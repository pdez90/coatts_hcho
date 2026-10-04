# sensitivity.R - how agreement between surface HCHO and the TEMPO column
# changes with the configuration, one thing at a time.
#
# Shiny sources this file for the app (files in app/R/ load automatically), where
# sensitivity_site() describes the selected site. R/24_app_data.R sources it to
# precompute the same table for every site of the national comparison, and stops
# unless the unchanged configuration reproduces the paper's site table.
# Uses pair_stats() and MIN_REPORT from stats.R. Nothing here refers to the
# app's own globals, so the step and the app compute the same numbers.

SEASON_CODES <- c("DJF", "MAM", "JJA", "SON")
SEASON_NAMES <- c(DJF = "Winter (DJF)", MAM = "Spring (MAM)", JJA = "Summer (JJA)", SON = "Autumn (SON)")
SMOKE_NAMES  <- c(all = "All days", none = "Smoke-free days", smoke = "Smoke-affected days")

# The paper's primary TEMPO screening; step 24 checks it against the dataset.
PRIMARY_SCREEN <- list(max_ecf = 0.2, block = "3x3", scan_window = "sampling window")

# One filter for the site panel, the map and this table: smoke class and seasons.
# Monthly means for the day-to-day correlation are then taken over the selected
# samples alone, as the paper does when it excludes smoke days.
filter_rows <- function(d, smoke = "all", seasons = SEASON_CODES) {
  if (smoke == "none")  d <- d[!is.na(d$smoke) & d$smoke == "none", ]
  if (smoke == "smoke") d <- d[!is.na(d$smoke) & d$smoke != "none", ]
  d[d$season %in% seasons, ]
}

lag_label <- function(l) ifelse(l == 0, "Sampling window (lag 0)",
                         ifelse(l > 0, sprintf("%d h after the sampling window (+%d h)", l, l),
                                sprintf("%d h before the sampling window (%d h)", -l, l)))

# Dimensions, in display order.
DIM_CURRENT <- "Current selection"
DIM <- c(smoke    = "Smoke (NOAA HMS)",
         season   = "Season",
         lag      = "TEMPO window",
         duration = "Sample duration (TEMPO window = sampling window)",
         block    = "TEMPO pixel block (cloud limit 0.2)",
         ecf      = "TEMPO cloud-fraction limit (3 × 3 block)",
         window   = "TEMPO scans used (Colorado 24 h)")

# Thirds of a site's samples by a condition of the day. As in the paper's
# boundary-layer analysis (R/20, diag10_pbl_tertiles.csv): samples without the
# variable are dropped, within-month anomalies are formed from the rest, and the
# samples entering the day-to-day correlation are split into equal thirds with
# dplyr::ntile(); "relative" stratifies by the departure from the month mean.
THIRDS <- data.frame(
  var      = c("hrrr_pbl_km", "hrrr_pbl_km", "tempo_pbl_km", "temp_c", "n_valid"),
  relative = c(FALSE, TRUE, FALSE, FALSE, FALSE),
  dim      = c("Boundary-layer height, HRRR (mean over the sampling window)",
               "Boundary-layer height, HRRR, relative to its month mean",
               "Boundary-layer height, TEMPO retrieval (mean over valid scans)",
               "Temperature, HRRR 2 m (mean over the sampling window)",
               "Valid TEMPO scans in the window"),
  fmt      = c("%.2f", "%+.2f", "%.2f", "%.1f", "%.0f"),
  unit     = c(" km", " km", " km", " °C", " scans"),
  stringsAsFactors = FALSE)
THIRD_KEYS <- c("low", "mid", "high")
DIM_ORDER  <- c(DIM_CURRENT, unname(DIM), THIRDS$dim)

# dplyr::ntile(x, 3) as in dplyr >= 1.1 (the version R/00_config.R requires):
# ranks with ties in order of appearance, groups differing in size by at most
# one, larger groups first. Step 24 checks it against dplyr::ntile().
ntile3 <- function(x) {
  out <- rep(NA_integer_, length(x))
  len <- sum(!is.na(x)); if (!len) return(out)
  r <- rank(x, ties.method = "first", na.last = "keep")
  n_larger <- len %% 3L; larger <- ceiling(len / 3); smaller <- floor(len / 3)
  thr <- larger * n_larger
  b <- ifelse(r <= thr, (r + larger - 1) / larger, (r - thr + smaller - 1) / smaller + n_larger)
  out[] <- suppressWarnings(as.integer(floor(b)))
  out
}

cor_or_na <- function(a, b) {
  if (length(a) < 3 || !isTRUE(stats::sd(a) > 0) || !isTRUE(stats::sd(b) > 0)) NA_real_ else stats::cor(a, b)
}

# One row per configuration: dim, key, level, ord (order within dim), n, r,
# n_anom, r_anom, current (the configuration shown in the site panel).
#   rows    the primary-screening rows of ONE site (every arm, duration, lag)
#   screen  the same site's rows for the other screening variants, or NULL
sensitivity_site <- function(rows, arm, dur, lag, smoke = "all", seasons = SEASON_CODES,
                             screen = NULL, with_duration = TRUE) {
  out <- list()
  add <- function(dim, key, level, st, current = FALSE) {
    out[[length(out) + 1L]] <<- data.frame(
      dim = dim, key = key, level = level, ord = sum(vapply(out, function(o) o$dim == dim, TRUE)) + 1L,
      n = as.integer(st$n), r = as.numeric(st$r), n_anom = as.integer(st$n_anom), r_anom = as.numeric(st$r_anom),
      current = current, stringsAsFactors = FALSE)
  }
  ps   <- function(d) { d <- d[d$usable, ]; pair_stats(d$date, d$hcho, d$column) }
  pick <- function(dd, ll) rows[rows$arm == arm & rows$duration_h == dd & rows$lag_h == ll, ]
  cur  <- pick(dur, lag)

  add(DIM_CURRENT, "current", "As selected", ps(filter_rows(cur, smoke, seasons)), TRUE)
  for (s in names(SMOKE_NAMES))
    add(DIM[["smoke"]], s, SMOKE_NAMES[[s]], ps(filter_rows(cur, s, seasons)), s == smoke)
  for (s in SEASON_CODES)
    add(DIM[["season"]], s, SEASON_NAMES[[s]], ps(filter_rows(cur, smoke, s)), setequal(seasons, s))
  lags <- sort(unique(rows$lag_h[rows$arm == arm & rows$duration_h == dur]))
  if (length(lags) > 1)
    for (l in lags) add(DIM[["lag"]], as.character(l), lag_label(l), ps(filter_rows(pick(dur, l), smoke, seasons)), l == lag)
  if (with_duration) {
    durs <- sort(unique(rows$duration_h[rows$arm == arm]), decreasing = TRUE)
    if (length(durs) > 1)
      for (dd in durs) add(DIM[["duration"]], as.character(dd), sprintf("%d h samples", dd),
                           ps(filter_rows(pick(dd, 0L), smoke, seasons)), dd == dur && lag == 0L)
  }

  if (!is.null(screen) && nrow(screen)) {
    variant <- function(e, b, w) {
      if (abs(e - PRIMARY_SCREEN$max_ecf) < 1e-9 && b == PRIMARY_SCREEN$block && w == PRIMARY_SCREEN$scan_window) return(cur)
      screen[screen$arm == arm & screen$duration_h == dur & screen$lag_h == lag & abs(screen$max_ecf - e) < 1e-9 &
               screen$block == b & screen$scan_window == w, ]
    }
    block_name <- function(b) paste(sub("x", " × ", b), if (b == "1x1") "pixel" else "pixels")
    for (b in c("1x1", "3x3", "5x5")) {
      d <- variant(PRIMARY_SCREEN$max_ecf, b, "sampling window")
      if (nrow(d)) add(DIM[["block"]], b, block_name(b), ps(filter_rows(d, smoke, seasons)), b == PRIMARY_SCREEN$block)
    }
    for (e in c(0.1, 0.2, 0.3)) {
      d <- variant(e, PRIMARY_SCREEN$block, "sampling window")
      if (nrow(d)) add(DIM[["ecf"]], sprintf("%.1f", e), sprintf("Effective cloud fraction ≤ %.1f", e),
                       ps(filter_rows(d, smoke, seasons)), abs(e - PRIMARY_SCREEN$max_ecf) < 1e-9)
    }
    mid <- variant(PRIMARY_SCREEN$max_ecf, PRIMARY_SCREEN$block, "midday")
    if (nrow(mid)) {
      add(DIM[["window"]], "sampling window", "Scans in the 24 h sampling window", ps(filter_rows(cur, smoke, seasons)), TRUE)
      add(DIM[["window"]], "midday", "Scans between 10:00 and 14:00 local standard time", ps(filter_rows(mid, smoke, seasons)))
    }
  }

  d <- filter_rows(cur, smoke, seasons); d <- d[d$usable, ]
  for (j in seq_len(nrow(THIRDS))) {
    v  <- THIRDS$var[j]
    dv <- d[is.finite(d[[v]]), ]
    an <- pair_stats(dv$date, dv$hcho, dv$column)$anom
    if (nrow(an) < 3) next
    x  <- dv[[v]][an$i]
    if (THIRDS$relative[j]) x <- x - stats::ave(x, an$ym)
    hc <- dv$hcho[an$i]; co <- dv$column[an$i]
    tc <- ntile3(x)
    for (k in 1:3) {
      s <- which(tc == k); if (!length(s)) next
      rg <- range(x[s])
      lv <- if (isTRUE(all.equal(rg[1], rg[2]))) sprintf(THIRDS$fmt[j], rg[1]) else
        paste(sprintf(THIRDS$fmt[j], rg[1]), "to", sprintf(THIRDS$fmt[j], rg[2]))
      add(THIRDS$dim[j], THIRD_KEYS[k], paste0(c("Lowest", "Middle", "Highest")[k], " third: ", lv, THIRDS$unit[j]),
          list(n = length(s), r = cor_or_na(hc[s], co[s]),
               n_anom = length(s), r_anom = cor_or_na(an$surface_anom[s], an$column_anom[s])))
    }
  }
  do.call(rbind, out)
}
