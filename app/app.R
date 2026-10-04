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

lag_label <- function(l) ifelse(l == 0, "Sampling window (lag 0)",
                         ifelse(l > 0, sprintf("%d h after the sampling window (+%d h)", l, l),
                                sprintf("%d h before the sampling window (%d h)", -l, l)))
class_label <- function(cl) ifelse(is.na(CLASS_LABEL[cl]), cl, CLASS_LABEL[cl])

# ---- site list and map labels --------------------------------------------------------
site_label <- function(s) ifelse(is.na(s$site_code), sprintf("%s (%s)", s$name, s$site_id),
                                 sprintf("%s (%s, %s)", s$name, s$site_code, s$site_id))
co_sites <- SITES[SITES$colorado_detail, ]
nat_sites <- SITES[!SITES$colorado_detail, ]
CHOICES <- c(list("Colorado: CDPHE air toxics and TEMPO" = setNames(co_sites$site_id, site_label(co_sites))),
             split(setNames(nat_sites$site_id, site_label(nat_sites)), nat_sites$state))
DEFAULT_SITE <- if ("08-001-0010" %in% SITES$site_id) "08-001-0010" else SITES$site_id[1]

# One filter for the site panel and the map: smoke class and seasons.
filter_rows <- function(d, smoke = "all", seasons = names(SEASONS)) {
  if (smoke == "none")  d <- d[!is.na(d$smoke) & d$smoke == "none", ]
  if (smoke == "smoke") d <- d[!is.na(d$smoke) & d$smoke != "none", ]
  d[d$season %in% seasons, ]
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
SITE_HEAD <- sprintf("<b>%s</b><br>AQS %s%s%s", SITES$name, SITES$site_id,
                     ifelse(is.na(SITES$site_code), "", paste0(" &middot; CDPHE ", SITES$site_code)),
                     ifelse(is.na(SITES$program), "", paste0("<br>", SITES$program)))
map_labels <- function(ms, ftxt) {
  stat <- ifelse(is.na(SITES$map_duration), "no matched samples",
          ifelse(ms$n_anom >= MIN_REPORT & !is.na(ms$r_anom),
                 sprintf("%d h record: day-to-day r = %.2f (%d pairs)", SITES$map_duration, ms$r_anom, ms$n_anom),
                 sprintf("%d h record: %d anomaly pairs, fewer than %d", SITES$map_duration, ms$n_anom, MIN_REPORT)))
  paste0(SITE_HEAD, "<br>", stat, "<br><i>", ftxt, "</i>")
}
add_site_markers <- function(map, ms, ftxt) {
  map |>
    addCircleMarkers(data = SITES, lng = ~lon, lat = ~lat, layerId = ~site_id,
                     radius = ifelse(SITES$colorado_detail, 8, 4 + 4 * sqrt(pmin(ms$n_anom, 150) / 150)),
                     fillColor = PAL(clamp(ifelse(ms$n_anom >= MIN_REPORT, ms$r_anom, NA))), fillOpacity = 0.9,
                     color = ifelse(SITES$colorado_detail, "#111111", "#6b6b6b"),
                     weight = ifelse(SITES$colorado_detail, 2.5, 0.7),
                     label = lapply(map_labels(ms, ftxt), HTML)) |>
    addLegend("bottomright", pal = PAL, values = c(-0.8, 0.8), opacity = 1, layerId = "legend",
              title = HTML(paste0("Day-to-day r<br><span style='font-weight:normal;font-size:85%'>",
                                  ftxt, "</span>")))
}
PAL   <- colorNumeric(c("#b2182b", "#f7f7f7", "#2166ac"), domain = c(-0.8, 0.8), na.color = "#bdbdbd")
clamp <- function(x) pmax(pmin(x, 0.8), -0.8)

# ---- about page ------------------------------------------------------------------------
ABOUT <- card(card_body(
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
    tags$li(tags$b("Smoke"), ": NOAA Hazard Mapping System smoke polygons over the site whose analysis period overlaps the sampling window widened by 3 h on each side.")),
  h4("Data and code"),
  p("The matched data are the released dataset of the paper, built by the R pipeline at ",
    a(META$repo, href = META$repo, target = "_blank"), " (folder ", code("dataset/"), "; the app is built by step 24). ",
    "TEMPO: NASA Langley ASDC, ", a("doi:10.5067/IS-40e/TEMPO/HCHO_L3.004", href = "https://doi.org/10.5067/IS-40e/TEMPO/HCHO_L3.004", target = "_blank"),
    ". Surface data: U.S. EPA AQS and CDPHE. Meteorology: NOAA HRRR. Smoke: NOAA HMS."),
  p(class = "small text-muted", "Data version: dataset md5 ", substr(META$dataset$md5, 1, 12), ".")
))

# ---- UI --------------------------------------------------------------------------------
ui <- page_navbar(
  title = "TEMPO formaldehyde and surface air toxics",
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  header = tags$style(HTML(".leaflet-container { background: #e8edf1; }")),
  fillable = FALSE,
  nav_panel("Explore",
    layout_sidebar(
      sidebar = sidebar(width = 330,
        selectInput("site", "Monitoring site", choices = CHOICES, selected = DEFAULT_SITE),
        uiOutput("site_card"),
        accordion(multiple = TRUE, open = c("TEMPO comparison", "Air toxics"),
          accordion_panel("TEMPO comparison",
            uiOutput("arm_ui"), uiOutput("dur_ui"), uiOutput("lag_ui"),
            radioButtons("smoke", "Smoke (NOAA HMS)", choices = c("All days" = "all", "Smoke-free days" = "none",
                                                                  "Smoke-affected days" = "smoke")),
            checkboxGroupInput("seasons", "Seasons", choices = setNames(names(SEASONS), SEASONS),
                               selected = names(SEASONS))),
          accordion_panel("Air toxics",
            uiOutput("tox_class_ui"), uiOutput("tox_param_ui"),
            checkboxInput("tox_log", "Logarithmic axis", FALSE),
            checkboxInput("tox_cmp", "Compare with the other Colorado sites", TRUE)))
      ),
      layout_columns(col_widths = breakpoints(sm = 12, xl = c(5, 7)),
        card(full_screen = TRUE,
             card_header(class = "d-flex justify-content-between align-items-center",
                         "Monitors: click one to select it",
                         actionLink("zoom_co", "Zoom to Colorado")),
             leafletOutput("map", height = 620),
             card_footer(class = "small text-muted",
                         "Colour: day-to-day correlation with TEMPO of each site's longest-duration record ",
                         "(sampling window), for the smoke and season filters at left. Grey: fewer than 10 ",
                         "within-month anomaly pairs. Black outline: Colorado sites with CDPHE air-toxics data. ",
                         "Background layers are in the control at the top right of the map.")),
        navset_card_tab(id = "tab", full_screen = TRUE,
          nav_panel("TEMPO vs surface HCHO", value = "tempo",
            uiOutput("tempo_boxes"),
            plotlyOutput("p_ts", height = "380px"),
            layout_columns(col_widths = breakpoints(sm = 12, lg = c(6, 6)),
                           plotlyOutput("p_scatter", height = "330px"),
                           plotlyOutput("p_anom", height = "330px")),
            plotlyOutput("p_obs", height = "300px"),
            div(class = "mt-2", downloadButton("dl_tempo", "Download these samples (CSV)", class = "btn-sm"))),
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
                       isolate(filter_text(input$smoke %or% "all", input$seasons %or% character()))) |>
      addLayersControl(baseGroups = base, overlayGroups = over,
                       options = layersControlOptions(collapsed = TRUE)) |>
      hideGroup(setdiff(base, base[1])) |>
      fitBounds(-124.5, 24.5, -67, 49.5)
  })
  observeEvent(input$map_marker_click, {
    id <- input$map_marker_click$id
    if (!is.null(id) && id %in% SITES$site_id) updateSelectInput(session, "site", selected = id)
  })
  # markers re-coloured when the smoke or season filter changes (same layerIds,
  # so each marker and the legend are replaced, not duplicated)
  map_ready <- reactiveVal(FALSE)
  observeEvent(input$map_zoom, map_ready(TRUE), once = TRUE)
  observe({
    req(map_ready())
    sm <- input$smoke %or% "all"; se <- input$seasons %or% character()
    leafletProxy("map") |> add_site_markers(map_stats(sm, se), filter_text(sm, se))
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
                     text = sprintf("%s<br>TEMPO column %.2f<br>%d valid scans<br>smoke: %s", format(u$date),
                                    u$column, u$n_valid, as.character(u$smoke_lab)),
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
    d$season_f <- factor(d$season, levels = names(SEASONS))
    plot_ly(d, x = ~column, y = ~hcho, color = ~season_f, colors = SEASON_COL,
            type = "scatter", mode = "markers", marker = list(size = 6, opacity = 0.8),
            text = sprintf("%s<br>column %.2f<br>surface %.2f", format(d$date), d$column, d$hcho),
            hoverinfo = "text") |>
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
    plot_ly(an, x = ~column_anom, y = ~surface_anom, type = "scatter", mode = "markers",
            marker = list(size = 6, color = "#2166ac", opacity = 0.75),
            text = sprintf("%s<br>column anomaly %.2f<br>surface anomaly %.2f", format(an$date),
                           an$column_anom, an$surface_anom),
            hoverinfo = "text", showlegend = FALSE) |>
      add_lines(x = xs, y = unname(predict(fit, data.frame(column_anom = xs))), inherit = FALSE,
                line = list(color = "black", width = 1.5), showlegend = FALSE) |>
      layout(title = list(text = sprintf("Day to day (within-month anomalies): r = %s (%d pairs)",
                                         fmt_r(s$r_anom), s$n_anom), font = list(size = 13)),
             xaxis = list(title = "TEMPO column anomaly"), yaxis = list(title = "Surface HCHO anomaly"))
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
