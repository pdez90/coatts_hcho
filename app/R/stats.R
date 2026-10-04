# stats.R - the agreement statistics of the paper, in one place.
#
# Shiny sources this file for the app (files in app/R/ load automatically), and
# R/24_app_data.R sources it to check, site by site, that it reproduces the
# correlations in output/tables/national_stats_by_site.csv. The app therefore
# shows the paper's numbers, computed the way the paper computes them.

MIN_PER_SITE_MONTH <- 3L   # CFG$min_days_per_site_month
MIN_REPORT         <- 10L  # CFG$min_anom_pairs_site, and >= 10 matched samples

# Within-month anomalies: the mean of each calendar month of each year is
# removed from both series, in months holding at least MIN_PER_SITE_MONTH
# samples. Call it on the samples of ONE site (and one duration and lag).
# Column i is the position of each anomaly in the input vectors.
month_anomalies <- function(date, surface, column, min_n = MIN_PER_SITE_MONTH) {
  if (!length(date)) {
    return(data.frame(date = as.Date(character()), ym = character(),
                      surface_anom = numeric(), column_anom = numeric(), i = integer()))
  }
  ym   <- format(date, "%Y-%m")
  n_ym <- stats::ave(seq_along(ym), ym, FUN = length)
  k    <- n_ym >= min_n
  data.frame(date = date[k], ym = ym[k],
             surface_anom = surface[k] - stats::ave(surface[k], ym[k]),
             column_anom  = column[k]  - stats::ave(column[k],  ym[k]),
             i = which(k))
}

# Whole-period and within-month (day-to-day) Pearson correlations between
# surface HCHO and the TEMPO column, over the samples with both.
pair_stats <- function(date, surface, column) {
  ok <- !is.na(date) & is.finite(surface) & is.finite(column)
  date <- date[ok]; surface <- surface[ok]; column <- column[ok]
  n  <- length(surface)
  r  <- if (n >= 3) stats::cor(surface, column) else NA_real_
  an <- month_anomalies(date, surface, column)
  an$i <- which(ok)[an$i]   # positions in the vectors passed to pair_stats()
  n_a <- nrow(an)
  r_a <- if (n_a >= 3) stats::cor(an$surface_anom, an$column_anom) else NA_real_
  list(n = n, r = r, n_anom = n_a, r_anom = r_a, anom = an)
}
