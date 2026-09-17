# =============================================================================
# helpers_stats.R - statistics shared by 05_analysis.R, 07_threeh_analysis.R
#                   and 13_national_analysis.R
# =============================================================================

rma_fit <- function(x, y) {
  r <- suppressWarnings(cor(x, y))
  if (!is.finite(r)) return(c(slope = NA_real_, intercept = NA_real_))
  sx <- sd(x); sy <- sd(y)
  if (!is.finite(sx) || !is.finite(sy) || sx == 0) return(c(slope = NA_real_, intercept = NA_real_))
  b <- sign(r) * sy / sx
  c(slope = b, intercept = mean(y) - b * mean(x))
}

# Bootstrap index generator. Resampling rows treats every observation as
# independent, which is right for a single site's own samples (the 1-in-6-day
# schedule breaks most day-to-day dependence) but wrong for a pooled fit, where
# the same monitors contribute many rows each. `cluster` names a column to
# resample instead of rows. With too few clusters a cluster bootstrap is
# degenerate rather than conservative, so below `min_clusters` it falls back to
# rows and says so in `rma_ci_basis`.
boot_index <- function(n, cl = NULL, min_clusters = 5L) {
  if (is.null(cl) || n_distinct(cl) < min_clusters) {
    return(list(draw = function() sample.int(n, n, replace = TRUE),
                basis = "row bootstrap (descriptive)"))
  }
  rows <- split(seq_len(n), cl)
  m <- length(rows)
  list(draw = function() unlist(rows[sample.int(m, m, replace = TRUE)], use.names = FALSE),
       basis = "cluster bootstrap by site")
}

relstats <- function(d, x = "tempo_vc_1e15", y = "hcho_ugm3", nboot = 1000,
                     cluster = NULL) {
  keep <- is.finite(d[[x]]) & is.finite(d[[y]])
  cl <- if (!is.null(cluster) && cluster %in% names(d)) d[[cluster]][keep] else NULL
  d <- d[keep, ]
  n <- nrow(d)
  if (n < 6) return(tibble(n = n))
  xx <- d[[x]]; yy <- d[[y]]
  pr <- cor.test(xx, yy, method = "pearson")
  sp <- suppressWarnings(cor.test(xx, yy, method = "spearman", exact = FALSE))
  ols <- coef(lm(yy ~ xx))
  rma <- rma_fit(xx, yy)

  # The RMA slope is sign(r) * sd(y)/sd(x). It is always defined, and it is now
  # always reported: withholding it when the Pearson p-value happens to exceed
  # 0.05 is selective reporting, and a reader cannot tell a suppressed slope
  # from an uncomputable one. Where r is near zero the sign is unstable and the
  # bootstrap interval will show that directly, which is the honest signal.
  bi <- boot_index(n, cl)
  boot <- replicate(nboot, {
    k <- bi$draw()
    if (length(k) < 3L) NA_real_ else rma_fit(xx[k], yy[k])[["slope"]]
  })
  ok <- is.finite(boot)

  tibble(n = n,
         pearson_r = pr$estimate[[1]], pearson_p = pr$p.value,
         spearman_rho = sp$estimate[[1]], spearman_p = sp$p.value,
         ols_slope = ols[[2]], ols_intercept = ols[[1]],
         rma_slope = rma[["slope"]],
         rma_slope_lo = if (!any(ok)) NA_real_ else quantile(boot[ok], 0.025)[[1]],
         rma_slope_hi = if (!any(ok)) NA_real_ else quantile(boot[ok], 0.975)[[1]],
         rma_intercept = rma[["intercept"]],
         rma_ci_basis = bi$basis,
         rma_n_clusters = if (is.null(cl)) NA_integer_ else n_distinct(cl),
         median_surface_ugm3 = median(yy), median_tempo_1e15 = median(xx),
         median_h_eff_km = median(d$h_eff_km, na.rm = TRUE),
         median_tempo_pbl_km = median(d$tempo_pbl_km, na.rm = TRUE))
}

# Remove site x calendar-month means so only day-to-day covariation remains.
# Months with fewer than min_n usable samples are dropped.
add_month_anomalies <- function(d, min_n) {
  d |>
    mutate(ym = floor_date(sample_date, "month")) |>
    group_by(site, ym) |>
    filter(n() >= min_n) |>
    mutate(surface_anom = hcho_ugm3 - mean(hcho_ugm3),
           column_anom = tempo_vc_1e15 - mean(tempo_vc_1e15)) |>
    ungroup()
}

# Within-site-month permutation test for the anomaly correlation.
#
# The site-month means were estimated from the same observations that go into
# the correlation, so the ordinary Pearson p-value spends degrees of freedom it
# does not have and is optimistic. Permuting one variable within each
# site x year-month stratum holds that nuisance structure fixed: a permutation
# does not change a stratum's mean, so permuting the anomalies within a stratum
# is exactly equivalent to permuting the underlying values and demeaning again.
# Two-sided, comparing |r|; the (ge + 1) / (nperm + 1) form keeps the p-value
# strictly positive, as it must be for a finite number of permutations.
#
# Strata of one cannot be permuted and are held fixed. add_month_anomalies()
# already drops months below CFG$min_days_per_site_month, so this is a guard
# rather than a common case.
# The seed is fixed INSIDE the function, and the caller's RNG state is restored
# on exit. Each script sets seed 42 at the top, which makes a whole run
# reproducible, but it does not make a single statistic reproducible: the same
# data permuted at a different point in the stream gives a different p-value.
# That showed up as Chatfield's +6 h anomaly carrying three different p-values
# (0.261, 0.253, 0.272) in one run, because it is computed once in anomstats()
# and twice more in the 2023 sensitivity, on identical rows. Seeding here makes
# the p-value independent of where in the stream it is computed, the canonical
# sort below makes it independent of row order, and restoring the state on exit
# keeps the bootstrap draws elsewhere unchanged.
perm_anom_p <- function(d, nperm = 2000L, seed = 42L) {
  if (!all(c("ym") %in% names(d))) return(NA_real_)
  if (!is.null(seed)) {
    if (exists(".Random.seed", envir = .GlobalEnv)) {
      .old_seed <- get(".Random.seed", envir = .GlobalEnv)
      on.exit(assign(".Random.seed", .old_seed, envir = .GlobalEnv), add = TRUE)
    } else {
      on.exit(suppressWarnings(rm(".Random.seed", envir = .GlobalEnv)), add = TRUE)
    }
    set.seed(seed)
  }
  # Canonical row order before permuting. Seeding alone makes the result
  # independent of the global RNG stream, but not of row order: split() and the
  # within-stratum shuffle both key off the order rows arrive in, so the same
  # observations delivered differently sorted would pair differently and give a
  # different p-value. Sorting here is what lets the p-value be called a
  # function of the data alone. The anomalies are included in the key so that
  # duplicate (site, month, date) rows, if any ever occur, still order stably.
  ord_key <- if (all(c("site", "sample_date") %in% names(d)))
               order(d$site, d$ym, d$sample_date, d$column_anom, d$surface_anom)
             else if ("sample_date" %in% names(d))
               order(d$ym, d$sample_date, d$column_anom, d$surface_anom)
             else order(d$ym, d$column_anom, d$surface_anom)
  d <- d[ord_key, , drop = FALSE]

  strat <- if ("site" %in% names(d)) paste(d$site, d$ym) else as.character(d$ym)
  idx <- split(seq_len(nrow(d)), strat)
  idx <- idx[lengths(idx) > 1L]
  if (!length(idx)) return(NA_real_)
  x <- d$column_anom; y <- d$surface_anom
  obs <- suppressWarnings(abs(cor(x, y)))
  if (!is.finite(obs)) return(NA_real_)

  ord   <- unlist(idx, use.names = FALSE)
  grp   <- rep.int(seq_along(idx), lengths(idx))
  base  <- ord[order(grp)]          # the rows to write, in stratum order
  ge <- 0L
  for (b in seq_len(nperm)) {
    ys <- y
    # rows drawn in stratum order but shuffled within each stratum
    ys[base] <- y[ord[order(grp, runif(length(ord)))]]
    rp <- suppressWarnings(abs(cor(x, ys)))
    if (is.finite(rp) && rp >= obs - 1e-12) ge <- ge + 1L
  }
  (ge + 1) / (nperm + 1)
}

# Correlation of anomalies. pearson_p is the ordinary test and is optimistic for
# the reason given above; pearson_p_perm is the within-site-month permutation
# p-value and is the one to quote.
anomstats <- function(d, nperm = 2000L) {
  if (nrow(d) < 6) return(tibble(n = nrow(d)))
  pr <- cor.test(d$column_anom, d$surface_anom)
  sp <- suppressWarnings(cor.test(d$column_anom, d$surface_anom, method = "spearman", exact = FALSE))
  months <- if ("site" %in% names(d)) n_distinct(paste(d$site, d$ym)) else n_distinct(d$ym)
  tibble(n = nrow(d), site_months = months,
         pearson_r = pr$estimate[[1]], pearson_p = pr$p.value,
         pearson_p_perm = perm_anom_p(d, nperm),
         spearman_rho = sp$estimate[[1]], spearman_p = sp$p.value,
         ols_slope = coef(lm(surface_anom ~ column_anom, data = d))[[2]])
}
