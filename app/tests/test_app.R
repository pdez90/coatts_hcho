# test_app.R - exercise the app's server for a range of sites before deploying.
# Run from the project root:  Rscript app/tests/test_app.R
# Every output is computed for each site and control combination below; the
# script prints one line per check and stops with an error if any failed.
suppressPackageStartupMessages(library(shiny))

app <- shinyAppDir("app")
fails <- character()
try_out <- function(label, expr) {
  ok <- tryCatch({ force(expr); TRUE }, error = function(e) {
    # validate()/need() messages are intended for empty selections, not failures
    if (inherits(e, "shiny.silent.error") || inherits(e, "validation")) TRUE else {
      message("  FAIL ", label, ": ", conditionMessage(e)); FALSE }
  })
  if (ok) message("  ok   ", label) else fails <<- c(fails, label)
}

testServer(app, {
  cases <- list(
    list(site = "08-001-0010"),                                   # COATTS, national + Colorado arms
    list(site = "08-001-0010", arm = "colorado_24h"),
    list(site = "08-059-0015"),                                   # Wheat Ridge: Colorado arm only
    list(site = "08-035-0004", arm = "colorado_3h", lag = "3"),   # Chatfield, +3 h
    list(site = "08-123-0008", arm = "colorado_3h", lag = "9"),   # Platteville, +9 h
    list(site = "06-019-0011", dur = "8"),                        # Fresno, 8 h record
    list(site = "11-001-0043", smoke = "none", seasons = c("JJA", "SON")),
    list(site = "06-019-0011", seasons = character()),            # nothing selected
    list(site = "06-019-0011", dur = "8", colour_by = "hrrr_pbl_km", nat_dur = "8", nets = "NATTS"),
    list(site = "08-059-0015", colour_by = "smoke", nat_dur = "3"),  # Wheat Ridge: midday-scan variant
    list(site = "06-029-0014", colour_by = "n_valid", nets = character())
  )
  for (cs in cases) {
    message("case: ", paste(names(cs), unlist(lapply(cs, paste, collapse = "+")), sep = "=", collapse = ", "))
    args <- modifyList(list(smoke = "all", seasons = c("DJF", "MAM", "JJA", "SON"), colour_by = "season",
                            nets = c("NATTS", "NCORE", "PAMS", "NEAR", "OTHER", "NONE", "CO"), nat_dur = "24"), cs)
    do.call(session$setInputs, args)
    for (o in c("site_card", "arm_ui", "dur_ui", "lag_ui", "tempo_boxes", "ts_note", "p_ts", "p_scatter", "p_anom", "p_obs",
                "tox_class_ui", "tox_param_ui", "tox_body", "sens_site_head", "sens_site_ui", "sens_site_plot",
                "sens_site_table", "sens_nat_head", "sens_nat_ui", "sens_nat_plot")) {
      try_out(paste(cs$site, o), session$getOutput(o))
    }
    if (nrow(tox_site())) {
      for (cl in classes_here()) {
        session$setInputs(tox_class = cl)
        session$setInputs(tox_param = names(params_here())[1], tox_log = TRUE, tox_cmp = TRUE)
        for (o in c("tox_boxes", "t_ts", "t_season", "t_cmp", "t_table")) try_out(paste(cs$site, cl, o), session$getOutput(o))
      }
    }
  }
  try_out("map", session$getOutput("map"))
})

# The map statistics are globals of app.R, which testServer's expression cannot
# see; load them as Shiny does (R/stats.R, then app.R) into their own environment.
message("map statistics")
e <- new.env(parent = globalenv())
try_out("load app globals", {
  for (f in sort(list.files(file.path("app", "R"), "\\.R$", full.names = TRUE))) sys.source(f, envir = e)
  sys.source(file.path("app", "app.R"), envir = e)
})
if (exists("map_stats", envir = e, inherits = FALSE)) {
  # with no filter, the map colours are step 24's headline values
  try_out("map colours = step 24 values", {
    ms <- e$map_stats()
    stopifnot(nrow(ms) == nrow(e$SITES),
              isTRUE(all.equal(ms$n_anom, as.integer(e$SITES$map_n_anom))),
              isTRUE(all.equal(ms$r_anom, as.numeric(e$SITES$map_r_anom))))
  })
  try_out("map stats, smoke-free winter", {
    lab <- e$map_labels(e$map_stats("none", "DJF"), e$filter_text("none", "DJF"))
    stopifnot(length(lab) == nrow(e$SITES))
  })
}

if (exists("sensitivity_site", envir = e, inherits = FALSE)) {
  message("agreement across configurations")
  try_out("site table: unchanged configuration = site panel statistics", {
    rows <- e$TEMPO[e$TEMPO$site_id == "06-019-0011", ]
    t  <- e$sensitivity_site(rows, "national", 8L, 0L, screen = e$SCREEN[e$SCREEN$site_id == "06-019-0011", ])
    d  <- rows[rows$arm == "national" & rows$duration_h == 8L & rows$lag_h == 0L & rows$usable, ]
    st <- e$pair_stats(d$date, d$hcho, d$column)
    cr <- t[t$key == "current", ]
    stopifnot(cr$n == st$n, cr$n_anom == st$n_anom, isTRUE(all.equal(cr$r, st$r)), isTRUE(all.equal(cr$r_anom, st$r_anom)),
              all(c(e$DIM[["lag"]], e$DIM[["block"]], e$DIM[["ecf"]], e$THIRDS$dim) %in% t$dim),
              # every sample entering the start-hour anomalies falls in exactly one third of valid scans
              sum(t$n[t$dim == e$THIRDS$dim[e$THIRDS$var == "n_valid"]]) ==
                sum(vapply(split(seq_len(nrow(d)), format(d$start_utc, "%H", tz = "UTC")),
                           function(ix) nrow(e$month_anomalies(d$date[ix], d$hcho[ix], d$column[ix])), 1L)))
  })
  try_out("all-sites table = the map's statistics", {
    s <- e$SITES[e$SITES$map_arm %in% "national" & !is.na(e$SITES$map_duration), ]
    cur <- e$SENS_NAT[e$SENS_NAT$key == "current", ]
    m <- match(paste(s$site_id, s$map_duration), paste(cur$site_id, cur$duration_h)); k <- !is.na(m)
    stopifnot(sum(k) >= 100, all(cur$n_anom[m[k]] == s$map_n_anom[k]),
              isTRUE(all.equal(cur$r_anom[m[k]], s$map_r_anom[k])))
  })
  try_out("all-sites plot rows", stopifnot(nrow(e$nat_plot_rows(e$SENS_NAT[e$SENS_NAT$duration_h == 24L, ])) > 20))
}

if (length(fails)) stop(length(fails), " check(s) failed: ", paste(fails, collapse = "; "))
message("All app checks passed.")
