# app.R - explore TEMPO formaldehyde columns against surface formaldehyde at
# every monitor of the paper, and the full CDPHE air-toxics record at the nine
# Colorado sites.
#
# Data: appdata/app_data.rds, written by R/24_app_data.R from the released
# dataset (dataset/, step 23) and the CDPHE annual data packets (step 01).
# Statistics: R/stats.R (loaded automatically), which step 24 checks against the
# paper's site table, so the correlations shown are the paper's.
library(shiny)
library(bslib)
library(leaflet)
library(plotly)
library(DT)

data_file <- if (file.exists(file.path("appdata", "app_data.rds"))) file.path("appdata", "app_data.rds") else
  file.path("app", "appdata", "app_data.rds")
D <- readRDS(data_file)
SITES <- D$sites; TEMPO <- D$tempo; TOX <- D$toxics; META <- D$meta; GEO <- D$geo
SCREEN <- D$screen; SENS_NAT <- D$sens_nat   # screening variants; every national site by configuration

`%or%` <- function(a, b) if (is.null(a) || !length(a) || all(is.na(a))) b else a
fmt_r <- function(r) if (is.null(r) || is.na(r)) "\u2013" else sprintf("%.2f", r)

SEASONS    <- c(DJF = "Winter (DJF)", MAM = "Spring (MAM)", JJA = "Summer (JJA)", SON = "Autumn (SON)")
SEASON_COL <- c(DJF = "#3b6fb6", MAM = "#5aa469", JJA = "#d9822b", SON = "#8a5fb0")
SMOKE_COL  <- c(none = "#8c8c8c", light = "#e08214", "medium/heavy" = "#b2182b", "no HMS data" = "#d0d0d0")
ARM_LABEL  <- c(national     = "National comparison (2024\u20132025)",
                colorado_24h = "Colorado analysis, 24 h samples",
                colorado_3h  = "Colorado analysis, 3 h samples (Platteville from Aug 2023)")
CLASS_LABEL <- c(Carbonyls = "Carbonyls", VOCs = "VOCs (TO-15)", SNMOC = "SNMOC (ozone precursors)",
                 PAHs = "PAHs", Metals = "Metals", Methane = "Methane")
U_CONC <- "\u00b5g m\u207b\u00b3"
U_COL  <- "10\u00b9\u2075 molecules cm\u207b\u00b2"

# lag_label() and filter_rows() are in R/sensitivity.R, shared with step 24.
fmt_rv  <- function(r) ifelse(is.na(r), "–", sprintf("%.2f", r))
fmt_num <- function(x, d) ifelse(is.na(x), "–", formatC(x, format = "f", digits = d))
class_label <- function(cl) ifelse(is.na(CLASS_LABEL[cl]), cl, CLASS_LABEL[cl])

# ---- site list and map labels --------------------------------------------------------
site_label <- function(s) ifelse(is.na(s$site_code), sprintf("%s (%s)", s$name, s$site_id),
                                 sprintf("%s (%s, %s)", s$name, s$site_code, s$site_id))
co_sites <- SITES[SITES$colorado_detail, ]
nat_sites <- SITES[!SITES$colorado_detail, ]
CHOICES <- c(list("Colorado: CDPHE air toxics and TEMPO" = setNames(co_sites$site_id, site_label(co_sites))),
             split(setNames(nat_sites$site_id, site_label(nat_sites)), nat_sites$state))
DEFAULT_SITE <- if ("08-001-0010" %in% SITES$site_id) "08-001-0010" else SITES$site_id[1]

# ---- monitoring networks, as AQS lists them (a site can belong to several) -------------
NET_LABEL <- c(NATTS = "NATTS", NCORE = "NCore", PAMS = "PAMS (incl. unofficial PAMS)", NEAR = "Near-road",
               OTHER = "Other AQS networks", NONE = "No network listed in AQS", CO = "Colorado CDPHE sites")
NET_KNOWN <- c("NATTS", "NCORE", "PAMS", "UNOFFICIAL PAMS", "NEAR ROAD")
net_tok <- lapply(strsplit(toupper(ifelse(is.na(SITES$networks), "", SITES$networks)), ";"),
                  function(t) { t <- trimws(t); unique(t[nzchar(t)]) })
NET_MAT <- do.call(rbind, lapply(seq_len(nrow(SITES)), function(i) {
  tk <- net_tok[[i]]
  c(NATTS = "NATTS" %in% tk, NCORE = "NCORE" %in% tk, PAMS = any(c("PAMS", "UNOFFICIAL PAMS") %in% tk),
    NEAR = "NEAR ROAD" %in% tk, OTHER = any(!tk %in% NET_KNOWN), NONE = !length(tk), CO = SITES$colorado_detail[i])
}))
NET_TEXT <- vapply(net_tok, paste, "", collapse = ", ")
NET_CHOICES <- names(NET_LABEL)[colSums(NET_MAT) > 0]
NET_CHOICES <- setNames(NET_CHOICES, sprintf("%s (%d)", NET_LABEL[NET_CHOICES], colSums(NET_MAT)[NET_CHOICES]))
site_in_nets <- function(nets) {
  nets <- intersect(nets, colnames(NET_MAT))
  if (!length(nets)) return(rep(FALSE, nrow(SITES)))
  rowSums(NET_MAT[, nets, drop = FALSE]) > 0
}
IS_NAT <- SITES$site_id %in% TEMPO$site_id[TEMPO$arm == "national"]
NET_N  <- colSums(NET_MAT[IS_NAT, , drop = FALSE])

# ---- what the app is for -----------------------------------------------------------------
INTRO_TEXT <- tagList(
  "This app compares formaldehyde (HCHO) measured at ground-based monitors with the HCHO column that NASA's ",
  "TEMPO satellite measures from geostationary orbit, sample by sample, from ",
  format(min(TEMPO$date), "%B %Y"), " to ", format(max(TEMPO$date), "%B %Y"), ". ",
  sprintf("The ground data are the integrated 24, 8 and 3 h samples of %d U.S. EPA Air Quality System (AQS) monitors: ",
          sum(IS_NAT)),
  sprintf("NATTS (%d), NCore (%d), PAMS (%d) and near-road (%d) sites%s, and %d state and local monitors with no network listed in AQS",
          NET_N[["NATTS"]], NET_N[["NCORE"]], NET_N[["PAMS"]], NET_N[["NEAR"]],
          if (NET_N[["OTHER"]] > 0) sprintf(", %d in other networks", NET_N[["OTHER"]]) else "", NET_N[["NONE"]]),
  " (a site can belong to more than one network)",
  if (any(!IS_NAT)) sprintf("; the Colorado analysis adds %s", paste(SITES$name[!IS_NAT], collapse = ", ")) else "",
  sprintf(". At the %d Colorado sites (black outline) the CDPHE ", sum(SITES$colorado_detail)),
  "air-toxics packets add every other toxic measured there. Click a monitor to see how closely surface and satellite ",
  "agree, over the whole period and day to day; the ", tags$b("How agreement varies"), " tab shows how that agreement ",
  "changes with boundary-layer height, temperature, timing, smoke, season and the satellite screening.")
INTRO <- div(class = "alert alert-light border small mb-3", tags$b("What this app is for. "), INTRO_TEXT)

# ---- colouring the scatter plots ----------------------------------------------------------
COLOUR_BY <- c("Season" = "season", "Smoke class (NOAA HMS)" = "smoke",
               "Boundary-layer height, HRRR (km)" = "hrrr_pbl_km",
               "Boundary-layer height, TEMPO (km)" = "tempo_pbl_km",
               "Temperature, HRRR (°C)" = "temp_c", "Valid TEMPO scans" = "n_valid")
scatter_by <- function(x, y, d, by, text) {
  if (by == "season") {
    plot_ly(x = x, y = y, color = factor(d$season, levels = names(SEASONS)), colors = SEASON_COL,
            type = "scatter", mode = "markers", marker = list(size = 6, opacity = 0.8), text = text, hoverinfo = "text")
  } else if (by == "smoke") {
    plot_ly(x = x, y = y, color = factor(ifelse(is.na(d$smoke), "no HMS data", d$smoke), levels = names(SMOKE_COL)),
            colors = SMOKE_COL, type = "scatter", mode = "markers", marker = list(size = 6, opacity = 0.8),
            text = text, hoverinfo = "text")
  } else {
    v <- d[[by]]; lab <- names(COLOUR_BY)[COLOUR_BY == by]
    plot_ly(x = x, y = y, type = "scatter", mode = "markers", showlegend = FALSE,
            marker = list(size = 7, opacity = 0.85, color = v, colorscale = "Viridis", showscale = TRUE,
                          colorbar = list(title = list(text = sub(" \\(", "<br>(", sub(", ", "<br>", lab))),
                                          len = 0.8, thickness = 12)),
            text = paste0(text, "<br>", lab, ": ", fmt_num(v, if (by == "n_valid") 0 else 2)), hoverinfo = "text")
  }
}

# ---- how agreement varies: dot plot, one row per configuration ----------------------------
SERIES <- list(tot = list(name = "Whole-period r", col = "#6f6f6f", sym = "diamond", off = 0.18),
               ano = list(name = "Day-to-day r (within-month anomalies)", col = "#2166ac", sym = "circle", off = -0.18))
sens_height <- function(tab) paste0(20 * (nrow(tab) + length(unique(tab$dim))) + 120, "px")
sens_plot <- function(tab) {
  y <- 0; yv <- numeric(); yt <- character(); tab$y <- NA_real_; ann <- list()
  for (dm in unique(tab$dim)) {
    y <- y - 1
    ann[[length(ann) + 1]] <- list(x = 0, xref = "paper", xanchor = "left", y = y, yref = "y", showarrow = FALSE,
                                   text = paste0("<b>", dm, "</b>"), font = list(size = 12))
    for (i in which(tab$dim == dm)) { y <- y - 1; tab$y[i] <- y; yv <- c(yv, y); yt <- c(yt, tab$label[i]) }
  }
  p <- plot_ly()
  for (s in names(SERIES)) {
    rr <- tab[[paste0("r_", s)]]; k <- which(!is.na(rr))
    if (!length(k)) next
    lo <- tab[[paste0("lo_", s)]]
    err <- if (is.null(lo)) NULL else
      list(type = "data", symmetric = FALSE, array = tab[[paste0("hi_", s)]][k] - rr[k], arrayminus = rr[k] - lo[k],
           color = SERIES[[s]]$col, thickness = 1.4, width = 0)
    args <- list(p, x = rr[k], y = tab$y[k] + SERIES[[s]]$off, type = "scatter", mode = "markers",
                 name = SERIES[[s]]$name,
                 marker = list(size = 9, symbol = SERIES[[s]]$sym, color = SERIES[[s]]$col,
                               opacity = ifelse(tab[[paste0("faded_", s)]][k], 0.3, 1)),
                 text = tab[[paste0("hover_", s)]][k], hoverinfo = "text")
    if (!is.null(err)) args$error_x <- err
    p <- do.call(add_trace, args)
  }
  p |> layout(xaxis = list(title = "Pearson r, surface HCHO vs TEMPO column", range = c(-1, 1), side = "top",
                           zeroline = TRUE, zerolinecolor = "#8a8a8a", showgrid = TRUE, fixedrange = TRUE),
              yaxis = list(tickvals = yv, ticktext = yt, range = c(y - 0.8, -0.3), zeroline = FALSE,
                           showgrid = FALSE, automargin = TRUE, fixedrange = TRUE),
              annotations = ann, legend = list(orientation = "h", x = 0, y = 0, yanchor = "top"),
              margin = list(t = 60, b = 10))
}
# the selected site: faded where the paper's reporting threshold is not met
site_plot_rows <- function(t) {
  low <- function(n, what) ifelse(n < MIN_REPORT, sprintf("<br><i>fewer than %d %s: the paper does not report this</i>",
                                                         MIN_REPORT, what), "")
  data.frame(dim = t$dim, label = paste0(t$level, ifelse(t$current, "  ◀", "")),
             r_tot = t$r, r_ano = t$r_anom, faded_tot = t$n < MIN_REPORT, faded_ano = t$n_anom < MIN_REPORT,
             hover_tot = sprintf("<b>%s</b><br>%s<br>whole-period r = %s (n = %d)%s", t$dim, t$level,
                                 fmt_rv(t$r), t$n, low(t$n, "samples")),
             hover_ano = sprintf("<b>%s</b><br>%s<br>day-to-day r = %s (%d anomaly pairs)%s", t$dim, t$level,
                                 fmt_rv(t$r_anom), t$n_anom, low(t$n_anom, "pairs")),
             stringsAsFactors = FALSE)
}
# every national site: median and interquartile range over the sites that meet the threshold
NAT_PRIMARY <- "Paper's primary configuration"
nat_plot_rows <- function(d) {
  d$label <- ifelse(d$key %in% THIRD_KEYS, c(low = "Lowest third", mid = "Middle third", high = "Highest third")[d$key], d$level)
  d$label[d$key == "current"] <- "TEMPO lag 0, 3 × 3 pixels, cloud fraction ≤ 0.2, all days and seasons"
  d$dim[d$dim == DIM_CURRENT] <- NAT_PRIMARY
  g <- stats::aggregate(ord ~ dim + key + label, data = d, FUN = min)
  g <- g[order(match(g$dim, c(NAT_PRIMARY, DIM_ORDER[-1])), g$ord), ]
  q <- function(v) if (length(v)) stats::quantile(v, c(0.25, 0.5, 0.75), names = FALSE) else rep(NA_real_, 3)
  do.call(rbind, lapply(seq_len(nrow(g)), function(i) {
    s  <- d[d$dim == g$dim[i] & d$key == g$key[i], ]
    vt <- s$r[s$n >= MIN_REPORT & !is.na(s$r)]; va <- s$r_anom[s$n_anom >= MIN_REPORT & !is.na(s$r_anom)]
    a <- q(vt); b <- q(va)
    hv <- function(what, x, nn, unit) sprintf("<b>%s</b><br>%s<br>%s: median %s, interquartile range %s to %s<br>%d sites with ≥ %d %s",
                                              g$dim[i], g$label[i], what, fmt_rv(x[2]), fmt_rv(x[1]), fmt_rv(x[3]), nn, MIN_REPORT, unit)
    data.frame(dim = g$dim[i], label = g$label[i],
               r_tot = a[2], lo_tot = a[1], hi_tot = a[3], faded_tot = FALSE,
               r_ano = b[2], lo_ano = b[1], hi_ano = b[3], faded_ano = FALSE,
               hover_tot = hv("whole-period r", a, length(vt), "samples"),
               hover_ano = hv("day-to-day r", b, length(va), "anomaly pairs"), stringsAsFactors = FALSE)
  }))
}
NAT_DUR_CHOICES <- if (is.null(SENS_NAT)) c("24 h samples" = "24") else {
  du <- sort(unique(SENS_NAT$duration_h), decreasing = TRUE)
  setNames(as.character(du), sprintf("%d h samples (%d sites)", du,
                                     vapply(du, function(x) length(unique(SENS_NAT$site_id[SENS_NAT$duration_h == x])), 1L)))
}
filter_text <- function(smoke, seasons) {
  s1 <- c(all = "all days", none = "smoke-free days", smoke = "smoke-affected days")[[smoke]]
  se <- intersect(names(SEASONS), seasons)
  s2 <- if (length(se) == length(SEASONS)) "all seasons" else if (!length(se)) "no season selected" else
    paste(c(DJF = "winter", MAM = "spring", JJA = "summer", SON = "autumn")[se], collapse = ", ")
  paste0(s1, "; ", s2)
}

# The map colours each site by the day-to-day correlation of the record behind
# its headline result (its longest duration, sampling window, national comparison;
# the Colorado analysis for Wheat Ridge), for the selected smoke class and seasons.
MAP_ROWS <- TEMPO[TEMPO$lag_h == 0L & TEMPO$usable &
                    paste(TEMPO$site_id, TEMPO$arm, TEMPO$duration_h) %in%
                    paste(SITES$site_id, SITES$map_arm, SITES$map_duration), ]
map_stats <- function(smoke = "all", seasons = names(SEASONS)) {
  d  <- filter_rows(MAP_ROWS, smoke, seasons)
  st <- lapply(split(d, factor(d$site_id, levels = SITES$site_id)),
               function(x) pair_stats(x$date, x$hcho, x$column))
  data.frame(n_anom = vapply(st, function(z) as.integer(z$n_anom), 1L),
             r_anom = vapply(st, function(z) as.numeric(z$r_anom), 1), row.names = NULL)
}
SITE_HEAD <- sprintf("<b>%s</b><br>AQS %s%s%s%s", SITES$name, SITES$site_id,
                     ifelse(is.na(SITES$site_code), "", paste0(" &middot; CDPHE ", SITES$site_code)),
                     ifelse(nzchar(NET_TEXT), paste0("<br>AQS networks: ", NET_TEXT), "<br>No network listed in AQS"),
                     ifelse(is.na(SITES$program), "", paste0("<br>", SITES$program)))
map_labels <- function(ms, ftxt) {
  stat <- ifelse(is.na(SITES$map_duration), "no matched samples",
          ifelse(ms$n_anom >= MIN_REPORT & !is.na(ms$r_anom),
                 sprintf("%d h record: day-to-day r = %.2f (%d pairs)", SITES$map_duration, ms$r_anom, ms$n_anom),
                 sprintf("%d h record: %d anomaly pairs, fewer than %d", SITES$map_duration, ms$n_anom, MIN_REPORT)))
  paste0(SITE_HEAD, "<br>", stat, "<br><i>", ftxt, "</i>")
}
add_site_markers <- function(map, ms, ftxt, show = rep(TRUE, nrow(SITES))) {
  i <- which(show)
  map <- clearGroup(map, "sites")
  if (length(i))
    map <- addCircleMarkers(map, data = SITES[i, ], lng = ~lon, lat = ~lat, layerId = ~site_id, group = "sites",
                            radius = ifelse(SITES$colorado_detail, 8, 4 + 4 * sqrt(pmin(ms$n_anom, 150) / 150))[i],
                            fillColor = PAL(clamp(ifelse(ms$n_anom >= MIN_REPORT, ms$r_anom, NA)))[i], fillOpacity = 0.9,
                            color = ifelse(SITES$colorado_detail, "#111111", "#6b6b6b")[i],
                            weight = ifelse(SITES$colorado_detail, 2.5, 0.7)[i],
                            label = lapply(map_labels(ms, ftxt)[i], HTML))
  map |>
    addLegend("bottomright", pal = PAL, values = c(-0.8, 0.8), opacity = 1, layerId = "legend",
              title = HTML(paste0("Day-to-day r<br><span style='font-weight:normal;font-size:85%'>",
                                  ftxt, "</span>")))
}
PAL   <- colorNumeric(c("#b2182b", "#f7f7f7", "#2166ac"), domain = c(-0.8, 0.8), na.color = "#bdbdbd")
clamp <- function(x) pmax(pmin(x, 0.8), -0.8)

# ---- about page ------------------------------------------------------------------------
ABOUT <- card(card_body(
  h4("Purpose"),
  p(INTRO_TEXT),
  h4("What this app shows"),
  p("Each point on the map is a U.S. EPA Air Quality System (AQS) monitor that reported integrated formaldehyde ",
    "samples (24, 8 or 3 h) in 2024\u20132025. For every sample the app shows the matching TEMPO Level 3 V04 ",
    "formaldehyde column: the mean of the TEMPO scans whose midpoint falls in the sampling window, each scan averaged ",
    "over the 3 \u00d7 3 grid cells around the monitor that pass the screening (main data quality flag 0, effective ",
    "cloud fraction \u2264 0.2, solar zenith angle \u2264 70\u00b0, no snow or ice), with at least five of the nine cells passing."),
  p("The nine Colorado sites (outlined in black) also carry the full air-toxics record of the Colorado Department of ",
    "Public Health and Environment (CDPHE) annual data packets: carbonyls, volatile organic compounds, PAHs and metals at the ",
    "seven Colorado Air Toxics Trends (COATTS) sites, and carbonyls, speciated non-methane organic compounds and methane at the ",
    "two ozone-precursor (COOPs) sites. Values are shown as reported; samples carrying an AQS null-data qualifier and the ",
    "packets' QC samples are removed, and non-detects are drawn at their detection limit where one is reported."),
  h4("Statistics"),
  tags$ul(
    tags$li(tags$b("Whole-period r"), ": Pearson correlation between surface HCHO and the TEMPO column over samples with a usable TEMPO observation."),
    tags$li(tags$b("Day-to-day r"), ": the same correlation after removing each calendar month's mean (each month of each year) from both series, ",
            "in months with at least three samples. It measures day-to-day covariation rather than the shared seasonal cycle. ",
            "The paper reports a site only with at least 10 matched samples and 10 anomaly pairs."),
    tags$li("Filters (smoke, season) recompute both correlations, and the monthly means, on the selected samples alone."),
    tags$li(tags$b("Smoke"), ": NOAA Hazard Mapping System smoke polygons over the site whose analysis period overlaps the sampling window widened by 3 h on each side."),
    tags$li(tags$b("Boundary-layer height"), ": NOAA HRRR's planetary boundary-layer height averaged over the hours of the ",
            "sampling window, and the boundary-layer height supplied with the TEMPO retrieval, averaged over the valid scans ",
            "(daytime only). Temperature: HRRR 2 m temperature over the sampling window."),
    tags$li(tags$b("How agreement varies"), ": both correlations recomputed with one thing changed at a time: smoke, season, ",
            "TEMPO window, sample duration, TEMPO pixel block and cloud-fraction limit (the screening variants of the released ",
            "data), and thirds of the samples by boundary-layer height, temperature and the number of valid TEMPO scans. ",
            "For the thirds, within-month anomalies are formed first and the samples entering the day-to-day correlation are ",
            "split into equal thirds (dplyr::ntile), as in the paper's boundary-layer analysis; whole-period r uses the same ",
            "samples. The all-sites panel applies the same calculation to every site of the national comparison.")),
  h4("Data and code"),
  p("The matched data are the released dataset of the paper, built by the R pipeline at ",
    a(META$repo, href = META$repo, target = "_blank"), " (folder ", code("dataset/"), "; the app is built by step 24). ",
    "TEMPO: NASA Langley ASDC, ", a("doi:10.5067/IS-40e/TEMPO/HCHO_L3.004", href = "https://doi.org/10.5067/IS-40e/TEMPO/HCHO_L3.004", target = "_blank"),
    ". Surface data: U.S. EPA AQS and CDPHE. Meteorology: NOAA HRRR. Smoke: NOAA HMS."),
  p(class = "small text-muted", "Data version: dataset md5 ", substr(META$dataset$md5, 1, 12), ".")
))

# ---- UI --------------------------------------------------------------------------------
ui <- page_navbar(
  title = "TEMPO vs ground-based formaldehyde (HCHO)",
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  header = tags$style(HTML(".leaflet-container { background: #e8edf1; }")),
  fillable = FALSE,
  nav_panel("Explore",
    layout_sidebar(
      sidebar = sidebar(width = 330,
        selectInput("site", "Monitoring site", choices = CHOICES, selected = DEFAULT_SITE),
        uiOutput("site_card"),
        accordion(multiple = TRUE, open = c("TEMPO comparison", "Monitoring networks", "Air toxics"),
          accordion_panel("TEMPO comparison",
            uiOutput("arm_ui"), uiOutput("dur_ui"), uiOutput("lag_ui"),
            radioButtons("smoke", "Smoke (NOAA HMS)", choices = c("All days" = "all", "Smoke-free days" = "none",
                                                                  "Smoke-affected days" = "smoke")),
            checkboxGroupInput("seasons", "Seasons", choices = setNames(names(SEASONS), SEASONS),
                               selected = names(SEASONS)),
            selectInput("colour_by", "Colour scatter points by", choices = COLOUR_BY)),
          accordion_panel("Monitoring networks",
            checkboxGroupInput("nets", NULL, choices = NET_CHOICES, selected = NET_CHOICES),
            div(class = "small text-muted",
                "Sites shown on the map and used in the all-sites panel. A site is shown if it belongs to any ",
                "checked group; AQS lists the networks.")),
          accordion_panel("Air toxics",
            uiOutput("tox_class_ui"), uiOutput("tox_param_ui"),
            checkboxInput("tox_log", "Logarithmic axis", FALSE),
            checkboxInput("tox_cmp", "Compare with the other Colorado sites", TRUE)))
      ),
      INTRO,
      # the map spans the full width, with the site panel below it
      layout_columns(col_widths = 12,
        card(full_screen = TRUE,
             card_header(class = "d-flex flex-wrap justify-content-between align-items-center gap-2",
                         span("Monitors: click one to select it. Scroll or use + / \u2212 to zoom."),
                         div(class = "d-flex gap-3",
                             span(class = "text-muted", "Zoom to:"),
                             actionLink("zoom_us", "Whole US"),
                             actionLink("zoom_co", "Colorado"),
                             actionLink("zoom_site", "Selected site"))),
             leafletOutput("map", height = 560),
             card_footer(class = "small text-muted",
                         "Colour: day-to-day correlation with TEMPO of each site's longest-duration record ",
                         "(sampling window), for the smoke and season filters at left. Grey: fewer than 10 ",
                         "within-month anomaly pairs. Black outline: Colorado sites with CDPHE air-toxics data. ",
                         "Sites follow the network filter at left. ",
                         "Background layers are in the control at the top right of the map; the expand ",
                         "icon at the bottom right of this card shows the map full screen.")),
        navset_card_tab(id = "tab", full_screen = TRUE,
          nav_panel("TEMPO vs surface HCHO", value = "tempo",
            uiOutput("tempo_boxes"),
            plotlyOutput("p_ts", height = "380px"),
            layout_columns(col_widths = breakpoints(sm = 12, lg = c(6, 6)),
                           plotlyOutput("p_scatter", height = "330px"),
                           plotlyOutput("p_anom", height = "330px")),
            plotlyOutput("p_obs", height = "300px"),
            div(class = "mt-2", downloadButton("dl_tempo", "Download these samples (CSV)", class = "btn-sm"))),
          nav_panel("How agreement varies", value = "sens",
            div(class = "small text-muted mt-2 mb-2",
                "How the agreement between surface HCHO and the TEMPO column changes with the conditions and the choices ",
                "of the comparison. Each row changes one thing and keeps the rest. Grey diamonds: whole-period r; ",
                "blue circles: day-to-day r (within-month anomalies). Faded: fewer than 10 samples or pairs, which the ",
                "paper does not report. Thirds: the samples entering the day-to-day correlation split into equal thirds ",
                "by that variable, as in the paper's boundary-layer analysis. Deep boundary layers and warm days fall ",
                "mostly in summer; the row “relative to its month mean” separates the day-to-day effect from the seasonal one."),
            h5("This site"),
            uiOutput("sens_site_head"),
            uiOutput("sens_site_ui"),
            tags$details(class = "mb-2", tags$summary("Show the numbers"), DTOutput("sens_site_table")),
            downloadButton("dl_sens", "Download this table (CSV)", class = "btn-sm"),
            hr(),
            h5("All national sites"),
            div(class = "small text-muted mb-2",
                "Every site of the national comparison at the paper's primary configuration, changing one thing at a ",
                "time (computed by step 24 with the same code). Points: median across the sites with at least 10 samples ",
                "(whole-period) or 10 anomaly pairs (day-to-day); bars: interquartile range across those sites. Sites ",
                "follow the network filter at left; the smoke and season filters do not apply here. Thirds are formed ",
                "site by site, so their cut points differ between sites."),
            radioButtons("nat_dur", NULL, inline = TRUE, choices = NAT_DUR_CHOICES),
            uiOutput("sens_nat_head"),
            uiOutput("sens_nat_ui")),
          nav_panel("Air toxics", value = "toxics", uiOutput("tox_body"))
        )
      )
    )
  ),
  nav_panel("About", ABOUT)
)

# ---- server ----------------------------------------------------------------------------
server <- function(input, output, session) {

  site <- reactive({ req(input$site); SITES[SITES$site_id == input$site, ][1, ] })

  output$site_card <- renderUI({
    s <- site()
    div(class = "small mb-2",
        div(tags$b(s$name)),
        div(class = "text-muted", sprintf("AQS %s%s \u00b7 %s", s$site_id,
                                          if (!is.na(s$site_code)) paste0(" \u00b7 CDPHE ", s$site_code) else "", s$state)),
        if (!is.na(s$program)) div(class = "text-muted", s$program),
        if (!is.na(s$networks)) div(class = "text-muted", "Networks: ", s$networks),
        if (!is.na(s$aqs_name) && !is.na(s$cdphe_name) && s$aqs_name != s$cdphe_name)
          div(class = "text-muted", "AQS name: ", s$aqs_name),
        div(class = "text-muted", "Sample durations: ", gsub(";", " h, ", s$durations), " h"))
  })

  # ---- map
  output$map <- renderLeaflet({
    m <- leaflet(SITES, options = leafletOptions(minZoom = 3)) |>
      # outlines in their own pane: above any tiles (200), below the markers (400)
      addMapPane("outline", zIndex = 250) |>
      addProviderTiles(providers$Esri.WorldGrayCanvas, group = "Grey basemap (Esri)") |>
      addProviderTiles(providers$OpenStreetMap.Mapnik, group = "Streets (OpenStreetMap)")
    base <- c("Grey basemap (Esri)", "Streets (OpenStreetMap)"); over <- character()
    if (!is.null(GEO$states)) {
      m <- m |>
        addPolygons(lng = GEO$states$lng, lat = GEO$states$lat, group = "No basemap", stroke = FALSE,
                    fillColor = "#ffffff", fillOpacity = 1,
                    options = pathOptions(pane = "outline", interactive = FALSE)) |>
        addPolylines(lng = GEO$states$lng, lat = GEO$states$lat, group = "State lines",
                     color = "#8a8a8a", weight = 0.8, opacity = 1,
                     options = pathOptions(pane = "outline", interactive = FALSE))
      base <- c("No basemap", base); over <- c(over, "State lines")
    }
    if (!is.null(GEO$co_counties)) {
      m <- addPolylines(m, lng = GEO$co_counties$lng, lat = GEO$co_counties$lat, group = "Colorado counties",
                        color = "#b5b5b5", weight = 0.5, opacity = 1,
                        options = pathOptions(pane = "outline", interactive = FALSE))
      over <- c(over, "Colorado counties")
    }
    m |>
      add_site_markers(isolate(map_stats(input$smoke %or% "all", input$seasons %or% character())),
                       isolate(filter_text(input$smoke %or% "all", input$seasons %or% character())),
                       isolate(site_in_nets(input$nets %or% character()))) |>
      addLayersControl(baseGroups = base, overlayGroups = over,
                       options = layersControlOptions(collapsed = TRUE)) |>
      hideGroup(setdiff(base, base[1])) |>
      fitBounds(-124.5, 24.5, -67, 49.5)
  })
  clicked <- reactiveVal(NULL)   # the site last chosen by clicking its marker
  observeEvent(input$map_marker_click, {
    id <- input$map_marker_click$id
    if (!is.null(id) && id %in% SITES$site_id) { clicked(id); updateSelectInput(session, "site", selected = id) }
  })
  # markers re-coloured when the smoke or season filter changes (same layerIds,
  # so each marker and the legend are replaced, not duplicated)
  map_ready <- reactiveVal(FALSE)
  observeEvent(input$map_zoom, map_ready(TRUE), once = TRUE)
  observe({
    req(map_ready())
    sm <- input$smoke %or% "all"; se <- input$seasons %or% character()
    leafletProxy("map") |> add_site_markers(map_stats(sm, se), filter_text(sm, se),
                                            site_in_nets(input$nets %or% character()))
  })
  # ring around the selected site, once the map exists
  observe({
    req(map_ready())
    s <- site()
    leafletProxy("map") |> clearGroup("selected") |>
      addCircleMarkers(lng = s$lon, lat = s$lat, radius = 15, fill = FALSE, color = "#000000",
                       weight = 3, opacity = 1, group = "selected", layerId = "selected_ring")
  })
  observeEvent(input$zoom_co, leafletProxy("map") |> fitBounds(-109.1, 36.9, -102.0, 41.1))
  observeEvent(input$zoom_us, leafletProxy("map") |> fitBounds(-124.5, 24.5, -67, 49.5))
  zoom_to_site <- function() {
    s <- site()
    leafletProxy("map") |> flyTo(s$lon, s$lat, zoom = max(input$map_zoom %or% 0, 9))
  }
  observeEvent(input$zoom_site, zoom_to_site())
  # a site chosen from the drop-down list is brought into view; one chosen by
  # clicking its marker is already in view, so the map stays where it is
  observeEvent(input$site, {
    req(map_ready())
    if (!identical(input$site, clicked())) zoom_to_site()
    clicked(NULL)
  }, ignoreInit = TRUE)

  # ---- TEMPO controls: data set, duration and lag available at this site
  arms_here <- reactive({
    a <- unique(TEMPO$arm[TEMPO$site_id == req(input$site)])
    a[order(match(a, names(ARM_LABEL)))]
  })
  cur_arm <- reactive({ a <- arms_here(); if (!is.null(input$arm) && input$arm %in% a) input$arm else a[1] })
  durs_here <- reactive({
    sort(unique(TEMPO$duration_h[TEMPO$site_id == input$site & TEMPO$arm == cur_arm()]), decreasing = TRUE)
  })
  cur_dur <- reactive({
    d <- durs_here(); v <- suppressWarnings(as.integer(input$dur %or% NA))
    if (!is.na(v) && v %in% d) v else d[1]
  })
  lags_here <- reactive({
    sort(unique(TEMPO$lag_h[TEMPO$site_id == input$site & TEMPO$arm == cur_arm() & TEMPO$duration_h == cur_dur()]))
  })
  cur_lag <- reactive({
    l <- lags_here(); v <- suppressWarnings(as.integer(input$lag %or% NA))
    if (!is.na(v) && v %in% l) v else if (0L %in% l) 0L else l[1]
  })
  output$arm_ui <- renderUI({
    a <- arms_here()
    radioButtons("arm", "Data set", choices = setNames(a, unname(ARM_LABEL[a])), selected = isolate(cur_arm()))
  })
  output$dur_ui <- renderUI({
    d <- durs_here()
    selectInput("dur", "Sample duration", choices = setNames(d, paste(d, "h samples")), selected = isolate(cur_dur()))
  })
  output$lag_ui <- renderUI({
    l <- lags_here()
    if (length(l) < 2) return(NULL)
    selectInput("lag", "TEMPO window", choices = setNames(l, lag_label(l)), selected = isolate(cur_lag()))
  })

  # ---- TEMPO data for the selection
  sel_all <- reactive({
    d <- TEMPO[TEMPO$site_id == req(input$site) & TEMPO$arm == cur_arm() &
                 TEMPO$duration_h == cur_dur() & TEMPO$lag_h == cur_lag(), ]
    filter_rows(d, input$smoke %or% "all", input$seasons %or% character())
  })
  sel <- reactive({ d <- sel_all(); d[d$usable, ] })
  st  <- reactive({ d <- sel(); pair_stats(d$date, d$hcho, d$column) })

  output$tempo_boxes <- renderUI({
    d <- sel_all(); s <- st()
    if (!nrow(d)) return(div(class = "text-muted p-2", "No samples match this selection."))
    layout_column_wrap(width = "200px", fill = FALSE, class = "mb-2",
      value_box("Samples", nrow(d), p(sprintf("%d with TEMPO coverage", sum(d$n_scans > 0)))),
      value_box("Usable TEMPO observation", sprintf("%.0f%%", 100 * mean(d$usable)), p(sprintf("%d samples", s$n))),
      value_box("Whole-period r", fmt_r(s$r), p(sprintf("n = %d", s$n))),
      value_box("Day-to-day r", fmt_r(s$r_anom),
                p(sprintf("%d anomaly pairs%s", s$n_anom,
                          if (s$n_anom < MIN_REPORT) "; below the paper's 10-pair threshold" else ""))))
  })

  output$p_ts <- renderPlotly({
    d <- sel_all()
    validate(need(nrow(d) > 0, "No samples match this selection."))
    top <- plot_ly(d, x = ~date, y = ~hcho, type = "scatter", mode = "markers", showlegend = FALSE,
                   marker = list(size = 6, color = ifelse(d$usable, "#2166ac", "rgba(255,255,255,0)"),
                                 line = list(color = "#2166ac", width = 1)),
                   text = sprintf("%s<br>surface HCHO %.2f %s<br>%s", format(d$date), d$hcho, U_CONC,
                                  ifelse(d$usable, "usable TEMPO observation", "no usable TEMPO observation")),
                   hoverinfo = "text") |>
      layout(yaxis = list(title = paste0("Surface HCHO (", U_CONC, ")")))
    u <- d[d$usable, ]
    if (nrow(u)) {
      u$smoke_lab <- factor(ifelse(is.na(u$smoke), "no HMS data", u$smoke), levels = names(SMOKE_COL))
      bot <- plot_ly(u, x = ~date, y = ~column, color = ~smoke_lab, colors = SMOKE_COL,
                     type = "scatter", mode = "markers", marker = list(size = 6),
                     text = sprintf("%s<br>TEMPO column %.2f<br>%d valid scans<br>smoke: %s<br>boundary layer: HRRR %s km, TEMPO %s km<br>temperature (HRRR) %s °C",
                                    format(u$date), u$column, u$n_valid, as.character(u$smoke_lab),
                                    fmt_num(u$hrrr_pbl_km, 2), fmt_num(u$tempo_pbl_km, 2), fmt_num(u$temp_c, 1)),
                     hoverinfo = "text") |>
        layout(yaxis = list(title = paste0("TEMPO (", U_COL, ")")))
    } else {
      bot <- plotly_empty(type = "scatter", mode = "markers")
    }
    subplot(top, bot, nrows = 2, shareX = TRUE, titleY = TRUE, heights = c(0.5, 0.5)) |>
      layout(title = list(text = "Surface samples (open: no usable TEMPO observation) and TEMPO columns by smoke class",
                          font = list(size = 13)),
             legend = list(orientation = "h", y = -0.12), xaxis = list(title = ""))
  })

  output$p_scatter <- renderPlotly({
    d <- sel(); s <- st()
    validate(need(nrow(d) >= 3, "Fewer than three samples with a usable TEMPO observation."))
    xs  <- range(d$column)
    fit <- stats::lm(hcho ~ column, data = d)
    scatter_by(d$column, d$hcho, d, input$colour_by %or% "season",
               sprintf("%s<br>column %.2f<br>surface %.2f", format(d$date), d$column, d$hcho)) |>
      add_lines(x = xs, y = unname(predict(fit, data.frame(column = xs))), inherit = FALSE,
                line = list(color = "black", width = 1.5), name = "least squares", showlegend = FALSE) |>
      layout(title = list(text = sprintf("Whole period: r = %s (n = %d)", fmt_r(s$r), s$n), font = list(size = 13)),
             xaxis = list(title = paste0("TEMPO column (", U_COL, ")")),
             yaxis = list(title = paste0("Surface HCHO (", U_CONC, ")")),
             legend = list(orientation = "h", y = -0.25))
  })

  output$p_anom <- renderPlotly({
    s <- st(); an <- s$anom
    validate(need(nrow(an) >= 3, "Too few samples in months with at least three for day-to-day anomalies."))
    xs  <- range(an$column_anom)
    fit <- stats::lm(surface_anom ~ column_anom, data = an)
    scatter_by(an$column_anom, an$surface_anom, sel()[an$i, ], input$colour_by %or% "season",
               sprintf("%s<br>column anomaly %.2f<br>surface anomaly %.2f", format(an$date),
                       an$column_anom, an$surface_anom)) |>
      add_lines(x = xs, y = unname(predict(fit, data.frame(column_anom = xs))), inherit = FALSE,
                line = list(color = "black", width = 1.5), showlegend = FALSE) |>
      layout(title = list(text = sprintf("Day to day (within-month anomalies): r = %s (%d pairs)",
                                         fmt_r(s$r_anom), s$n_anom), font = list(size = 13)),
             xaxis = list(title = "TEMPO column anomaly"), yaxis = list(title = "Surface HCHO anomaly"),
             legend = list(orientation = "h", y = -0.25))
  })

  output$p_obs <- renderPlotly({
    d <- sel_all()
    validate(need(nrow(d) > 0, ""))
    lev <- c("Usable TEMPO observation", "TEMPO observed, every scan screened out", "No TEMPO granule")
    d$status <- factor(ifelse(d$usable, lev[1], ifelse(d$n_scans > 0, lev[2], lev[3])), levels = lev)
    plot_ly(d, x = ~status, y = ~hcho, type = "box", boxpoints = "all", jitter = 0.4, pointpos = 0,
            marker = list(size = 4, color = "#2166ac", opacity = 0.5), line = list(color = "#333333"),
            fillcolor = "rgba(33,102,172,0.12)", name = "", showlegend = FALSE) |>
      layout(title = list(text = "Surface HCHO by TEMPO observability (raw values; the paper removes site-month means)",
                          font = list(size = 13)),
             xaxis = list(title = ""), yaxis = list(title = paste0("Surface HCHO (", U_CONC, ")")))
  })

  output$dl_tempo <- downloadHandler(
    filename = function() sprintf("tempo_hcho_%s_%s_%sh_lag%+d.csv", input$site, cur_arm(), cur_dur(), cur_lag()),
    content = function(file) {
      d <- sel_all()
      d$start_utc <- format(d$start_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      utils::write.csv(d, file, row.names = FALSE, na = "")
    })

  # ---- how agreement varies: the selected site, then every national site
  sens_site <- reactive({
    rows <- TEMPO[TEMPO$site_id == req(input$site), ]
    scr  <- if (is.null(SCREEN)) NULL else SCREEN[SCREEN$site_id == input$site, ]
    sensitivity_site(rows, cur_arm(), cur_dur(), cur_lag(), input$smoke %or% "all",
                     input$seasons %or% character(), scr)
  })
  output$sens_site_head <- renderUI({
    div(class = "small text-muted mb-1",
        sprintf("%s · %s · %d h samples · %s · %s. ◀ marks the configuration of the TEMPO tab.",
                site()$name, ARM_LABEL[[cur_arm()]], cur_dur(), lag_label(cur_lag()),
                filter_text(input$smoke %or% "all", input$seasons %or% character())))
  })
  output$sens_site_ui   <- renderUI(plotlyOutput("sens_site_plot", height = sens_height(sens_site())))
  output$sens_site_plot <- renderPlotly(sens_plot(site_plot_rows(sens_site())))
  output$sens_site_table <- renderDT({
    t <- sens_site()
    datatable(data.frame(Dimension = t$dim, Configuration = t$level, Samples = t$n, `Whole-period r` = round(t$r, 3),
                         `Anomaly pairs` = t$n_anom, `Day-to-day r` = round(t$r_anom, 3), check.names = FALSE),
              rownames = FALSE, class = "compact", options = list(dom = "t", paging = FALSE, ordering = FALSE))
  })
  output$dl_sens <- downloadHandler(
    filename = function() sprintf("agreement_by_configuration_%s_%s_%sh_lag%+d.csv", input$site, cur_arm(), cur_dur(), cur_lag()),
    content = function(file) {
      t <- cbind(data.frame(site_id = input$site, arm = cur_arm(), duration_h = cur_dur(), lag_h = cur_lag(),
                            filters = filter_text(input$smoke %or% "all", input$seasons %or% character())),
                 sens_site())
      utils::write.csv(t, file, row.names = FALSE, na = "")
    })
  sens_nat_sub <- reactive({
    validate(need(!is.null(SENS_NAT), "Re-run step 24 (R/24_app_data.R) to add the all-sites table."))
    ids <- SITES$site_id[site_in_nets(input$nets %or% character())]
    d <- SENS_NAT[SENS_NAT$duration_h == as.integer(input$nat_dur %or% "24") & SENS_NAT$site_id %in% ids, ]
    validate(need(nrow(d) > 0, "No national site in the selected networks has samples of this duration."))
    d
  })
  sens_nat_tab <- reactive(nat_plot_rows(sens_nat_sub()))
  output$sens_nat_head <- renderUI({
    div(class = "small text-muted mb-1", sprintf("%d sites with %s h samples in the selected networks.",
                                                length(unique(sens_nat_sub()$site_id)), input$nat_dur %or% "24"))
  })
  output$sens_nat_ui   <- renderUI(plotlyOutput("sens_nat_plot", height = sens_height(sens_nat_tab())))
  output$sens_nat_plot <- renderPlotly(sens_plot(sens_nat_tab()))

  # ---- air toxics
  tox_site <- reactive({ TOX[!is.na(TOX$site_id) & TOX$site_id == req(input$site), ] })
  classes_here <- reactive({ cl <- unique(tox_site()$class); cl[order(match(cl, names(CLASS_LABEL)))] })
  cur_class <- reactive({
    cl <- classes_here(); req(length(cl))
    if (!is.null(input$tox_class) && input$tox_class %in% cl) input$tox_class else cl[1]
  })
  params_here <- reactive({
    t <- tox_site(); t <- t[t$class == cur_class(), ]
    det <- tapply(!t$nondetect & !is.na(t$value), t$parameter, mean)
    det[order(-det, names(det))]
  })
  cur_param <- reactive({
    det <- params_here(); ps <- names(det)
    if (!is.null(input$tox_param) && input$tox_param %in% ps) input$tox_param else
      if ("Formaldehyde" %in% ps) "Formaldehyde" else if ("Benzene" %in% ps) "Benzene" else ps[1]
  })

  # the group list depends on the site only, the pollutant list on the group only,
  # so changing one control never rebuilds (and resets) the others
  output$tox_class_ui <- renderUI({
    if (!nrow(tox_site())) {
      return(p(class = "small text-muted",
               "CDPHE air-toxics data are available for the nine Colorado sites outlined in black on the map."))
    }
    cl <- classes_here()
    selectInput("tox_class", "Pollutant group", choices = setNames(cl, class_label(cl)), selected = isolate(cur_class()))
  })
  output$tox_param_ui <- renderUI({
    if (!nrow(tox_site())) return(NULL)
    det <- params_here()
    selectInput("tox_param", "Pollutant", selected = isolate(cur_param()),
                choices = setNames(names(det), sprintf("%s (%.0f%% detected)", names(det), 100 * det)))
  })

  tox_series <- reactive({ t <- tox_site(); t[t$class == cur_class() & t$parameter == cur_param(), ] })

  output$tox_body <- renderUI({
    if (!nrow(tox_site())) {
      return(div(class = "p-3 text-muted",
                 "Select one of the nine Colorado sites (outlined in black on the map) to see its air-toxics record ",
                 "from the CDPHE annual data packets."))
    }
    tagList(
      uiOutput("tox_boxes"),
      plotlyOutput("t_ts", height = "360px"),
      layout_columns(col_widths = breakpoints(sm = 12, lg = c(6, 6)),
                     plotlyOutput("t_season", height = "320px"), plotlyOutput("t_cmp", height = "320px")),
      h6(class = "mt-3", "Every pollutant of this group at this site (click a row to plot it)"),
      DTOutput("t_table"),
      div(class = "mt-2", downloadButton("dl_tox", "Download this site's air-toxics data (CSV)", class = "btn-sm")))
  })

  output$tox_boxes <- renderUI({
    d <- tox_series(); req(nrow(d))
    v <- d$value[!d$nondetect & !is.na(d$value)]
    u <- d$unit[1]
    layout_column_wrap(width = "200px", fill = FALSE, class = "mb-2",
      value_box("Samples", nrow(d), p(sprintf("%s to %s", format(min(d$sample_date)), format(max(d$sample_date))))),
      value_box("Detected", sprintf("%.0f%%", 100 * length(v) / nrow(d)), p(sprintf("%d non-detects", sum(d$nondetect)))),
      value_box("Median (detected)", if (length(v)) sprintf("%.3g", median(v)) else "\u2013", p(u)),
      value_box("Maximum", if (length(v)) sprintf("%.3g", max(v)) else "\u2013", p(u)))
  })

  output$t_ts <- renderPlotly({
    d <- tox_series()
    validate(need(nrow(d) > 0, "No samples."))
    u   <- d$unit[1]
    det <- d[!d$nondetect & !is.na(d$value), ]
    nd  <- d[d$nondetect | is.na(d$value), ]
    ndl <- nd[!is.na(nd$dl), ]
    p <- plot_ly()
    if (nrow(det)) {
      p <- add_markers(p, data = det, x = ~sample_date, y = ~value, name = "detected",
                       marker = list(size = 6, color = "#2166ac"),
                       text = sprintf("%s<br>%.3g %s%s", format(det$sample_date), det$value, u,
                                      ifelse(is.na(det$flags), "", paste0("<br>flags: ", det$flags))),
                       hoverinfo = "text")
    }
    if (nrow(ndl)) {
      p <- add_markers(p, data = ndl, x = ~sample_date, y = ~dl, name = "non-detect, at detection limit",
                       marker = list(size = 7, symbol = "triangle-down-open", color = "#7f7f7f"),
                       text = sprintf("%s<br>non-detect (detection limit %.3g %s)", format(ndl$sample_date), ndl$dl, u),
                       hoverinfo = "text")
    }
    layout(p,
           title = list(text = sprintf("%s at %s: %d samples, %d non-detects%s", cur_param(), site()$name, nrow(d),
                                       nrow(nd), if (nrow(nd) > nrow(ndl))
                                         sprintf(" (%d without a reported detection limit, not drawn)", nrow(nd) - nrow(ndl)) else ""),
                        font = list(size = 13)),
           xaxis = list(title = ""),
           yaxis = list(title = sprintf("%s (%s)", cur_param(), u), type = if (isTRUE(input$tox_log)) "log" else "linear"),
           legend = list(orientation = "h", y = -0.15))
  })

  output$t_season <- renderPlotly({
    d <- tox_series(); d <- d[!d$nondetect & !is.na(d$value), ]
    validate(need(nrow(d) > 0, "No detected values."))
    d$season_f <- factor(d$season, levels = names(SEASONS))
    plot_ly(d, x = ~season_f, y = ~value, color = ~season_f, colors = SEASON_COL, type = "box",
            boxpoints = "all", jitter = 0.4, pointpos = 0, marker = list(size = 4), showlegend = FALSE) |>
      layout(title = list(text = "Detected values by season", font = list(size = 13)),
             xaxis = list(title = ""),
             yaxis = list(title = d$unit[1], type = if (isTRUE(input$tox_log)) "log" else "linear"))
  })

  output$t_cmp <- renderPlotly({
    validate(need(isTRUE(input$tox_cmp), "Tick \u201cCompare with the other Colorado sites\u201d to show this panel."))
    d <- TOX[TOX$class == cur_class() & TOX$parameter == cur_param() & !TOX$nondetect & !is.na(TOX$value), ]
    validate(need(nrow(d) > 0, "No detected values at any site."))
    d$site_lab <- sprintf("%s (%g h)", d$site_code, d$duration_h)
    here <- site()$site_code
    d$here <- ifelse(d$site_code == here, "this site", "other sites")
    plot_ly(d, x = ~site_lab, y = ~value, color = ~here, colors = c("this site" = "#2166ac", "other sites" = "#9e9e9e"),
            type = "box", boxpoints = FALSE) |>
      layout(title = list(text = "Across the Colorado sites (detected values)", font = list(size = 13)),
             xaxis = list(title = ""), legend = list(orientation = "h", y = -0.25),
             yaxis = list(title = d$unit[1], type = if (isTRUE(input$tox_log)) "log" else "linear"))
  })

  tox_table <- reactive({
    t <- tox_site(); t <- t[t$class == cur_class(), ]
    rows <- lapply(split(t, t$parameter), function(x) {
      v <- x$value[!x$nondetect & !is.na(x$value)]
      data.frame(Pollutant = x$parameter[1], Unit = x$unit[1], Samples = nrow(x),
                 `Detected (%)` = round(100 * length(v) / nrow(x)),
                 Median = if (length(v)) signif(median(v), 3) else NA_real_,
                 `90th percentile` = if (length(v)) signif(unname(stats::quantile(v, 0.9)), 3) else NA_real_,
                 Maximum = if (length(v)) signif(max(v), 3) else NA_real_,
                 First = min(x$sample_date), Last = max(x$sample_date), check.names = FALSE)
    })
    out <- do.call(rbind, rows)
    out[order(-out$`Detected (%)`, out$Pollutant), , drop = FALSE]
  })
  output$t_table <- renderDT({
    datatable(tox_table(), rownames = FALSE, selection = "single",
              options = list(pageLength = 10, dom = "ftip", order = list()))
  })
  observeEvent(input$t_table_rows_selected, {
    i <- input$t_table_rows_selected
    tt <- tox_table()
    if (length(i) == 1 && i <= nrow(tt)) updateSelectInput(session, "tox_param", selected = tt$Pollutant[i])
  })

  output$dl_tox <- downloadHandler(
    filename = function() sprintf("air_toxics_%s.csv", site()$site_code %or% input$site),
    content = function(file) utils::write.csv(tox_site(), file, row.names = FALSE, na = ""))
}

shinyApp(ui, server)
