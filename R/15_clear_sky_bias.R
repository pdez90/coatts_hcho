# =============================================================================
# 15_clear_sky_bias.R - is the subset of days TEMPO can see representative?
#
# Cloud screening removes a quarter to a third of sample days. Goldberg et al.
# (2025) show that for NO2 the days a satellite can see are systematically
# different from the days it cannot: surface NO2 is higher under cloud, because
# its photochemical sink is slower. HCHO is predominantly secondary, so the
# expectation runs the other way. This step tests it directly, in both arms.
#
# Days are split three ways: usable (at least one scan passed screening),
# screened out (scans existed but none passed - overwhelmingly cloud), and no
# scan at all. The clear-versus-cloudy comparison uses the first two, so that
# gaps in TEMPO's own sampling do not enter it. Differences are taken within
# site and calendar month, which removes the seasonal cycle in both cloud
# frequency and HCHO.
#
# Inputs : data/processed/matched_primary.csv       (Colorado, 24 h)
#          data/processed/aqs_matched_primary.csv.gz (national)
# Outputs: output/tables/clear_sky_bias.csv          (one row per arm/stratum)
#          output/tables/clear_sky_day_types.csv     (day counts and cloud fraction)
#          output/tables/clear_sky_bias_fixed_effects.csv (site + month FE estimate)
#          output/figures/fig14_clear_sky_bias.png
# =============================================================================
source("R/00_config.R")
set.seed(42)

is_true <- function(x) x %in% c(TRUE, "TRUE", "True", "true", "1", 1)

# ---- 1. assemble both arms on a common set of columns ------------------------
co <- read_tbl(file.path(P$processed, "matched_primary.csv")) |>
  transmute(arm = "Colorado (24 h)", site, sample_date = as.Date(sample_date),
            season, hcho_ugm3, n_scans, n_valid_scans,
            mean_ecf = suppressWarnings(as.numeric(mean_ecf)),
            usable = is_true(usable))

nat_path <- file.path(P$processed, "aqs_matched_primary.csv.gz")
nat <- read_tbl(nat_path, colClasses = list(character = c("site", "site_id"))) |>
  filter(duration_class == "24 h", lag_h == 0) |>
  transmute(arm = "National (24 h)", site, sample_date = as.Date(sample_date),
            season, hcho_ugm3, n_scans, n_valid_scans,
            mean_ecf = NA_real_, usable = is_true(usable))

d <- bind_rows(co, nat) |>
  filter(!is.na(hcho_ugm3)) |>
  mutate(day_type = case_when(usable ~ "usable",
                              n_scans > 0 ~ "screened out",
                              TRUE ~ "no scan"),
         ym = format(sample_date, "%Y-%m"))

types <- d |>
  group_by(arm, day_type) |>
  summarise(days = n(), pct = NA_real_,
            median_ecf = suppressWarnings(median(mean_ecf, na.rm = TRUE)),
            median_hcho = median(hcho_ugm3), .groups = "drop") |>
  group_by(arm) |> mutate(pct = round(100 * days / sum(days), 1)) |> ungroup()
data.table::fwrite(types, file.path(P$tables, "clear_sky_day_types.csv"))
print(types)
for (a in unique(types$arm)) {
  t <- filter(types, arm == a)
  log_msg(a, ": ", paste(sprintf("%s %d (%.1f%%)", t$day_type, t$days, t$pct), collapse = "; "))
}

# ---- 2. within site-month contrast -------------------------------------------
# Each site-month with at least CFG$min_days_per_site_month samples and at least
# one day of each kind contributes deviations from its own mean.
contrast <- function(x, label) {
  g <- x |>
    group_by(site, ym) |>
    filter(n() >= CFG$min_days_per_site_month,
           any(usable), any(!usable)) |>
    mutate(anom = hcho_ugm3 - mean(hcho_ugm3)) |>
    ungroup()
  if (!nrow(g)) return(tibble())
  clear  <- g$anom[g$usable]
  cloudy <- g$anom[!g$usable]
  # a season can be left with too few qualifying site-months to test (JJA in
  # Colorado has only a handful of cloudy days); report the difference and leave
  # the test statistics missing rather than failing
  safe_t <- function(...) tryCatch(t.test(...), error = function(e) NULL)
  tt <- if (length(clear) >= 2 && length(cloudy) >= 2) safe_t(cloudy, clear) else NULL
  # paired at the site-month level as well, which is the conservative version
  pm <- g |> group_by(site, ym) |>
    summarise(d = mean(anom[!usable]) - mean(anom[usable]), .groups = "drop")
  pt <- if (nrow(pm) >= 2) safe_t(pm$d) else NULL
  tibble(stratum = label,
         site_months = n_distinct(paste(g$site, g$ym)),
         n_clear = length(clear), n_cloudy = length(cloudy),
         mean_anom_clear = mean(clear), mean_anom_cloudy = mean(cloudy),
         diff_ugm3 = mean(cloudy) - mean(clear),
         t = if (is.null(tt)) NA_real_ else unname(tt$statistic),
         p = if (is.null(tt)) NA_real_ else tt$p.value,
         paired_diff_ugm3 = mean(pm$d),
         paired_p = if (is.null(pt)) NA_real_ else pt$p.value,
         median_hcho = median(g$hcho_ugm3),
         diff_pct = 100 * (mean(cloudy) - mean(clear)) / median(g$hcho_ugm3))
}

out <- list()
for (a in unique(d$arm)) {
  x <- filter(d, arm == a, day_type != "no scan")   # clear vs cloud-screened
  out[[length(out) + 1]] <- contrast(x, "all") |> mutate(arm = a, .before = 1)
  for (s in c("DJF", "MAM", "JJA", "SON")) {
    r <- contrast(filter(x, season == s), s)
    if (nrow(r)) out[[length(out) + 1]] <- mutate(r, arm = a, .before = 1)
  }
}
bias <- bind_rows(out)
data.table::fwrite(bias, file.path(P$tables, "clear_sky_bias.csv"))

for (i in seq_len(nrow(bias))) {
  b <- bias[i, ]
  # the site-month paired test is the one to quote: within a site-month the two
  # groups of anomalies are mechanically anti-correlated, so the unpooled t is
  # anti-conservative
  log_msg(sprintf("%s, %s: %d site-months; cloudy minus clear %+.3f ug/m3 (%+.1f%%); paired %+.3f, p = %.3g (unpaired t = %.1f)",
                  b$arm, b$stratum, b$site_months, b$diff_ugm3, b$diff_pct,
                  b$paired_diff_ugm3, b$paired_p, b$t))
}

# ---- 2b. fixed-effects estimate ----------------------------------------------
# HCHO_it = alpha_site + gamma_month + beta * usable_it + e_it
# beta is the difference in surface HCHO between days TEMPO can and cannot see,
# holding the site and the calendar month fixed. Unlike the within-site-month
# contrast above this uses every day, not only site-months containing both kinds.
fe <- lapply(unique(d$arm), function(a) {
  x <- filter(d, arm == a, day_type != "no scan") |>
    mutate(month = factor(format(sample_date, "%m")), site = factor(site))
  if (n_distinct(x$usable) < 2) return(NULL)
  m <- lm(hcho_ugm3 ~ usable + site + month, data = x)
  co <- summary(m)$coefficients
  r <- co[grep("^usableTRUE$", rownames(co)), , drop = FALSE]
  if (!nrow(r)) return(NULL)
  tibble(arm = a, n = nrow(x), sites = n_distinct(x$site),
         beta_usable_ugm3 = r[1, 1], se = r[1, 2], t = r[1, 3], p = r[1, 4],
         median_hcho = median(x$hcho_ugm3),
         beta_pct = 100 * r[1, 1] / median(x$hcho_ugm3))
}) |> bind_rows()
if (nrow(fe)) {
  data.table::fwrite(fe, file.path(P$tables, "clear_sky_bias_fixed_effects.csv"))
  for (i in seq_len(nrow(fe))) {
    b <- fe[i, ]
    log_msg(sprintf("%s, site + month fixed effects: usable day %+.3f +/- %.3f ug/m3 (%+.1f%%), t = %.1f, p = %.3g (n = %d, %d sites)",
                    b$arm, b$beta_usable_ugm3, b$se, b$beta_pct, b$t, b$p, b$n, b$sites))
  }
}

# ---- 3. figure ---------------------------------------------------------------
plot_d <- d |>
  filter(day_type != "no scan") |>
  group_by(arm, site, ym) |>
  filter(n() >= CFG$min_days_per_site_month, any(usable), any(!usable)) |>
  mutate(anom = hcho_ugm3 - mean(hcho_ugm3)) |>
  ungroup() |>
  mutate(sky = factor(ifelse(usable, "TEMPO usable\n(clear)", "screened out\n(cloudy)"),
                      levels = c("TEMPO usable\n(clear)", "screened out\n(cloudy)")))

p <- ggplot(plot_d, aes(sky, anom, fill = sky)) +
  geom_hline(yintercept = 0, colour = "grey50", linewidth = 0.3) +
  geom_boxplot(width = 0.55, outlier.size = 0.4, outlier.alpha = 0.3, show.legend = FALSE) +
  stat_summary(fun = mean, geom = "point", shape = 23, size = 2.4,
               fill = "white", show.legend = FALSE) +
  facet_wrap(~ arm) +
  scale_fill_manual(values = c("#5ab4ac", "#b8b8b8")) +
  coord_cartesian(ylim = quantile(plot_d$anom, c(0.01, 0.99), na.rm = TRUE)) +
  labs(x = NULL, y = expression("Surface HCHO anomaly ("*mu*g~m^{-3}*")"),
       title = "Are the days TEMPO can see representative?",
       subtitle = "Deviations from the site and calendar-month mean; diamonds are means. Axes truncated at the 1st and 99th percentiles.") +
  theme_bw(base_size = 10) +
  theme(plot.subtitle = element_text(size = 8), panel.grid.minor = element_blank())

ggsave(file.path(P$figures, "fig14_clear_sky_bias.png"), p, width = 7, height = 4.2, dpi = 300)
log_msg("  figure: fig14_clear_sky_bias.png")
log_msg("Clear-sky bias test done.")
