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
    for (o in c("p_find_avg", "p_find_pbl", "site_card", "arm_ui", "dur_ui", "lag_ui", "tempo_boxes", "ts_note", "p_ts", "p_scatter", "p_anom", "p_obs",
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

  # How the comparison works: every step for several kinds of record
  wk_cases <- list(list(wk_site = "04-013-9997", wk_dur = "24"),   # national 24 h, with a noise ceiling
                   list(wk_site = "06-061-0006", wk_dur = "24"),   # ceiling estimated at zero
                   list(wk_site = "06-019-0011", wk_dur = "8"),    # 8 h record: no ceiling
                   list(wk_site = "08-035-0004", wk_dur = "3"),    # Chatfield, national 3 h record
                   list(wk_site = "08-059-0015", wk_dur = "24"))   # Wheat Ridge: Colorado arm only
  for (cs in wk_cases) {
    session$setInputs(wk_site = cs$wk_site); session$setInputs(wk_dur = cs$wk_dur)
    an <- wk_an(); session$setInputs(wk_month = names(which.max(table(an$ym))))
    session$setInputs(wk_date = as.character(wk_month()$start_utc[1]))
    for (o in c("wk_rec_ui", "wk_month_ui", "wk_date_ui", "wk_s1", "wk_s2", "wk_s3", "wk_p_raw", "wk_p_anom",
                "wk_s4", "wk_p_perm", "wk_s4_shuffle", "wk_s5"))
      try_out(paste("worked", cs$wk_site, o), session$getOutput(o))
  }
  try_out("worked: example month and sample follow the selection", {
    session$setInputs(wk_site = "04-013-9997"); session$setInputs(wk_dur = "24")
    m <- sort(unique(wk_an()$ym))[2]; session$setInputs(wk_month = m)
    session$setInputs(wk_date = as.character(wk_month()$start_utc[2]))
    stopifnot(wk_row()$ym == m, wk_row()$start_utc == wk_month()$start_utc[2])
  })
  for (b in c("08-035-0004", "08-123-0008", "all")) {
    session$setInputs(wk_boot_site = b)
    for (o in c("wk_s6", "wk_p_boot", "wk_draw_out")) try_out(paste("worked boot", b, o), session$getOutput(o))
    session$setInputs(wk_draw = 1)
    try_out(paste("worked boot", b, "one draw"), { session$getOutput("wk_draw_out"); stopifnot(length(wk_drawn()) == length(unique(wk_wd()$cluster))) })
  }
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
  try_out("map stats by duration", {
    for (du in setdiff(e$MAP_DUR_CHOICES, "longest")) {
      ms <- e$map_stats(dur = du)
      lab <- e$map_labels(ms, e$filter_text("all", names(e$SEASONS)))
      stopifnot(nrow(ms) == nrow(e$SITES), length(lab) == nrow(e$SITES), all(ms$dur[!is.na(ms$dur)] == as.integer(du)),
                any(!is.na(ms$dur)))
    }
  })
  try_out("main findings data", {
    stopifnot(!is.null(e$FIND), length(e$FIND$nums) > 100, !is.null(e$FIND$averaging), !is.null(e$FIND$pbl),
              e$FN("site_dd_median_24") != "\u2013", e$FN("pbl_int_adj_24_ptxt") != "\u2013")
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

# The worked examples: the paper's values (step 24 checks every site; these are spot checks)
message("worked examples")
try_out("worked: permutation p and noise ceiling at Fresno (24 h)", {
  d  <- e$TEMPO[e$TEMPO$arm == "national" & e$TEMPO$site_id == "06-019-0011" & e$TEMPO$duration_h == 24L &
                  e$TEMPO$lag_h == 0L & e$TEMPO$usable, ]
  an <- e$pair_stats(d$date, d$hcho, d$column)$anom
  pt <- e$perm_test(an)
  stopifnot(nrow(an) == 19L, pt$nperm == 2000L, abs(pt$p - 13 / 2001) < 1e-12, length(pt$r_perm) == 2000L,
            # a shuffle keeps each month's values
            all(tapply(pt$first_shuffle, an$ym, function(v) sum(v)) - tapply(an$surface_anom, an$ym, sum) < 1e-9))
  sc <- e$FIND$site_ceiling
  if (!is.null(sc)) {
    row <- sc[sc$site == "06-019-0011", ]
    cs  <- e$ceiling_steps(an, d$n_valid[an$i], row$scan_noise_sd_single_1e15)
    stopifnot(abs(cs$ceiling - row$ceiling_empirical) < 1e-9, abs(cs$E - row$r_noise_corrected) < 1e-9)
  }
})
try_out("worked: Colorado window comparison", {
  w <- e$window_pairs(e$TEMPO); ch <- w[w$site_id == "08-035-0004", ]
  x <- e$window_diff(ch); b <- e$boot_window_diff(ch)
  stopifnot(nrow(ch) == 42L, length(unique(ch$cluster)) == 11L, nrow(w) == 80L, length(unique(w$cluster)) == 21L,
            abs(x[["diff"]] - 0.568095) < 1e-5, b$nboot == 10000L, b$lo > 0.2, b$hi < 0.95, b$p < 0.001)
})

if (length(fails)) stop(length(fails), " check(s) failed: ", paste(fails, collapse = "; "))
message("All app checks passed.")
