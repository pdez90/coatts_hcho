# worked.R - the calculations behind the "How the comparison works" tab.
#
# Each function repeats, on one monitor's samples, a step of the paper's
# calculation: the within-site-month permutation test (perm_anom_p() in
# R/helpers_stats.R), the noise ceiling (ceiling_stats() in
# R/17_national_diagnostics.R) and the site-month bootstrap of the difference
# between two correlations (dep_cor_test() in R/helpers_stats.R, as step 09 uses
# it for the Colorado 3 h windows). Step 24 checks that these reproduce the
# paper's tables, so the worked numbers in the app are the paper's numbers.

WK_NPERM <- 2000L    # permutations, as in the paper
WK_NBOOT <- 10000L   # bootstrap replicates for a difference between two correlations

# Run expr with a fixed seed, leaving the caller's random-number stream as it was.
with_seed <- function(seed, expr) {
  old <- if (exists(".Random.seed", envir = .GlobalEnv)) get(".Random.seed", envir = .GlobalEnv) else NULL
  on.exit(if (is.null(old)) suppressWarnings(rm(".Random.seed", envir = .GlobalEnv)) else
    assign(".Random.seed", old, envir = .GlobalEnv), add = TRUE)
  set.seed(seed)
  expr
}

# Within-site-month permutation test of the anomaly correlation. an: the anom
# element of pair_stats() for one site (columns date, ym, surface_anom,
# column_anom). Same canonical order, seed and two-sided rule as perm_anom_p(),
# so p is the paper's. Also returns every permuted r (for the histogram) and the
# surface anomalies of the first shuffle, in the row order of an.
perm_test <- function(an, nperm = WK_NPERM, seed = 42L) {
  if (nrow(an) < 3) return(NULL)
  o <- order(an$ym, an$date, an$column_anom, an$surface_anom)
  d <- an[o, , drop = FALSE]
  idx <- split(seq_len(nrow(d)), d$ym); idx <- idx[lengths(idx) > 1L]
  if (!length(idx)) return(NULL)
  x <- d$column_anom; y <- d$surface_anom
  obs <- cor(x, y)
  ord <- unlist(idx, use.names = FALSE); grp <- rep.int(seq_along(idx), lengths(idx)); base <- ord[order(grp)]
  rp <- numeric(nperm); first <- NULL
  with_seed(seed, for (b in seq_len(nperm)) {
    ys <- y
    ys[base] <- y[ord[order(grp, runif(length(ord)))]]
    if (b == 1L) first <- ys
    rp[b] <- suppressWarnings(cor(x, ys))
  })
  ge <- sum(is.finite(rp) & abs(rp) >= abs(obs) - 1e-12)
  shuffled <- numeric(nrow(an)); shuffled[o] <- first
  list(r_obs = obs, r_perm = rp, ge = ge, nperm = nperm, p = (ge + 1) / (nperm + 1), first_shuffle = shuffled)
}

# Noise ceiling of one monitor's anomaly correlation, step by step. an: anom
# element of pair_stats(); n_valid: valid scans of each anomaly's sample;
# scan_sd: the single-scan noise SD (10^15 molecules cm^-2) that step 17 estimated
# from successive scans. Each sample's noise variance is scan_sd^2 / k, times
# (1 - 1/m) for the site-month mean of m samples that the anomaly removes.
ceiling_steps <- function(an, n_valid, scan_sd) {
  if (!length(scan_sd) || !is.finite(scan_sd) || nrow(an) < 3) return(NULL)
  m      <- stats::ave(seq_along(an$ym), an$ym, FUN = length)
  nv_i   <- scan_sd^2 / n_valid * (1 - 1 / m)
  nv     <- mean(nv_i)
  vcol   <- stats::var(an$column_anom)
  f      <- nv / vcol
  ceil   <- sqrt(max(0, 1 - f))
  r_obs  <- stats::cor(an$surface_anom, an$column_anom)
  list(scan_sd = scan_sd, k = n_valid, m = m, nv_i = nv_i, noise_var = nv, noise_sd = sqrt(nv),
       median_k = stats::median(n_valid), var_col = vcol, sd_col = sqrt(vcol), share = f, ceiling = ceil,
       r_obs = r_obs, E = if (ceil > 0) r_obs / ceil else NA_real_)
}

# The Colorado 3 h samples with a usable TEMPO mean both in the sampling window
# (lag 0) and in the window 3 h later, and their within-site-month anomalies, in
# site-months holding at least MIN_PER_SITE_MONTH such samples (step 09).
window_pairs <- function(tempo, later = 3L) {
  c3 <- tempo[tempo$arm == "colorado_3h", ]
  w0 <- c3[c3$lag_h == 0L & c3$usable, c("site_id", "start_utc", "date", "hcho", "column")]
  wl <- c3[c3$lag_h == later & c3$usable, c("site_id", "start_utc", "column")]
  b  <- merge(w0, wl, by = c("site_id", "start_utc"), suffixes = c("_window", "_later"))
  b  <- b[order(b$site_id, b$start_utc), ]
  b$ym <- format(b$date, "%Y-%m")
  key  <- paste(b$site_id, b$ym)
  b <- b[stats::ave(seq_along(key), key, FUN = length) >= MIN_PER_SITE_MONTH, ]
  key <- paste(b$site_id, b$ym)
  b$surface_anom <- b$hcho - stats::ave(b$hcho, key)
  b$window_anom  <- b$column_window - stats::ave(b$column_window, key)
  b$later_anom   <- b$column_later - stats::ave(b$column_later, key)
  b$cluster <- key
  rownames(b) <- NULL
  b
}

# Difference between the two anomaly correlations (later window minus sampling
# window) for a set of rows k of window_pairs().
window_diff <- function(d, k = seq_len(nrow(d))) {
  ra <- suppressWarnings(stats::cor(d$surface_anom[k], d$later_anom[k]))
  rw <- suppressWarnings(stats::cor(d$surface_anom[k], d$window_anom[k]))
  c(r_window = rw, r_later = ra, diff = ra - rw)
}

# One bootstrap resample of whole site-months: as many site-months as there are,
# drawn with replacement, each keeping all its samples.
draw_clusters <- function(d) {
  ids <- unique(d$cluster)
  ids[sample.int(length(ids), length(ids), replace = TRUE)]
}
rows_of <- function(d, drawn) unlist(lapply(drawn, function(g) which(d$cluster == g)), use.names = FALSE)

# The site-month bootstrap of window_diff(): 95% percentile interval and the
# two-sided percentile-bootstrap p-value of dep_cor_test().
boot_window_diff <- function(d, nboot = WK_NBOOT, seed = 42L) {
  idx <- unname(split(seq_len(nrow(d)), d$cluster)); G <- length(idx)
  bt <- with_seed(seed, vapply(seq_len(nboot), function(b) {
    k <- unlist(idx[sample.int(G, G, replace = TRUE)])
    window_diff(d, k)[["diff"]]
  }, numeric(1)))
  bt <- bt[is.finite(bt)]
  list(diff = bt, lo = unname(stats::quantile(bt, 0.025)), hi = unname(stats::quantile(bt, 0.975)),
       n_le0 = sum(bt <= 0), n_ge0 = sum(bt >= 0), nboot = length(bt), clusters = G,
       p = min(1, (2 * min(sum(bt <= 0), sum(bt >= 0)) + 1) / (length(bt) + 1)))
}
