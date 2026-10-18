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
FIND <- D$findings                           # the paper's national results (step 24, from the pipeline tables)

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
  "TEMPO satellite measures from geostationary orbit, sample by sample. The national analysis covers ",
  paste(range(format(TEMPO$date[TEMPO$arm == "national"], "%Y")), collapse = "\u2013"),
  if (any(TEMPO$arm == "colorado_3h"))
    paste0("; the Colorado analysis extends the Platteville record back to ",
           format(min(TEMPO$date[TEMPO$arm == "colorado_3h"]), "%B %Y")) else "",
  ". ",
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
  "changes with boundary-layer height, temperature, timing, smoke, season and the satellite screening. The paper's ",
  "national results are summarized on the ", tags$b("Main findings"), " tab, and ", tags$b("How the comparison works"),
  " repeats the paper's calculation step by step for any monitor.")
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
# every duration of each site's map arm, for the record selector above the map
MAP_ALL <- TEMPO[TEMPO$lag_h == 0L & TEMPO$usable &
                   paste(TEMPO$site_id, TEMPO$arm) %in% paste(SITES$site_id, SITES$map_arm), ]
MAP_DUR_CHOICES <- c("Longest at each site" = "longest",
                     setNames(as.character(sort(unique(MAP_ALL$duration_h), decreasing = TRUE)),
                              paste(sort(unique(MAP_ALL$duration_h), decreasing = TRUE), "h")))
# dur: "longest" (each site's longest record) or a duration in hours; the column
# dur gives the record behind each site's colour (NA: the site has no such record)
map_stats <- function(smoke = "all", seasons = names(SEASONS), dur = "longest") {
  if (identical(dur, "longest")) {
    d <- MAP_ROWS; shown <- SITES$map_duration
  } else {
    dd <- as.integer(dur); d <- MAP_ALL[MAP_ALL$duration_h == dd, ]
    shown <- ifelse(SITES$site_id %in% d$site_id, dd, NA_integer_)
  }
  d  <- filter_rows(d, smoke, seasons)
  st <- lapply(split(d, factor(d$site_id, levels = SITES$site_id)),
               function(x) pair_stats(x$date, x$hcho, x$column))
  data.frame(n_anom = vapply(st, function(z) as.integer(z$n_anom), 1L),
             r_anom = vapply(st, function(z) as.numeric(z$r_anom), 1),
             dur = as.integer(shown), row.names = NULL)
}
map_show <- function(ms, nets, dur) site_in_nets(nets) & (identical(dur, "longest") | !is.na(ms$dur))
SITE_HEAD <- sprintf("<b>%s</b><br>AQS %s%s%s%s", SITES$name, SITES$site_id,
                     ifelse(is.na(SITES$site_code), "", paste0(" &middot; CDPHE ", SITES$site_code)),
                     ifelse(nzchar(NET_TEXT), paste0("<br>AQS networks: ", NET_TEXT), "<br>No network listed in AQS"),
                     ifelse(is.na(SITES$program), "", paste0("<br>", SITES$program)))
map_labels <- function(ms, ftxt) {
  stat <- ifelse(is.na(ms$dur), "no matched samples",
          ifelse(ms$n_anom >= MIN_REPORT & !is.na(ms$r_anom),
                 sprintf("%d h record: day-to-day r = %.2f (%d pairs)", ms$dur, ms$r_anom, ms$n_anom),
                 sprintf("%d h record: %d anomaly pairs, fewer than %d", ms$dur, ms$n_anom, MIN_REPORT)))
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
  p("The ", tags$b("Main findings"), " tab gives the paper's national results and regression tables, read from the ",
    "pipeline's output tables (steps 13, 15, 17, 20, 21 and 25) when the app data are built by step 24; nothing is typed ",
    "into the app. The ", tags$b("How the comparison works"), " tab works through the calculation for one monitor: ",
    "matching samples to scans, within-month anomalies, the two correlations, the within-site-month permutation test, ",
    "the noise ceiling and E, and the site-month bootstrap used to compare two correlations. Step 24 checks that the ",
    "app's code reproduces the paper's tables: the correlations of every site, every permutation p-value, every ",
    "site-level noise ceiling and E, and the Colorado window comparison. The single-scan noise of each monitor is the ",
    "one quantity read from the paper's output rather than recomputed, because the app data hold sample means, not ",
    "individual scans."),
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
            "split into equal thirds (dplyr::ntile), as in the paper's boundary-layer analysis; for 8 h and 3 h records both steps ",
            "are done within each sampling start hour, so that a third does not just collect one time of day. Whole-period r uses the same ",
            "samples. The all-sites panel applies the same calculation to every site of the national comparison.")),
  h4("Data and code"),
  p("The matched data are the released dataset of the paper, built by the R pipeline at ",
    a(META$repo, href = META$repo, target = "_blank"), " (folder ", code("dataset/"), "; the app is built by step 24). ",
    "TEMPO: NASA Langley ASDC, ", a("doi:10.5067/IS-40e/TEMPO/HCHO_L3.004", href = "https://doi.org/10.5067/IS-40e/TEMPO/HCHO_L3.004", target = "_blank"),
    ". Surface data: U.S. EPA AQS and CDPHE. Meteorology: NOAA HRRR. Smoke: NOAA HMS."),
  p(class = "small text-muted", "Data version: dataset md5 ", substr(META$dataset$md5, 1, 12), ".")
))

# ---- main findings: the regression results (Table 1, Tables S6 and S11, the geography models) ----
fmt_pv <- function(p) ifelse(is.na(p), "–", ifelse(p < 0.001, "< 0.001", sprintf("= %.3f", p)))
fmt_est <- function(x, d = 3) ifelse(is.na(x), "–", sub("^-", "−", sprintf(paste0("%+.", d, "f"), x)))
PRED_LABEL <- c(log_surface = "log median surface HCHO", log_snr = "log signal-to-noise ratio",
                log_scans = "log median valid scans", usable_pct = "usable share",
                pbl_hrrr_km = "HRRR mixing depth", smoke_share = "smoke-affected share",
                west = "west of 100° W", log_coast = "log distance to the coast", log_relief = "log terrain relief")
reg_table <- function(header, rows) tags$table(class = "table table-sm small mb-2",
  tags$thead(tags$tr(lapply(header, function(h) tags$th(HTML(h))))),
  tags$tbody(lapply(rows, function(r) tags$tr(lapply(r, function(v) tags$td(HTML(as.character(v))))))))
REGRESSIONS <- if (is.null(FIND)) NULL else local({
  card_md <- function(title, ...) card(card_header(tags$b(title)), card_body(...))
  # Table 1: the column coefficient by duration
  t1 <- FIND$table1
  coef_row <- if (is.null(t1)) NULL else t1[grepl("^Column coefficient", t1$row_label), , drop = FALSE]
  col_card <- card_md("Surface HCHO per unit column, by sample duration (Table 1)",
    p("Ordinary least squares of surface HCHO on the TEMPO column with monitor and calendar-month fixed effects, so the ",
      "coefficient describes variation within a monitor and month. ± is the site-clustered standard error; the four ",
      "3 h sites give a descriptive uncertainty only."),
    if (!is.null(coef_row) && nrow(coef_row) == 1)
      reg_table(c("", "24 h samples", "8 h samples", "3 h samples"),
                list(c("µg m⁻³ per 10¹⁵ molecules cm⁻²", coef_row[[2]], coef_row[[3]], coef_row[[4]]),
                     c("Samples with a usable scan", t1[t1$row_label == "Samples with a usable scan", 2],
                       t1[t1$row_label == "Samples with a usable scan", 3], t1[t1$row_label == "Samples with a usable scan", 4])))
    else p(class = "text-muted small", "Re-run step 24 after step 21 to add Table 1."),
    p(class = "small text-muted", "Paper: Table 1, Sect. 3.1."))
  # Tables S6 and the geography extension: site models
  sm <- FIND$site_models; gm <- FIND$geo_models
  model_rows <- function(d, model_name, with_se = TRUE) {
    d <- d[d$model == model_name & d$term != "(Intercept)", , drop = FALSE]
    lapply(seq_len(nrow(d)), function(i) c(PRED_LABEL[d$term[i]] %or% d$term[i],
      if (with_se) sprintf("%s (%.3f)", fmt_est(as.numeric(d$estimate_per_sd[i])), as.numeric(d$se[i])) else fmt_est(as.numeric(d$estimate_per_sd[i])),
      paste("p", fmt_pv(as.numeric(d$p[i])))))
  }
  m1 <- "M1: Fisher z of observed r ~ all six"; m2 <- "M2: Fisher z of E ~ all six"
  g1 <- "M1 + geography: Fisher z of observed r"; g2 <- "M2 + geography: Fisher z of E"
  r2 <- function(d, m, col) if (is.null(d) || !m %in% d$model) NA else as.numeric(d[[col]][d$model == m][1])
  site_card <- card_md("What distinguishes monitors with weak agreement (Tables S6 and the geography models)",
    p("Weighted least squares across the ", if (is.null(sm)) "" else format(r2(sm, m1, "n_sites")), " 24 h sites with a noise ceiling. ",
      HTML("Outcomes: the Fisher-transformed observed day-to-day correlation (M1) and the Fisher-transformed ratio E = r<sub>obs</sub>/r<sub>ceiling</sub> (M2). "),
      "Coefficients are per standard deviation of each predictor (the first three log-transformed), standard errors in ",
      "parentheses, weights n − 3 with n the number of anomaly pairs."),
    if (is.null(sm)) p(class = "text-muted small", "Re-run step 24 after step 20 to add the site models.") else
      layout_columns(col_widths = breakpoints(sm = 12, lg = c(6, 6)),
        div(h6(sprintf("M1: observed r (R² = %.2f, adjusted %.2f)", r2(sm, m1, "r2"), r2(sm, m1, "adj_r2"))),
            reg_table(c("Predictor", "Coefficient (SE)", ""), model_rows(sm, m1))),
        div(h6(sprintf("M2: E (R² = %.2f, adjusted %.2f)", r2(sm, m2, "r2"), r2(sm, m2, "adj_r2"))),
            reg_table(c("Predictor", "Coefficient (SE)", ""), model_rows(sm, m2)))),
    if (!is.null(gm)) tagList(
      p(class = "mt-2", HTML(sprintf(
        "Adding the three geographic descriptors raises R² for the observed correlation from %.2f to %.2f (nested F test, p %s) and for E from %.2f to %.2f (p %s). These descriptors were chosen after the geographic pattern was noticed, so the paper treats them as exploratory.",
        r2(gm, g1, "r2_base"), r2(gm, g1, "r2_with_geography"), fmt_pv(r2(gm, g1, "p_geography")),
        r2(gm, g2, "r2_base"), r2(gm, g2, "r2_with_geography"), fmt_pv(r2(gm, g2, "p_geography"))))),
      layout_columns(col_widths = breakpoints(sm = 12, lg = c(6, 6)),
        div(h6("M1 + geography: observed r"), reg_table(c("Predictor", "Coefficient", ""), model_rows(gm, g1, with_se = FALSE))),
        div(h6("M2 + geography: E"), reg_table(c("Predictor", "Coefficient", ""), model_rows(gm, g2, with_se = FALSE))))),
    p(class = "small text-muted", "Paper: Sect. 3.4, Table S6, Fig. S6b."))
  # Table S11: the mixing-depth interactions
  pi <- FIND$pbl_int
  int_card <- card_md("Does the column–surface slope change with mixing depth? (Table S11 interactions)",
    p("Regression of the surface anomaly on the column anomaly, the HRRR mixing-depth anomaly and their interaction, all ",
      "standardized, with site-clustered standard errors. The interaction is the change in the column–surface slope per ",
      "standard deviation of mixing depth. The adjusted model also lets the slope depend on the number of valid scans ",
      "and on the site-month column level, so that a signal-to-noise effect cannot masquerade as a mixing effect."),
    if (is.null(pi)) p(class = "text-muted small", "Re-run step 24 after step 20 to add the interaction models.") else local({
      d <- pi[pi$term == "col_std:pbl_std", , drop = FALSE]
      adj <- grepl("competing", d$model)
      rows <- lapply(seq_len(nrow(d)), function(i) c(d$sample[i], if (adj[i]) "with scan count and column level" else "mixing depth only",
        format(as.integer(d$n[i]), big.mark = ","), sprintf("%s (%.3f)", fmt_est(as.numeric(d$estimate[i])), as.numeric(d$se_cluster[i])),
        paste("p", fmt_pv(as.numeric(d$p[i])))))
      reg_table(c("Samples", "Model", "n", "Interaction (SE)", ""), rows)
    }),
    p(class = "small text-muted", "Paper: Sect. 3.5, Table S11, Fig. 4."))
  tagList(h5(class = "mt-3", "Regression results"), col_card, site_card, int_card)
})

# ---- main findings: the paper's national results, from the pipeline's tables ----------
FN  <- function(k) { v <- if (is.null(FIND)) NA else unname(FIND$nums[k]); if (length(v) != 1 || is.na(v)) "\u2013" else sub("^-", "\u2212", v) }
F2  <- function(x) if (length(x) != 1 || is.na(x)) "\u2013" else sub("^-", "\u2212", sprintf("%.2f", x))
FROW <- function(tab, ...) { if (is.null(tab)) return(NULL); k <- Reduce(`&`, list(...)); r <- tab[k, , drop = FALSE]; if (nrow(r) == 1) r else NULL }
MAIN_FINDINGS <- if (is.null(FIND)) div(class = "alert alert-secondary", "Re-run step 24 to add the paper's national results.") else local({
  p24  <- FROW(FIND$pooled, FIND$pooled$duration_class == "24 h", FIND$pooled$lag_h == 0)
  ce3  <- FROW(FIND$ceiling, FIND$ceiling$block_label == "3x3")
  ofx  <- FROW(FIND$obs_fx, FIND$obs_fx$arm == "National (24 h)")
  opr  <- FROW(FIND$obs_pair, FIND$obs_pair$arm == "National (24 h)", FIND$obs_pair$stratum == "all")
  pct  <- 100 * FIND$n24[["usable"]] / FIND$n24[["samples"]]
  card_md <- function(title, ...) card(card_header(tags$b(title)), card_body(...))
  tagList(
    div(class = "alert alert-light border small mb-3",
        tags$b("The paper's national results. "),
        "Unless stated otherwise, these are for the national 24 h samples of 2024\u20132025 at the primary screening ",
        "(3 \u00d7 3 grid cells, effective cloud fraction \u2264 0.2, scans inside the sampling window). The ",
        tags$b("Explore"), " tab shows individual monitors."),
    layout_column_wrap(width = "220px", fill = FALSE, class = "mb-3",
      value_box("Samples with a usable TEMPO observation", sprintf("%.0f%%", pct),
                p(sprintf("%d of %d national 24 h samples", FIND$n24[["usable"]], FIND$n24[["samples"]]))),
      value_box("Pooled whole-period r", F2(p24$pearson_r),
                p(sprintf("%d samples at %d sites", p24$n, FIND$n24[["sites"]]))),
      value_box("Pooled day-to-day r", F2(p24$anom_pearson_r),
                p(sprintf("%d within-month anomaly pairs", p24$anom_n))),
      value_box("Median day-to-day r across monitors", FN("site_dd_median_24"),
                p(sprintf("interquartile range %s\u2013%s; range %s to %s over %s sites", FN("site_dd_q25_24"),
                          FN("site_dd_q75_24"), FN("site_dd_min_24"), FN("site_dd_max_24"), FN("n_sites_24"))))),
    layout_columns(col_widths = breakpoints(sm = 12, lg = c(6, 6)),
      card_md("Agreement differs widely between monitors",
        p("Day-to-day agreement is positive at most monitors but ranges from ", FN("site_dd_min_24"), " to ",
          FN("site_dd_max_24"), ", and most of that variation lies among monitors within the same state. ",
          "A single network-wide satellite-to-surface relationship should therefore not be applied to an individual ",
          "monitor without local evaluation. The map on the Explore tab shows each monitor."),
        p(class = "small text-muted", "Paper: Sect. 3.2, Figs. 1\u20132.")),
      card_md("Scatter between scans sets an estimated ceiling",
        p("If the scatter between successive scans (no more than 1.6 h apart) were entirely retrieval noise, and ",
          "that noise the only source of disagreement, the pooled day-to-day correlation could reach about ",
          F2(ce3$ceiling_empirical), "; the observed value is ", F2(ce3$anomaly_r_observed), ". At individual monitors ",
          "the estimated ceilings are similar (median ", FN("nat_site_ceiling_median"), "), but observed correlations ",
          "reach a median of only ", FN("nat_site_rcorr_median"), " of them, so noise explains only part of the ",
          "disagreement. The How the comparison works tab shows the calculation for any 24 h monitor."),
        p(class = "small text-muted", "The ceiling is an estimate: real change in the column between scans inflates ",
          "the noise estimate, and errors that persist through the day are invisible to it. Paper: Sect. 3.3."))),
    layout_columns(col_widths = breakpoints(sm = 12, lg = c(6, 6)),
      card_md("Averaging scans improves agreement",
        plotlyOutput("p_find_avg", height = "300px"),
        p(class = "small", "On one fixed set of ", FN("ta_samples"), " samples with at least four valid scans, a single ",
          "randomly chosen scan of the 3 \u00d7 3 block gives a pooled day-to-day r of ", FN("ta_r1_33"),
          " and the mean of all scans ", FN("ta_rall_33"), ". Because the samples are the same at every point, this ",
          "isolates the effect of averaging; the \u201cvalid scans\u201d thirds on the How agreement varies tab ",
          "compare different days and do not."),
        p(class = "small text-muted", "Bars: 2.5\u201397.5% range over random draws. Paper: Sect. 3.3, Fig. 3.")),
      card_md("Agreement rises with modelled mixing depth for 8 h samples",
        plotlyOutput("p_find_pbl", height = "300px"),
        p(class = "small", "For 8 h samples starting at 04:00 LST, the pooled anomaly correlation rose from ",
          FN("pbl_8h4_r_low"), " in the shallowest third of HRRR mixing depth to ", FN("pbl_8h4_r_high"),
          " in the deepest (difference ", FN("pbl_8h4_diff"), ", 95% CI ", FN("pbl_8h4_lo"), " to ", FN("pbl_8h4_hi"),
          "). The association persisted after allowing for the number of scans and the column level (interaction ",
          FN("pbl_int_adj_8h4"), ", ", FN("pbl_int_adj_8h4_ptxt"), ") and, at about half the size, on smoke-free ",
          "days. For 24 h samples it disappeared once scan count and column level were allowed for (interaction ",
          FN("pbl_int_adj_24"), ", ", FN("pbl_int_adj_24_ptxt"), ")."),
        p(class = "small text-muted", "These are pooled analyses, with thirds formed within each start hour over all ",
          "sites. The How agreement varies tab forms thirds site by site and shows medians across monitors, an ",
          "exploratory view. Paper: Sect. 3.5, Fig. 4."))),
    layout_columns(col_widths = breakpoints(sm = 12, lg = c(6, 6)),
      card_md("Agreement is weakest in winter",
        p(HTML(paste0("For 24 h samples the pooled correlation was ", FN("seas_r_24_djf"), " in winter (95% CI ", FN("seas_rlo_24_djf"),
          " to ", FN("seas_rhi_24_djf"), "), against ", FN("seas_r_24_jja"), " in summer; the day-to-day correlation was ",
          FN("seas_dd_24_djf"), " in winter and ", FN("seas_dd_24_jja"), " in summer, positive in every season. The column's ",
          "seasonal cycle is larger than the surface's (relative seasonal range a median ", FN("seas_amp_ratio_median"),
          " times that of the surface over ", FN("seas_amp_sites"), " sites), and a small winter column is harder to distinguish from roughly constant retrieval noise."))),
        p(class = "small text-muted", "Paper: Sect. 3.1, Table S4, Fig. S5.")),
      card_md("Agreement is generally stronger on smoke-affected days",
        p(HTML(paste0("At the 24 h sites the pooled correlation rose from ", FN("smoke_r_24_none"), " on smoke-free days to ",
          FN("smoke_r_24_light"), " under light smoke and ", FN("smoke_r_24_heavy"), " under medium or heavy smoke; excluding ",
          "smoke-affected days reduced the national day-to-day correlation from ", FN("smoke_dd_24_all"), " to ",
          FN("smoke_dd_24_nosmoke"), " for 24 h samples and from ", FN("smoke_dd_8_all"), " to ", FN("smoke_dd_8_nosmoke"),
          " for 8 h samples. Columns were about twice as high under smoke (", FN("smoke_col_24_none"), " against ",
          FN("smoke_col_24_light"), " × 10¹⁵ molecules cm⁻²), so the satellite signal stands further above the noise."))),
        p(class = "small text-muted", HTML(paste0("Smoke: NOAA HMS polygons over the site within the sampling window widened by 3 h. ",
          "Season explains part of the 24 h contrast (smoke affected ", FN("smoke_pct_24_jja"), "% of summer samples and ",
          FN("smoke_pct_24_djf"), "% of winter samples), but the summer-only 8 h records show the same decline. Paper: Sect. 3.4, Table S7, Fig. S7."))))),
    card_md("Days TEMPO can use are not representative",
      p("After allowing for monitor and calendar month, surface HCHO was ", F2(ofx$beta_observable_minus_screened),
        " \u00b5g m\u207b\u00b3 higher on days with a usable TEMPO observation than on days when TEMPO observed the ",
        "site but every scan was screened out (95% CI ", F2(ofx$ci_lo), " to ", F2(ofx$ci_hi), "; ", ofx$n,
        " samples at ", ofx$sites, " monitors); paired differences within site-months give ",
        F2(opr$paired_observable_minus_screened), " (", F2(opr$boot_lo), " to ", F2(opr$boot_hi), ")."),
      p(class = "small text-muted", "This is a difference between two kinds of day, about ",
        sprintf("%.0f%%", ofx$pct_of_median), " of the median concentration; it is not the bias of an all-day mean, ",
        "which also depends on how many days fall in each group. Days without any TEMPO granule are excluded. ",
        "Paper: Sect. 3.6, Fig. 5.")),
    REGRESSIONS,
    p(class = "small text-muted mt-2", "All numbers on this page are read from the paper's analysis output (see About)."))
})

# ---- how the comparison works: the paper's calculation, worked on one monitor -----------
WK_DEFAULT <- if ("04-013-9997" %in% SITES$site_id) "04-013-9997" else DEFAULT_SITE
WK_BOOT_SITES <- c("Chatfield State Park" = "08-035-0004", "Platteville" = "08-123-0008", "Both sites together" = "all")
WK_BOOT_KEY   <- c("08-035-0004" = "chco", "08-123-0008" = "pvco", all = "all")
WK_HI  <- "#d95f02"   # the example month, wherever it appears
f2s <- function(x, d = 2) if (length(x) != 1 || is.na(x)) "–" else sub("^-", "−", formatC(x, format = "f", digits = d))
f2p <- function(x, d = 2) if (length(x) != 1 || is.na(x)) "–" else
  paste0(if (x >= 0) "+" else "−", formatC(abs(x), format = "f", digits = d))
fmt_p <- function(p) if (is.na(p)) "–" else if (p < 0.001) sprintf("%.4f", p) else sprintf("%.3f", p)
month_name <- function(ym) format(as.Date(paste0(ym, "-01")), "%B %Y")
step_card <- function(n, title, ...) card(class = "mb-3",
  card_header(span(class = "badge bg-primary me-2", n), tags$b(title)), card_body(...))
wk_table <- function(df, bold = rep(FALSE, nrow(df)), hi = NULL) {
  tags$table(class = "table table-sm small mb-2", style = "width:auto; white-space:nowrap;",
    tags$thead(tags$tr(lapply(names(df), function(h) tags$th(class = "text-end", HTML(h))))),
    tags$tbody(lapply(seq_len(nrow(df)), function(i) tags$tr(
      style = if (bold[i]) paste0("font-weight:bold; background:#fdf0e6;") else NULL,
      lapply(df[i, ], function(v) tags$td(class = "text-end", HTML(as.character(v))))))))
}

WORKED <- tagList(
  div(class = "alert alert-light border small mb-3",
      tags$b("How the comparison works. "),
      "This page repeats the paper's calculation for one monitor, step by step, on its real samples. Choose a monitor, ",
      "a month and a sample; every number is recomputed from the released data with the app's own code, which is ",
      "checked against the paper's tables when the app is built (see About). The page uses all days and seasons at the ",
      "paper's primary screening; the filters on the Explore tab do not apply here."),
  card(class = "mb-3", card_body(
    layout_columns(col_widths = breakpoints(sm = 12, md = c(4, 3, 2, 3)),
      selectInput("wk_site", "Monitoring site", choices = CHOICES, selected = WK_DEFAULT),
      uiOutput("wk_rec_ui"), uiOutput("wk_month_ui"), uiOutput("wk_date_ui")))),
  step_card(1, "Match each surface sample with TEMPO", uiOutput("wk_s1")),
  step_card(2, "Remove each month's mean (within-month anomalies)", uiOutput("wk_s2")),
  step_card(3, "Two correlations: whole period and day to day",
    uiOutput("wk_s3"),
    layout_columns(col_widths = breakpoints(sm = 12, lg = c(6, 6)),
                   plotlyOutput("wk_p_raw", height = "320px"), plotlyOutput("wk_p_anom", height = "320px"))),
  step_card(4, "Is the day-to-day correlation more than chance? (permutation test)",
    uiOutput("wk_s4"),
    layout_columns(col_widths = breakpoints(sm = 12, lg = c(7, 5)),
                   plotlyOutput("wk_p_perm", height = "300px"), uiOutput("wk_s4_shuffle"))),
  step_card(5, "How high could the correlation be? (noise ceiling and E)", uiOutput("wk_s5")),
  step_card(6, "Is one correlation higher than another? (site-month bootstrap)",
    div(class = "small mb-2",
        "The paper's example: at the two Colorado 3 h sites, do TEMPO scans from the three hours ", tags$i("after"),
        " sampling (09:00–12:00 MST) track the 06:00–09:00 surface samples better than the scans made ",
        tags$i("during"), " sampling? Both correlations share the same surface anomalies, so they are compared on the ",
        "same samples: those with valid scans in both windows."),
    div(class = "d-flex flex-wrap align-items-center gap-3 mb-2",
        radioButtons("wk_boot_site", NULL, inline = TRUE, choices = WK_BOOT_SITES),
        actionButton("wk_draw", "Draw one resample", class = "btn-sm btn-outline-primary")),
    uiOutput("wk_s6"),
    layout_columns(col_widths = breakpoints(sm = 12, lg = c(7, 5)),
                   plotlyOutput("wk_p_boot", height = "300px"), uiOutput("wk_draw_out"))),
  p(class = "small text-muted", "Paper: Sect. 2.3 (anomalies, permutation test, bootstrap, noise ceiling), ",
    "Sect. 3.3 (ceiling), Sect. 3.5 (Colorado windows); Supplement Sects. S3–S4.")
)

# ---- UI --------------------------------------------------------------------------------
ui <- page_navbar(
  title = "TEMPO vs ground-based formaldehyde (HCHO)",
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  header = tags$style(HTML(".leaflet-container { background: #e8edf1; }")),
  fillable = FALSE,
  nav_panel("Main findings", MAIN_FINDINGS),
  nav_panel("How the comparison works", WORKED),
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
                "checked group; AQS lists the networks.",
                if (any(!IS_NAT)) sprintf(" Counts include %s, which is in the Colorado analysis only.",
                                          paste(SITES$name[!IS_NAT], collapse = ", ")) else "")),
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
                         div(class = "d-flex align-items-center gap-2",
                             span(class = "text-muted", "Record shown:"),
                             div(style = "margin-bottom: -1rem;", radioButtons("map_dur", NULL, inline = TRUE,
                                                               choices = MAP_DUR_CHOICES, selected = "longest"))),
                         div(class = "d-flex gap-3",
                             span(class = "text-muted", "Zoom to:"),
                             actionLink("zoom_us", "Whole US"),
                             actionLink("zoom_co", "Colorado"),
                             actionLink("zoom_site", "Selected site"))),
             leafletOutput("map", height = 560),
             card_footer(class = "small text-muted",
                         "Colour: day-to-day correlation with TEMPO of the record chosen above (by default each ",
                         "site's longest-duration record, so 24 h, 8 h and 3 h sites are mixed; choose a duration to ",
                         "compare like with like), sampling window, for the smoke and season filters at left. Grey: fewer than 10 ",
                         "within-month anomaly pairs. Black outline: Colorado sites with CDPHE air-toxics data. ",
                         "Sites follow the network filter at left. ",
                         "Background layers are in the control at the top right of the map; the expand ",
                         "icon at the bottom right of this card shows the map full screen.")),
        navset_card_tab(id = "tab", full_screen = TRUE,
          nav_panel("TEMPO vs surface HCHO", value = "tempo",
            uiOutput("tempo_boxes"),
            uiOutput("ts_note"),
            plotlyOutput("p_ts", height = "480px"),
            layout_columns(col_widths = breakpoints(sm = 12, lg = c(6, 6)),
                           plotlyOutput("p_scatter", height = "330px"),
                           plotlyOutput("p_anom", height = "330px")),
            plotlyOutput("p_obs", height = "300px"),
            div(class = "mt-2", downloadButton("dl_tempo", "Download these samples (CSV)", class = "btn-sm"))),
          nav_panel("How agreement varies", value = "sens",
            div(class = "small text-muted mt-2 mb-2",
                "How the agreement between surface HCHO and the TEMPO column changes with the conditions and the choices ",
                "of the comparison. Each row changes one setting; screening and subgroup choices also change which samples ",
                "are included, so rows do not always compare the same samples. Grey diamonds: whole-period r; ",
                "blue circles: day-to-day r (within-month anomalies). Faded: fewer than 10 samples or pairs, which the ",
                "paper does not report. Thirds: the samples entering the day-to-day correlation split into equal thirds ",
                "by that variable, as in the paper's boundary-layer analysis (for 8 h and 3 h records, within each ",
                "sampling start hour). Deep boundary layers and warm days fall ",
                "mostly in summer; the row “relative to its month mean” separates the day-to-day effect from the seasonal one."),
            h5("This site"),
            uiOutput("sens_site_head"),
            uiOutput("sens_site_ui"),
            tags$details(class = "mb-2", tags$summary("Show the numbers"), DTOutput("sens_site_table")),
            downloadButton("dl_sens", "Download this table (CSV)", class = "btn-sm"),
            hr(),
            h5("All national sites"),
            div(class = "alert alert-warning py-2 small mb-2",
                tags$b("Medians across monitors; bars show the spread between monitors (interquartile range), not ",
                       "confidence intervals. The smoke and season filters at left do not apply here."),
                " The paper's pooled results, including its mixing-depth analysis, are on the Main findings tab."),
            div(class = "small text-muted mb-2",
                "Every site of the national comparison at the paper's primary configuration, changing one thing at a ",
                "time (computed with the app's own code; see About). Points: median across the sites with at least 10 samples ",
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
      add_site_markers(isolate(map_stats(input$smoke %or% "all", input$seasons %or% character(),
                                         input$map_dur %or% "longest")),
                       isolate(filter_text(input$smoke %or% "all", input$seasons %or% character())),
                       isolate(map_show(map_stats(input$smoke %or% "all", input$seasons %or% character(),
                                                  input$map_dur %or% "longest"),
                                        input$nets %or% character(), input$map_dur %or% "longest"))) |>
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
    sm <- input$smoke %or% "all"; se <- input$seasons %or% character(); du <- input$map_dur %or% "longest"
    ms <- map_stats(sm, se, du)
    leafletProxy("map") |> add_site_markers(ms, filter_text(sm, se), map_show(ms, input$nets %or% character(), du))
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

  output$ts_note <- renderUI({
    req(nrow(sel_all()) > 0)
    div(class = "small text-muted mb-1",
        sprintf(paste0("Every %d h surface sample at this monitor, in date order: this is one site's record, not an ",
                       "average across sites. Each TEMPO point is the mean of all usable scans (effective cloud ",
                       "fraction \u2264 0.2) over the 3 \u00d7 3 block of grid cells (about 7 \u00d7 5 km) around ",
                       "the monitor, during %s. Filters at left apply. The lines on the scatter plots are ordinary least-squares fits ",
                       "shown for orientation; the paper reports reduced major axis slopes (Supplement Sect. S3)."),
                cur_dur(), if (cur_lag() == 0) "that sample's own sampling window"
                           else sprintf("the sampling window shifted by %+d h", cur_lag())))
  })

  # ---- main findings plots
  output$p_find_avg <- renderPlotly({
    a <- FIND$averaging
    validate(need(!is.null(a) && nrow(a) > 0, "The temporal-averaging table is not in the app data."))
    a$k <- as.character(a$k_scans); a$x <- ifelse(a$k == "all", 5, suppressWarnings(as.numeric(a$k)))
    blocks <- c("1x1" = "1 \u00d7 1 grid cell", "3x3" = "3 \u00d7 3 block", "5x5" = "5 \u00d7 5 block")
    cols <- c("1x1" = "#9ecae1", "3x3" = "#2166ac", "5x5" = "#08306b")
    p <- plot_ly()
    for (b in intersect(names(blocks), unique(a$block))) {
      s <- a[a$block == b, ]; s <- s[order(s$x), ]
      p <- add_trace(p, x = s$x, y = s$r_pooled, type = "scatter", mode = "lines+markers", name = blocks[[b]],
                     line = list(color = cols[[b]]), marker = list(color = cols[[b]], size = 7),
                     error_y = list(type = "data", symmetric = FALSE, array = s$r_pooled_hi - s$r_pooled,
                                    arrayminus = s$r_pooled - s$r_pooled_lo, color = cols[[b]], thickness = 1, width = 3),
                     text = sprintf("%s, %s scan(s): r = %.2f", blocks[[b]], s$k, s$r_pooled), hoverinfo = "text")
    }
    p |> layout(xaxis = list(title = "Scans averaged per 24 h sample", tickvals = 1:5, ticktext = c("1", "2", "3", "4", "all")),
                yaxis = list(title = "Pooled day-to-day r"), legend = list(orientation = "h", y = -0.25),
                margin = list(t = 10))
  })
  output$p_find_pbl <- renderPlotly({
    t <- FIND$pbl
    validate(need(!is.null(t) && nrow(t) > 0, "The mixing-depth table is not in the app data."))
    t <- t[t$stratification == "absolute HRRR mixing depth", ]
    t$sample <- factor(t$sample, levels = c("8 h, start 04:00 LST", "8 h, start 12:00 LST", "24 h"),
                       labels = c("8 h from 04:00 LST", "8 h from 12:00 LST", "24 h"))
    t$third <- factor(t$tert, levels = 1:3, labels = c("shallowest third", "middle third", "deepest third"))
    plot_ly(t, x = ~sample, y = ~r, color = ~third, colors = c("#c6dbef", "#6baed6", "#08519c"), type = "bar",
            text = ~sprintf("%.2f", r), textposition = "outside",
            hovertext = ~sprintf("%s, %s<br>r = %.2f (n = %d)<br>median mixing depth %.2f km", sample, third, r, n,
                                 pbl_median_km), hoverinfo = "text") |>
      layout(barmode = "group", yaxis = list(title = "Pooled day-to-day r", range = c(0, 0.75)),
             xaxis = list(title = ""), legend = list(orientation = "h", y = -0.2), margin = list(t = 10))
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
      layout(yaxis = list(title = list(text = paste0("Surface HCHO<br>(", U_CONC, ")"), standoff = 8)))
    u <- d[d$usable, ]
    if (nrow(u)) {
      u$smoke_lab <- factor(ifelse(is.na(u$smoke), "no HMS data", u$smoke), levels = names(SMOKE_COL))
      bot <- plot_ly(u, x = ~date, y = ~column, color = ~smoke_lab, colors = SMOKE_COL,
                     type = "scatter", mode = "markers", marker = list(size = 6),
                     text = sprintf("%s<br>TEMPO column %.2f<br>%d valid scans<br>smoke: %s<br>boundary layer: HRRR %s km, TEMPO %s km<br>temperature (HRRR) %s °C",
                                    format(u$date), u$column, u$n_valid, as.character(u$smoke_lab),
                                    fmt_num(u$hrrr_pbl_km, 2), fmt_num(u$tempo_pbl_km, 2), fmt_num(u$temp_c, 1)),
                     hoverinfo = "text") |>
        layout(yaxis = list(title = list(text = paste0("TEMPO column<br>(", U_COL, ")"), standoff = 8)))
    } else {
      bot <- plotly_empty(type = "scatter", mode = "markers")
    }
    subplot(top, bot, nrows = 2, shareX = TRUE, titleY = TRUE, heights = c(0.5, 0.5), margin = 0.04) |>
      layout(margin = list(l = 95, t = 30),
             annotations = list(
               list(text = "<b>Surface HCHO</b>, one point per sample (open: no usable TEMPO observation)",
                    x = 0, y = 1, xref = "paper", yref = "paper", xanchor = "left", yanchor = "bottom",
                    showarrow = FALSE, font = list(size = 12)),
               list(text = "<b>TEMPO column</b> for the same samples, coloured by NOAA HMS smoke",
                    x = 0, y = 0.46, xref = "paper", yref = "paper", xanchor = "left", yanchor = "bottom",
                    showarrow = FALSE, font = list(size = 12))),
             legend = list(orientation = "h", y = -0.1, title = list(text = "Smoke: ")),
             xaxis = list(title = ""))
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
      layout(title = list(text = sprintf("Whole period: r = %s (n = %d)<br><span style='font-size:11px'>least squares: surface = %.2f + %.3f × column</span>",
                                         fmt_r(s$r), s$n, coef(fit)[[1]], coef(fit)[[2]]), font = list(size = 13)),
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
      layout(title = list(text = sprintf("Day to day (within-month anomalies): r = %s (%d pairs)<br><span style='font-size:11px'>least squares: slope %.3f µg m⁻³ per 10¹⁵ molecules cm⁻²</span>",
                                         fmt_r(s$r_anom), s$n_anom, coef(fit)[[2]]), font = list(size = 13)),
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
  # ---- how the comparison works ------------------------------------------------------
  wk_site <- reactive({ req(input$wk_site); SITES[SITES$site_id == input$wk_site, ][1, ] })
  wk_arm  <- reactive({
    a <- unique(TEMPO$arm[TEMPO$site_id == input$wk_site & TEMPO$lag_h == 0L])
    if ("national" %in% a) "national" else a[1]
  })
  output$wk_rec_ui <- renderUI({
    du <- sort(unique(TEMPO$duration_h[TEMPO$site_id == input$wk_site & TEMPO$arm == wk_arm()]), decreasing = TRUE)
    radioButtons("wk_dur", "Record", inline = TRUE, choices = setNames(as.character(du), paste(du, "h samples")))
  })
  wk_all <- reactive({   # every sample of the record, usable or not
    req(input$wk_dur)
    d <- TEMPO[TEMPO$site_id == input$wk_site & TEMPO$arm == wk_arm() & TEMPO$duration_h == as.integer(input$wk_dur) &
                 TEMPO$lag_h == 0L, ]
    validate(need(nrow(d) > 0, "Choose a record."))
    d[order(d$start_utc), ]
  })
  wk_use <- reactive(wk_all()[wk_all()$usable & is.finite(wk_all()$column), ])
  wk_ps  <- reactive({ d <- wk_use(); pair_stats(d$date, d$hcho, d$column) })
  wk_an  <- reactive({   # anomalies with their samples' values and month means
    d <- wk_use(); an <- wk_ps()$anom
    validate(need(nrow(an) >= 3, "This record has fewer than three samples in any month, so no within-month anomalies can be formed."))
    an$hcho <- d$hcho[an$i]; an$column <- d$column[an$i]; an$n_valid <- d$n_valid[an$i]
    an$start_utc <- d$start_utc[an$i]
    an$hcho_mean <- an$hcho - an$surface_anom; an$column_mean <- an$column - an$column_anom
    an$m <- stats::ave(seq_along(an$ym), an$ym, FUN = length)
    an
  })
  output$wk_month_ui <- renderUI({
    an <- wk_an(); tb <- table(an$ym)
    pick <- names(tb)[which.max(tb)]
    selectInput("wk_month", "Example month", selected = pick,
                choices = setNames(names(tb), sprintf("%s (%d)", month_name(names(tb)), as.integer(tb))))
  })
  wk_month <- reactive({ an <- wk_an(); req(input$wk_month %in% an$ym); an[an$ym == input$wk_month, ] })
  output$wk_date_ui <- renderUI({
    m <- wk_month()
    selectInput("wk_date", "Example sample", choices = setNames(as.character(m$start_utc),
                format(m$start_utc, "%d %b %Y %H:%M UTC", tz = "UTC")))
  })
  wk_row <- reactive({
    m <- wk_month(); k <- match(input$wk_date, as.character(m$start_utc))
    if (is.na(k)) k <- 1L
    m[k, ]
  })

  output$wk_s1 <- renderUI({
    r <- wk_row(); a <- wk_all(); u <- wk_use(); du <- as.integer(input$wk_dur)
    end <- r$start_utc + du * 3600
    full <- a[a$start_utc == r$start_utc, ][1, ]
    tagList(
      p(HTML(sprintf("The %d h surface sample that began at %s UTC on %s and ended at %s UTC on %s measured <b>%s %s</b>.",
                du, format(r$start_utc, "%H:%M", tz = "UTC"), format(r$start_utc, "%d %B %Y", tz = "UTC"),
                format(end, "%H:%M", tz = "UTC"), format(end, "%d %B %Y", tz = "UTC"), f2s(r$hcho), U_CONC))),
      p(sprintf("TEMPO scanned the monitor %d times while the sample was being collected (the midpoint of each scan ",
                full$n_scans),
        "inside the sampling window). For each scan we average the 3 × 3 grid cells around the monitor that pass ",
        "the screening (main quality flag 0, effective cloud fraction ≤ 0.2, solar zenith angle ≤ 70°, no ",
        "snow or ice); a scan counts as valid when at least five of the nine cells pass. ",
        HTML(sprintf("Here %d of the %d scans were valid, and the TEMPO value for this sample is their mean: <b>%s × %s</b>.",
                     r$n_valid, full$n_scans, f2s(r$column), U_COL))),
      p(class = "small text-muted", sprintf(
        "A sample with no valid scan has no TEMPO value and is left out: %d of this record's %d samples had at least one valid scan.",
        nrow(u), nrow(a)),
        if (du == 24L) " TEMPO observes only in daylight, so for a 24 h sample the scans cover the daytime part of the sample." else ""))
  })

  output$wk_s2 <- renderUI({
    m <- wk_month(); r <- wk_row(); an <- wk_an(); ps <- wk_ps()
    n_months_all <- length(unique(format(wk_use()$date, "%Y-%m")))
    bold <- m$start_utc == r$start_utc
    tab <- data.frame(
      Date = format(m$start_utc, "%d %b", tz = "UTC"),
      `Surface (µg m<sup>−3</sup>)` = sapply(m$hcho, f2s),
      `Month mean` = sapply(m$hcho_mean, f2s),
      `Surface anomaly` = sapply(m$surface_anom, f2p),
      `TEMPO (10<sup>15</sup> molec. cm<sup>−2</sup>)` = sapply(m$column, f2s),
      `Month mean ` = sapply(m$column_mean, f2s),
      `Column anomaly` = sapply(m$column_anom, f2p), check.names = FALSE)
    tagList(
      p(sprintf("Every month of every year is treated separately. In %s this monitor has %d samples with a TEMPO value; ",
                month_name(r$ym), nrow(m)),
        "the mean of each series over that month is subtracted from every sample of the month. For the highlighted sample:"),
      div(class = "ps-3 mb-2",
        div(sprintf("Surface anomaly = %s − %s = %s %s", f2s(r$hcho), f2s(r$hcho_mean), f2p(r$surface_anom), U_CONC)),
        div(sprintf("Column anomaly = %s − %s = %s × %s", f2s(r$column), f2s(r$column_mean), f2p(r$column_anom), U_COL))),
      wk_table(tab, bold),
      p(class = "small", "The anomalies of each month add up to zero, so the seasonal cycle, and any offset between ",
        "monitor and satellite that stays the same through the month, is removed. What remains asks a narrower question: ",
        "does TEMPO see which days were higher or lower than usual for that month?"),
      p(class = "small text-muted", sprintf(
        "Months with fewer than three samples are left out, because a mean of one or two samples says little: %d of the record's %d months qualify, giving %d anomaly pairs.",
        length(unique(an$ym)), n_months_all, nrow(an))))
  })

  wk_scatter <- function(x, y, hi, xlab, ylab, title) {
    plot_ly() |>
      add_markers(x = x[!hi], y = y[!hi], name = "other months", marker = list(color = "#9aa7b4", size = 6, opacity = 0.7),
                  hoverinfo = "x+y") |>
      add_markers(x = x[hi], y = y[hi], name = "example month", marker = list(color = WK_HI, size = 9,
                  line = list(color = "#7a3500", width = 1)), hoverinfo = "x+y") |>
      layout(title = list(text = title, font = list(size = 13)), xaxis = list(title = xlab, zeroline = FALSE),
             yaxis = list(title = list(text = ylab, standoff = 8), zeroline = FALSE, automargin = TRUE),
             legend = list(orientation = "h", y = -0.25), margin = list(l = 70))
  }
  output$wk_s3 <- renderUI({
    ps <- wk_ps(); an <- wk_an()
    low <- ps$n < MIN_REPORT || ps$n_anom < MIN_REPORT
    tagList(
      p(tags$b("Whole-period r"), sprintf(" correlates the %d samples' surface values with their TEMPO values: r = %s. ", ps$n, f2s(ps$r)),
        "It mixes the seasonal cycle, which surface and column share, with day-to-day changes. ",
        tags$b("Day-to-day r"), sprintf(" correlates the %d pairs of anomalies from step 2 (in %d site-months): r = %s. ",
                                         ps$n_anom, length(unique(an$ym)), f2s(ps$r_anom)),
        "This is the paper's main measure of agreement. The example month is shown in orange in both panels."),
      if (low) p(class = "small text-warning", sprintf(
        "The paper reports a monitor only with at least %d matched samples and %d anomaly pairs; this record has fewer.",
        MIN_REPORT, MIN_REPORT)))
  })
  output$wk_p_raw <- renderPlotly({
    d <- wk_use(); hi <- format(d$date, "%Y-%m") == input$wk_month
    wk_scatter(d$column, d$hcho, hi, paste0("TEMPO column (", U_COL, ")"), paste0("Surface HCHO (", U_CONC, ")"),
               sprintf("Whole period: r = %s (n = %d)", f2s(wk_ps()$r), wk_ps()$n))
  })
  output$wk_p_anom <- renderPlotly({
    an <- wk_an(); hi <- an$ym == input$wk_month
    wk_scatter(an$column_anom, an$surface_anom, hi, paste0("Column anomaly (", U_COL, ")"), paste0("Surface anomaly (", U_CONC, ")"),
               sprintf("Day to day: r = %s (%d pairs)", f2s(wk_ps()$r_anom), wk_ps()$n_anom))
  })

  wk_perm <- reactive(perm_test(wk_an()))
  output$wk_s4 <- renderUI({
    pt <- wk_perm(); validate(need(!is.null(pt), "Too few samples for a permutation test."))
    tagList(
      p("If the TEMPO column carried no information about day-to-day changes at the surface, any pairing of a ",
        "month's surface anomalies with that month's column anomalies would be as likely as the observed one. So we ",
        "shuffle the surface anomalies among the days of each site-month (the values stay in their own month, so each ",
        sprintf("month's anomalies still add up to zero), recompute r, and repeat %s times. ", format(pt$nperm, big.mark = ",")),
        "The histogram shows the shuffled correlations."),
      div(class = "ps-3 mb-2",
        div(sprintf("Shuffles with |r| at least as large as the observed |r| = %s: %d of %s",
                    f2s(abs(pt$r_obs)), pt$ge, format(pt$nperm, big.mark = ","))),
        div(tags$b(sprintf("p = (%d + 1) / (%s + 1) = %s", pt$ge, format(pt$nperm, big.mark = ","), fmt_p(pt$p))))),
      p(class = "small text-muted", "The +1 counts the observed pairing as one of the possible arrangements, so the ",
        sprintf("smallest possible p is 1/%s ≈ %s. ", format(pt$nperm + 1, big.mark = ","), fmt_p(1 / (pt$nperm + 1))),
        "The test is two-sided. Shuffling within site-months, rather than across the whole record, keeps each anomaly ",
        "with the month mean it was formed from; the ordinary test of r would treat the pairs as independent and is too ",
        "optimistic. This test assumes observations can be exchanged within a site-month and does not account for all ",
        "possible temporal dependence, such as persistence from one sampling day to the next. The shuffles use the ",
        "paper's seed, so p is the paper's value."))
  })
  output$wk_p_perm <- renderPlotly({
    pt <- wk_perm(); req(pt)
    lim <- max(1, abs(pt$r_obs)) 
    plot_ly(x = pt$r_perm, type = "histogram", nbinsx = 50, marker = list(color = "#9aa7b4"), name = "shuffled",
            hovertemplate = "r %{x}<br>%{y} shuffles<extra></extra>") |>
      layout(xaxis = list(title = "r after shuffling within site-months", range = c(-lim, lim)),
             yaxis = list(title = "Shuffles"), showlegend = FALSE, bargap = 0.05,
             shapes = list(
               list(type = "line", x0 = pt$r_obs, x1 = pt$r_obs, y0 = 0, y1 = 1, yref = "paper", line = list(color = WK_HI, width = 3)),
               list(type = "line", x0 = -pt$r_obs, x1 = -pt$r_obs, y0 = 0, y1 = 1, yref = "paper",
                    line = list(color = WK_HI, width = 1.5, dash = "dot"))),
             annotations = list(list(x = pt$r_obs, y = 1, yref = "paper", text = sprintf("observed r = %s", f2s(pt$r_obs)),
                                     showarrow = FALSE, xanchor = if (pt$r_obs > 0) "right" else "left", yanchor = "bottom",
                                     font = list(color = WK_HI))))
  })
  output$wk_s4_shuffle <- renderUI({
    pt <- wk_perm(); req(pt); an <- wk_an(); k <- which(an$ym == input$wk_month); r <- wk_row()
    tab <- data.frame(Date = format(an$start_utc[k], "%d %b", tz = "UTC"),
                      `Column<br>anomaly` = sapply(an$column_anom[k], f2p),
                      `Surface anomaly,<br>observed` = sapply(an$surface_anom[k], f2p),
                      `Surface anomaly,<br>shuffle 1` = sapply(pt$first_shuffle[k], f2p), check.names = FALSE)
    tagList(div(class = "small fw-bold mb-1", sprintf("The first shuffle, in %s", month_name(input$wk_month))),
            wk_table(tab, an$start_utc[k] == r$start_utc),
            div(class = "small text-muted", "The same surface anomalies, reassigned to other days of the same month."))
  })

  output$wk_s5 <- renderUI({
    s <- input$wk_site; an <- wk_an(); r <- wk_row()
    sc <- FIND$site_ceiling; row <- if (is.null(sc)) NULL else sc[sc$site == s, ]
    nat <- FROW(FIND$ceiling, FIND$ceiling$block_label == "3x3")
    use_site <- !is.null(row) && nrow(row) == 1 && wk_arm() == "national" && input$wk_dur == "24"
    caveat <- p(class = "small text-muted", "The ceiling is an estimate. Real change in the column between two scans ",
                "inflates the noise estimate (lowering the ceiling), and errors that persist through the day, such as an ",
                "error in the assumed vertical profile, do not show up in scan-to-scan differences at all (raising it).")
    intro <- p("Even a perfect monitor could not correlate perfectly with TEMPO, because each scan carries random retrieval ",
               "error (noise). The ceiling is the correlation expected if that noise were the only source of disagreement; ",
               "E, the observed r divided by the ceiling, says how much of that attainable agreement a monitor reaches.")
    nat1 <- FROW(FIND$ceiling, FIND$ceiling$block_label == "1x1")
    nat_line <- if (!is.null(nat)) p(class = "small", tags$b("National example (all 24 h sites pooled, 3 × 3 block, Sect. 3.3): "),
      sprintf("single-scan noise of the 3 × 3 block mean %s × %s%s; median %s valid scans per sample; anomaly noise %s × %s, %s%% of the anomaly variance; ceiling √(1 − %s) = %s; observed r = %s, so E = %s.",
              f2s(nat$scan_noise_sd_single_1e15), U_COL,
              if (is.null(nat1)) "" else sprintf(" (%s for a single grid cell: averaging nine cells reduces the noise)", f2s(nat1$scan_noise_sd_single_1e15)),
              format(nat$median_valid_scans), f2s(nat$noise_sd_empirical_1e15), U_COL,
              sprintf("%.0f", 100 * nat$noise_share_empirical), f2s(nat$noise_share_empirical),
              f2s(nat$ceiling_empirical), f2s(nat$anomaly_r_observed), f2s(nat$anomaly_r_observed / nat$ceiling_empirical)))
    if (!use_site) return(tagList(intro,
      div(class = "alert alert-secondary py-2 small", "The paper estimates a ceiling for each national 24 h record with at ",
          "least 10 anomaly pairs. ", if (is.null(sc)) "Re-run step 24 to add the per-site ceilings. " else
            "This record has none; choose a 24 h record of the national comparison, or see the national example below."),
      nat_line, caveat))
    cs <- ceiling_steps(an, an$n_valid, row$scan_noise_sd_single_1e15)
    k <- which(an$start_utc == r$start_utc)[1]
    zero <- cs$ceiling <= 0
    U30 <- "10³⁰ molecules² cm⁻⁴"   # unit of a variance of columns in 10^15 molecules cm^-2
    qty <- function(sym, what, value, source) tags$tr(tags$td(HTML(sym)), tags$td(what), tags$td(class = "text-end", style = "white-space:nowrap;", HTML(value)), tags$td(class = "text-muted", source))
    quantities <- tags$table(class = "table table-sm small mb-2",
      tags$thead(tags$tr(tags$th("Symbol"), tags$th("Meaning"), tags$th(class = "text-end", "Value here"), tags$th("Where it comes from"))),
      tags$tbody(
        qty("σ", "noise of a single TEMPO scan (standard deviation)", sprintf("%s × %s", f2s(cs$scan_sd), U_COL),
            sprintf("root-mean-square difference between successive valid scans at this monitor, ÷ √2; %d scan pairs; this one number is read from the paper's analysis output, because the app data hold each sample's mean column rather than the individual scans", as.integer(row$n_scan_pairs))),
        qty("k", "valid scans averaged in the example sample", format(cs$k[k]), "step 1 above"),
        qty("m", sprintf("samples with a TEMPO value in %s", month_name(r$ym)), format(cs$m[k]), "step 2 above"),
        qty("σ² / k", "noise variance of the sample's mean column", sprintf("%s² / %d = %s", f2s(cs$scan_sd), cs$k[k], f2s(cs$scan_sd^2 / cs$k[k], 3)),
            "averaging k independent scans divides the noise variance by k"),
        qty("× (1 − 1/m)", "noise variance of the sample's anomaly", sprintf("%s × (1 − 1/%d) = <b>%s</b>", f2s(cs$scan_sd^2 / cs$k[k], 3), cs$m[k], f2s(cs$nv_i[k], 3)),
            "subtracting the month mean removes the share 1/m of the noise, because the sample's own noise is part of that mean"),
        qty("√", "noise SD of the sample's anomaly", sprintf("√%s = <b>%s</b> × %s", f2s(cs$nv_i[k], 3), f2s(sqrt(cs$nv_i[k])), U_COL), "")))
    tagList(intro,
      tags$ol(class = "mb-2",
        tags$li(tags$b("Noise of one scan. "), sprintf(
          "On days with two valid scans no more than 1.6 h apart, the difference between successive scans holds the errors of both scans, so the root-mean-square difference divided by √2 estimates the noise of a single scan: σ = %s × %s, from %d such scan pairs at this monitor. The same σ applies to every sample of the record.",
          f2s(cs$scan_sd), U_COL, as.integer(row$n_scan_pairs))),
        tags$li(tags$b("Noise in one sample's anomaly. "),
          sprintf("The example sample from step 1 averaged k = %d valid scans, and its anomaly in step 2 subtracted a month mean formed from m = %d samples. Its noise is therefore:", cs$k[k], cs$m[k]),
          quantities,
          HTML(sprintf("In one line: σ² / k × (1 − 1/m) = %s² / %d × (1 − 1/%d) = %s, a noise SD of %s × %s. Variances are in %s.",
                       f2s(cs$scan_sd), cs$k[k], cs$m[k], f2s(cs$nv_i[k], 3), f2s(sqrt(cs$nv_i[k])), U_COL, U30))),
        tags$li(tags$b("Average over the record. "), sprintf(
          "The same calculation for each of the %d anomaly samples (each with its own k and m; median k = %s) gives noise variances that average %s, a noise SD of %s × %s.",
          nrow(an), format(cs$median_k), f2s(cs$noise_var, 3), f2s(cs$noise_sd), U_COL)),
        tags$li(tags$b("Noise share. "), sprintf(
          "The column anomalies themselves (step 2) have an SD of %s × %s, a variance of %s. The share of that variance due to noise is f = %s / %s = %s.",
          f2s(cs$sd_col), U_COL, f2s(cs$var_col, 3), f2s(cs$noise_var, 3), f2s(cs$var_col, 3), f2s(cs$share))),
        tags$li(tags$b("Ceiling. "), if (zero) "The estimated noise is at least as large as the variance of the column anomalies, so the ceiling is 0 and E cannot be calculated (such records are left out of the paper's site models)." else
          HTML(sprintf("If the column anomalies were the true anomalies plus noise, and the surface tracked the true anomalies perfectly, the correlation would be r<sub>ceiling</sub> = √(1 − f) = √(1 − %s) = <b>%s</b>.", f2s(cs$share), f2s(cs$ceiling)))),
        if (!zero) tags$li(tags$b("E. "), HTML(sprintf(
          "The observed day-to-day r (step 3) is %s, so E = r<sub>obs</sub> / r<sub>ceiling</sub> = %s / %s = <b>%s</b>: this monitor reaches about %.0f%% of the agreement that scan noise alone would allow.",
          f2s(cs$r_obs), f2s(cs$r_obs), f2s(cs$ceiling), f2s(cs$E), 100 * min(cs$E, 1)))) ),
      nat_line, caveat)
  })

  wk_wp <- reactive(window_pairs(TEMPO))
  wk_wd <- reactive({
    w <- wk_wp(); s <- input$wk_boot_site %or% "08-035-0004"
    if (s == "all") w else w[w$site_id == s, ]
  })
  wk_boot <- reactive(boot_window_diff(wk_wd()))
  wk_drawn <- reactiveVal(NULL)
  observeEvent(input$wk_boot_site, wk_drawn(NULL))
  observeEvent(input$wk_draw, wk_drawn(draw_clusters(wk_wd())))
  output$wk_s6 <- renderUI({
    d <- wk_wd(); x <- window_diff(d); b <- wk_boot(); key <- WK_BOOT_KEY[[input$wk_boot_site %or% "08-035-0004"]]
    cl <- table(d$cluster)
    lab <- function(g) { p <- strsplit(g, " ")[[1]]
      nm <- SITES$site_code[SITES$site_id == p[1]]; paste0(if (input$wk_boot_site == "all") paste0(nm, " ") else "", p[2]) }
    tagList(
      p(sprintf("%d samples fall in %d site-months with at least three such samples. Their anomalies (step 2) give ",
                nrow(d), length(cl)),
        HTML(sprintf("r<sub>sampling window</sub> = %s and r<sub>3 h later</sub> = %s, a difference of <b>%s</b>.",
                     f2s(x[["r_window"]]), f2s(x[["r_later"]]), f2p(x[["diff"]])))),
      p(class = "small text-muted", paste0("Site-months (samples): ",
        paste(sprintf("%s (%d)", vapply(names(cl), lab, ""), as.integer(cl)), collapse = ", "), ".")),
      p(HTML(sprintf(paste0("To judge the difference, we resample <b>whole site-months</b>: draw %d site-months with ",
        "replacement from the %d, keep every sample in each, and recompute both correlations and their difference. ",
        "Resampling site-months rather than single samples keeps together the samples whose anomalies were formed from ",
        "the same month mean, so the dependence that creates is carried into the interval. Repeated %s times (histogram):"),
        length(cl), length(cl), format(WK_NBOOT, big.mark = ",")))),
      div(class = "ps-3 mb-2",
        div(sprintf("95%% interval = 2.5th to 97.5th percentiles of the resampled differences = %s to %s",
                    f2s(b$lo), f2s(b$hi))),
        div(sprintf("Resampled differences ≤ 0: %d; ≥ 0: %d. Two-sided p = (2 × %d + 1) / (%s + 1) = %s",
                    b$n_le0, b$n_ge0, min(b$n_le0, b$n_ge0), format(b$nboot, big.mark = ","), fmt_p(b$p)))),
      p(class = "small", tags$b("Paper: "), sprintf("difference %s (95%% CI %s to %s), bootstrap %s over %s site-months.",
        FN(paste0("win_", key, "_diff")), FN(paste0("win_", key, "_lo")), FN(paste0("win_", key, "_hi")),
        FN(paste0("win_", key, "_bootp")), FN(paste0("win_", key, "_clusters"))),
        span(class = "text-muted", " The app's resamples are drawn independently of the paper's, so interval ends ",
             "and p can differ slightly in the last digit. The national 24 h comparison of 06:00–09:00 with ",
             "09:00–12:00 LST pools many monitors and so resamples whole monitors instead.")))
  })
  output$wk_p_boot <- renderPlotly({
    b <- wk_boot(); dr <- wk_drawn(); d <- wk_wd()
    sh <- list(list(type = "line", x0 = 0, x1 = 0, y0 = 0, y1 = 1, yref = "paper", line = list(color = "#444", width = 1)),
               list(type = "line", x0 = b$lo, x1 = b$lo, y0 = 0, y1 = 1, yref = "paper", line = list(color = "#2166ac", dash = "dash")),
               list(type = "line", x0 = b$hi, x1 = b$hi, y0 = 0, y1 = 1, yref = "paper", line = list(color = "#2166ac", dash = "dash")))
    if (!is.null(dr)) { v <- window_diff(d, rows_of(d, dr))[["diff"]]
      if (is.finite(v)) sh[[4]] <- list(type = "line", x0 = v, x1 = v, y0 = 0, y1 = 1, yref = "paper", line = list(color = WK_HI, width = 3)) }
    plot_ly(x = b$diff, type = "histogram", nbinsx = 60, marker = list(color = "#9aa7b4"),
            hovertemplate = "difference %{x}<br>%{y} resamples<extra></extra>") |>
      layout(xaxis = list(title = "r(3 h later) − r(sampling window), resampled"), yaxis = list(title = "Resamples"),
             showlegend = FALSE, bargap = 0.05, shapes = sh)
  })
  output$wk_draw_out <- renderUI({
    dr <- wk_drawn(); d <- wk_wd()
    if (is.null(dr)) return(div(class = "small text-muted",
      "Blue dashed lines: the 95% interval. Press ", tags$b("Draw one resample"), " to see a single bootstrap draw."))
    x <- window_diff(d, rows_of(d, dr)); tb <- table(dr); ids <- unique(d$cluster)
    lab <- function(g) { p <- strsplit(g, " ")[[1]]
      nm <- SITES$site_code[SITES$site_id == p[1]]; paste0(if (input$wk_boot_site == "all") paste0(nm, " ") else "", p[2]) }
    tagList(div(class = "small fw-bold mb-1", "One resample (orange line)"),
      div(class = "small", "Drawn: ", paste(sprintf("%s%s", vapply(names(tb), lab, ""),
                                                    ifelse(tb > 1, sprintf(" ×%d", as.integer(tb)), "")), collapse = ", ")),
      div(class = "small text-muted", sprintf("%d of the %d site-months drawn more than once, %d not drawn; %d samples.",
                                              sum(tb > 1), length(ids), length(setdiff(ids, dr)), length(rows_of(d, dr)))),
      div(class = "small mt-1", HTML(sprintf("r<sub>sampling window</sub> = %s, r<sub>3 h later</sub> = %s, difference <b>%s</b>.",
                                             f2s(x[["r_window"]]), f2s(x[["r_later"]]), f2p(x[["diff"]])))))
  })
}

shinyApp(ui, server)
