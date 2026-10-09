# =============================================================================
# 25_geography.R - does day-to-day agreement depend on where a monitor is?
#
# A reviewer asked whether agreement differs between the western and eastern
# United States, and between homogeneous and complex terrain. Among the 24 h
# monitors the lowest day-to-day correlations sit on the coast of southern
# California, in the Salt Lake basin and along the Colorado Front Range, while
# the highest include the inland Central Valley of California, so longitude,
# the coast and terrain are tested separately.
#
# For every 24 h monitor with a site-level day-to-day correlation (step 13: at
# least CFG$min_anom_pairs_site matched samples and anomaly pairs) the step
# derives three descriptors, fixed before their association with agreement was
# examined:
#   west      monitor west of 100 deg W (the 100th meridian)
#   coast_km  geodesic distance to the ocean coastline: the Atlantic, Pacific and
#             Gulf features of the U.S. Census TIGER/Line coastline file,
#             downloaded once and cached in data/raw/basemap. The distance to the
#             Great Lakes shoreline is recorded but not tested.
#   relief_m  terrain relief across the 5 x 5 block of TEMPO grid cells around the
#             monitor (about 11 km x 8.5 km): for each scan, the height
#             difference between the cells of highest and lowest TEMPO surface
#             pressure, SCALE_H_M x ln(p_max / p_min), and its median over scans.
#             The surface pressure supplied with each 0.02 deg cell follows that
#             cell's terrain, so no elevation data are needed; the synoptic
#             pressure gradient across 11 km is about 0.1 hPa (~1 m) and is
#             ignored. The 3 x 3 relief is recorded too.
# Tests: Wilcoxon rank-sum for west vs east and coastal (coast_km <= COAST_KM)
# vs inland; Spearman correlation with longitude, log10(coast_km) and
# log10(relief_m); medians by relief tertile (quantile cut, ties together, as
# step 13 cuts concentration). Then, at the sites of step 20's site model, the
# three descriptors are added to M1 (Fisher z of the observed r) and M2 (Fisher z
# of E = r / ceiling), weighted by n - 3 as there, and tested jointly with a
# nested F test. The step stops unless its base models reproduce step 20's R^2.
#
# Reads what steps 12, 13 and 20 wrote; downloads only the coastline file.
# Outputs: output/tables/geography_sites.csv
#          output/tables/geography_groups.csv
#          output/tables/geography_tests.csv
#          output/tables/geography_models.csv
#          output/tables/manuscript_numbers_25.csv
#          output/figures/fig25_geography.png
# =============================================================================
source("R/00_config.R")
source("R/helpers_basemap.R")
HAS_GG <- requireNamespace("ggplot2", quietly = TRUE)
if (HAS_GG) theme_set(theme_bw(base_size = 11) + theme(strip.background = element_rect(fill = "grey92")))
if (!have_sf()) stop("Package 'sf' is needed for the coastline distances: install.packages(\"sf\")")
check <- function(ok, ...) if (!isTRUE(all(ok))) stop(...)

bysite_path <- file.path(P$tables, "national_stats_by_site.csv")
gap_path    <- file.path(P$tables, "diag8_ceiling_gap_sites.csv")
models_path <- file.path(P$tables, "diag8_ceiling_gap_models.csv")
cells_path  <- file.path(P$processed, "aqs_tempo_site_cells.csv.gz")
for (f in c(bysite_path, gap_path, models_path, cells_path)) {
  if (!file.exists(f)) stop("Missing ", f, " - run steps 12, 13 and 20 first.")
}

MIN_PAIRS <- CFG$min_anom_pairs_site   # as steps 13, 17 and 20
WEST_LON  <- -100                      # deg E
COAST_KM  <- 50                        # "coastal": within 50 km of the ocean coastline
SCALE_T_K <- 288                       # temperature of the scale height, K
SCALE_H_M <- 8430                      # R_d x 288 K / g, in m
fz <- function(r) atanh(pmin(pmax(r, -0.999), 0.999))
# two decimals, never "-0.00" (as step 20); p-values as "p = 0.039" or "p < 0.001"
r2   <- function(x) { s <- sprintf("%.2f", x); s3 <- sprintf("%.3f", x)
  ifelse(!is.na(x) & abs(x) < 0.005, ifelse(s3 %in% c("0.000", "-0.000"), "0.00", s3), s) }
ptxt <- function(p) ifelse(is.na(p), "NA", ifelse(p < 0.001, "p < 0.001", sprintf("p = %.3f", p)))

# ---- 1. the sites ------------------------------------------------------------
sites <- read_tbl(bysite_path, colClasses = list(character = c("site", "networks"))) |>
  filter(duration_class == "24 h", n >= MIN_PAIRS, anom_n >= MIN_PAIRS, is.finite(anom_pearson_r)) |>
  transmute(site, site_name, state, lat = as.numeric(lat), lon = as.numeric(lon),
            n = as.integer(n), anom_n = as.integer(anom_n), r = pearson_r, r_anom = anom_pearson_r)
check(!anyDuplicated(sites$site) & is.finite(sites$lat) & is.finite(sites$lon), "Bad site rows in ", bysite_path)
log_msg(nrow(sites), " 24 h sites with a site-level day-to-day correlation")

# ---- 2. terrain relief from TEMPO surface pressure ------------------------------
cells <- data.table::fread(cells_path, select = c("granule", "site", "di", "dj", "surface_pressure"),
                           colClasses = list(character = c("granule", "site"))) |>
  tibble::as_tibble() |>
  filter(site %in% sites$site, is.finite(surface_pressure), surface_pressure > 0) |>
  distinct(site, granule, di, dj, .keep_all = TRUE)
relief_scan <- cells |>
  mutate(in3 = abs(di) <= 1 & abs(dj) <= 1) |>
  group_by(site, granule) |>
  summarise(relief5 = if (n() == 25L) SCALE_H_M * log(max(surface_pressure) / min(surface_pressure)) else NA_real_,
            relief3 = if (sum(in3) == 9L) SCALE_H_M * log(max(surface_pressure[in3]) / min(surface_pressure[in3])) else NA_real_,
            .groups = "drop")
rm(cells)
relief <- relief_scan |>
  group_by(site) |>
  summarise(relief5_m = median(relief5, na.rm = TRUE), scans5 = sum(!is.na(relief5)),
            relief3_m = median(relief3, na.rm = TRUE), scans3 = sum(!is.na(relief3)), .groups = "drop")
miss <- setdiff(sites$site, relief$site[relief$scans5 >= 20])
check(!length(miss), "Fewer than 20 complete 5 x 5 scans for the relief at: ", paste(miss, collapse = ", "))
log_msg("Terrain relief (5 x 5 block): median ", round(median(relief$relief5_m)), " m, range ",
        round(min(relief$relief5_m)), "-", round(max(relief$relief5_m)), " m; ",
        min(relief$scans5), "-", max(relief$scans5), " complete scans per site")

# ---- 3. distance to the coast ---------------------------------------------------
# TIGER/Line coastline, fetched and cached as helpers_basemap.R fetches the
# cartographic boundary files.
coastline <- function(base_dir = BASEMAP_DIR) {
  dir.create(base_dir, recursive = TRUE, showWarnings = FALSE)
  for (yr in c(2023L, 2022L)) {
    f <- file.path(base_dir, sprintf("tl_%d_us_coastline.zip", yr))
    if (!file.exists(f) || file.size(f) < 1000) {
      url <- sprintf("https://www2.census.gov/geo/tiger/TIGER%d/COASTLINE/tl_%d_us_coastline.zip", yr, yr)
      ok <- tryCatch({
        resp <- httr2::req_perform(public_request(url), path = f)
        httr2::resp_status(resp) < 400 && file.size(f) > 1000
      }, error = function(e) FALSE)
      if (!ok) { unlink(f); next }
      log_msg("  downloaded ", basename(f))
    }
    d <- file.path(base_dir, tools::file_path_sans_ext(basename(f)))
    if (!dir.exists(d)) utils::unzip(f, exdir = d)
    shp <- list.files(d, pattern = "\\.shp$", full.names = TRUE)
    if (length(shp)) return(sf::st_read(shp[1], quiet = TRUE))
  }
  stop("Could not obtain the Census TIGER/Line coastline file.")
}
coast <- coastline()
check("NAME" %in% names(coast), "The coastline file has no NAME field: ", paste(names(coast), collapse = ", "))
tab <- table(coast$NAME)
log_msg("Coastline features by water body: ", paste(sprintf("%s %d", names(tab), as.integer(tab)), collapse = "; "))
is_ocean <- grepl("Atlantic|Pacific|Gulf", coast$NAME)
is_lakes <- grepl("Great Lakes", coast$NAME)
check(any(grepl("Atlantic", coast$NAME)) & any(grepl("Pacific", coast$NAME)) & any(grepl("Gulf", coast$NAME)),
      "The coastline file lacks an Atlantic, Pacific or Gulf feature")
pts <- sf::st_as_sf(sites, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
min_km <- function(lines) {
  if (!nrow(lines)) return(rep(NA_real_, nrow(pts)))
  d <- sf::st_distance(pts, sf::st_transform(lines, 4326))       # geodesic (s2), m
  apply(matrix(as.numeric(d), nrow = nrow(pts)), 1, min) / 1000
}
sites$coast_km <- min_km(coast[is_ocean, ])
sites$lakes_km <- min_km(coast[is_lakes, ])
check(is.finite(sites$coast_km) & sites$coast_km >= 0, "Distance to the coast could not be computed")
ord <- order(sites$coast_km)
log_msg("Nearest the coast: ", paste(sprintf("%s %.0f km", sites$site_name[head(ord, 3)], sites$coast_km[head(ord, 3)]), collapse = "; "),
        "; farthest: ", paste(sprintf("%s %.0f km", sites$site_name[tail(ord, 2)], sites$coast_km[tail(ord, 2)]), collapse = "; "))

# ---- 4. tests -------------------------------------------------------------------
geo <- sites |>
  left_join(relief, by = "site") |>
  mutate(west = lon < WEST_LON, coastal = coast_km <= COAST_KM,
         relief_class = cut(relief5_m, unique(quantile(relief5_m, c(0, 1 / 3, 2 / 3, 1))),
                            include.lowest = TRUE, labels = c("low", "mid", "high")))
check(nlevels(geo$relief_class) == 3 & !anyNA(geo$relief_class), "The relief tertiles could not be formed")
data.table::fwrite(geo, file.path(P$tables, "geography_sites.csv"))

q3 <- function(x) stats::quantile(x, c(0.25, 0.5, 0.75), names = FALSE)
grp <- function(g, label, levels) {
  map_dfr(levels, function(l) {
    x <- geo$r_anom[g == l]
    tibble(grouping = label, group = as.character(l), n_sites = length(x),
           median_r_anom = q3(x)[2], q25 = q3(x)[1], q75 = q3(x)[3], median_r = median(geo$r[g == l]))
  })
}
groups <- bind_rows(
  grp(ifelse(geo$west, "west", "east"), "longitude (100 W)", c("west", "east")),
  grp(ifelse(geo$coastal, "coastal", "inland"), sprintf("ocean coast (%d km)", COAST_KM), c("coastal", "inland")),
  grp(as.character(geo$relief_class), "terrain relief, 5 x 5 block (tertiles)", c("low", "mid", "high")),
  grp(paste(ifelse(geo$west, "west", "east"), ifelse(geo$coastal, "coastal", "inland")), "longitude x coast",
      c("west coastal", "west inland", "east coastal", "east inland")))
rng <- tapply(geo$relief5_m, geo$relief_class, range)
groups$range <- NA_character_
for (l in names(rng)) groups$range[groups$grouping == "terrain relief, 5 x 5 block (tertiles)" & groups$group == l] <-
  sprintf("%.0f\u2013%.0f m", rng[[l]][1], rng[[l]][2])
data.table::fwrite(groups, file.path(P$tables, "geography_groups.csv"))

wil <- function(g) suppressWarnings(stats::wilcox.test(geo$r_anom[g], geo$r_anom[!g], exact = FALSE))$p.value
spr <- function(x) {
  ct <- suppressWarnings(stats::cor.test(x, geo$r_anom, method = "spearman", exact = FALSE))
  c(unname(ct$estimate), ct$p.value)
}
s_lon <- spr(geo$lon); s_coast <- spr(log10(pmax(geo$coast_km, 0.1))); s_rel <- spr(log10(pmax(geo$relief5_m, 1)))
tests <- tibble(
  test = c("west vs east (Wilcoxon)", sprintf("coastal (<= %d km) vs inland (Wilcoxon)", COAST_KM),
           "high vs low relief tertile (Wilcoxon)",
           "longitude (Spearman)", "log10 distance to the ocean coast (Spearman)", "log10 terrain relief (Spearman)"),
  statistic = c(NA, NA, NA, s_lon[1], s_coast[1], s_rel[1]),
  p = c(wil(geo$west), wil(geo$coastal),
        suppressWarnings(stats::wilcox.test(geo$r_anom[geo$relief_class == "high"], geo$r_anom[geo$relief_class == "low"],
                                            exact = FALSE))$p.value,
        s_lon[2], s_coast[2], s_rel[2]),
  n_sites = nrow(geo))
data.table::fwrite(tests, file.path(P$tables, "geography_tests.csv"))
for (i in seq_len(nrow(tests)))
  log_msg("  ", tests$test[i], ": ", if (is.na(tests$statistic[i])) "" else sprintf("rho %.2f, ", tests$statistic[i]),
          ptxt(tests$p[i]))
for (i in seq_len(nrow(groups)))
  log_msg("  ", groups$grouping[i], " / ", groups$group[i], ": n ", groups$n_sites[i], ", median day-to-day r ",
          r2(groups$median_r_anom[i]), " (", r2(groups$q25[i]), "-", r2(groups$q75[i]), ")")

# ---- 5. the site model of step 20, with geography added --------------------------
SIX  <- c("log_surface", "log_snr", "log_scans", "usable_pct", "pbl_hrrr_km", "smoke_share")
GEO3 <- c("west", "log_coast", "log_relief")
gap <- read_tbl(gap_path, colClasses = list(character = c("site", "block_label", "networks"))) |>
  inner_join(geo |> transmute(site, west = as.numeric(west), log_coast = log10(pmax(coast_km, 0.1)),
                              log_relief = log10(pmax(relief5_m, 1))), by = "site")
check(nrow(gap) == nrow(read_tbl(gap_path, colClasses = list(character = c("site", "block_label", "networks")))),
      "Some sites of step 20's model have no geography")
check(all(abs(gap$anomaly_r_observed - geo$r_anom[match(gap$site, geo$site)]) < 1e-9),
      "Step 20's site correlations differ from step 13's: re-run step 20 before step 25")
ref <- read_tbl(models_path)
fit_geo <- function(outcome, ref_model, label) {
  d <- gap |> select(all_of(c(outcome, SIX, GEO3, "n_anomalies"))) |> drop_na()
  Z <- d |> mutate(across(all_of(c(SIX, GEO3)), ~ as.numeric(scale(.x))))
  w <- Z$n_anomalies - 3
  f0 <- lm(reformulate(SIX, response = outcome), data = Z, weights = w)
  f1 <- lm(reformulate(c(SIX, GEO3), response = outcome), data = Z, weights = w)
  fg <- lm(reformulate(GEO3, response = outcome), data = Z, weights = w)
  r2_ref <- ref$r2[startsWith(ref$model, ref_model)][1]
  check(abs(summary(f0)$r.squared - r2_ref) < 1e-9,
        "The base model does not reproduce step 20's ", ref_model, " (R2 ", summary(f0)$r.squared, " vs ", r2_ref, ")")
  a  <- stats::anova(f0, f1)
  co <- coef(summary(f1))
  tibble(model = label, outcome = outcome, n_sites = nrow(d),
         r2_base = summary(f0)$r.squared, r2_with_geography = summary(f1)$r.squared,
         adj_r2_base = summary(f0)$adj.r.squared, adj_r2_with_geography = summary(f1)$adj.r.squared,
         r2_geography_only = summary(fg)$r.squared,
         f_geography = a$F[2], p_geography = a$`Pr(>F)`[2],
         term = rownames(co), estimate_per_sd = co[, 1], se = co[, 2], p = co[, 4])
}
models <- bind_rows(fit_geo("z_obs", "M1", "M1 + geography: Fisher z of observed r"),
                    fit_geo("z_eff", "M2", "M2 + geography: Fisher z of E"))
data.table::fwrite(models, file.path(P$tables, "geography_models.csv"))
for (m in unique(models$model)) {
  mm <- filter(models, model == m)
  log_msg("  ", m, ": n ", mm$n_sites[1], ", R2 ", r2(mm$r2_base[1]), " -> ", r2(mm$r2_with_geography[1]),
          " (geography alone ", r2(mm$r2_geography_only[1]), "; joint F test ", ptxt(mm$p_geography[1]), "); ",
          paste(sprintf("%s %+.2f (%s)", mm$term[mm$term %in% GEO3], mm$estimate_per_sd[mm$term %in% GEO3],
                        ptxt(mm$p[mm$term %in% GEO3])), collapse = ", "))
}

# ---- 6. manuscript numbers -------------------------------------------------------
g  <- function(grouping, group, what) groups[[what]][startsWith(groups$grouping, grouping) & groups$group == group][1]
m1 <- filter(models, startsWith(model, "M1")); m2 <- filter(models, startsWith(model, "M2"))
term <- function(m, t, what) m[[what]][m$term == t][1]
nums <- tibble(
  key = c("geo_sites", "geo_west_lon", "geo_coast_km",
          "geo_west_n", "geo_west_med", "geo_west_q25", "geo_west_q75",
          "geo_east_n", "geo_east_med", "geo_east_q25", "geo_east_q75", "geo_west_p",
          "geo_coastal_n", "geo_coastal_med", "geo_coastal_q25", "geo_coastal_q75",
          "geo_inland_n", "geo_inland_med", "geo_inland_q25", "geo_inland_q75", "geo_coastal_p",
          "geo_wc_n", "geo_wc_med", "geo_wi_n", "geo_wi_med", "geo_ec_n", "geo_ec_med", "geo_ei_n", "geo_ei_med",
          "geo_relief_low_n", "geo_relief_low_med", "geo_relief_low_range",
          "geo_relief_mid_n", "geo_relief_mid_med", "geo_relief_mid_range",
          "geo_relief_high_n", "geo_relief_high_med", "geo_relief_high_range", "geo_relief_hl_p",
          "geo_lon_rho", "geo_lon_p", "geo_coast_rho", "geo_coast_p", "geo_relief_rho", "geo_relief_p",
          "geo_m1_sites", "geo_m1_r2_base", "geo_m1_r2_geo", "geo_m1_r2_geo_only", "geo_m1_p",
          "geo_m1_west", "geo_m1_west_p", "geo_m1_coast", "geo_m1_coast_p", "geo_m1_relief", "geo_m1_relief_p",
          "geo_m1_snr", "geo_m1_snr_p", "geo_m1_smoke", "geo_m1_smoke_p", "geo_scale_h_km", "geo_scale_t_k",
          "geo_m2_r2_base", "geo_m2_r2_geo", "geo_m2_p"),
  value = c(as.character(nrow(geo)), as.character(abs(WEST_LON)), as.character(COAST_KM),
            g("longitude", "west", "n_sites"), r2(g("longitude", "west", "median_r_anom")), r2(g("longitude", "west", "q25")), r2(g("longitude", "west", "q75")),
            g("longitude", "east", "n_sites"), r2(g("longitude", "east", "median_r_anom")), r2(g("longitude", "east", "q25")), r2(g("longitude", "east", "q75")),
            ptxt(tests$p[1]),
            g("ocean coast", "coastal", "n_sites"), r2(g("ocean coast", "coastal", "median_r_anom")), r2(g("ocean coast", "coastal", "q25")), r2(g("ocean coast", "coastal", "q75")),
            g("ocean coast", "inland", "n_sites"), r2(g("ocean coast", "inland", "median_r_anom")), r2(g("ocean coast", "inland", "q25")), r2(g("ocean coast", "inland", "q75")),
            ptxt(tests$p[2]),
            g("longitude x coast", "west coastal", "n_sites"), r2(g("longitude x coast", "west coastal", "median_r_anom")),
            g("longitude x coast", "west inland", "n_sites"), r2(g("longitude x coast", "west inland", "median_r_anom")),
            g("longitude x coast", "east coastal", "n_sites"), r2(g("longitude x coast", "east coastal", "median_r_anom")),
            g("longitude x coast", "east inland", "n_sites"), r2(g("longitude x coast", "east inland", "median_r_anom")),
            g("terrain", "low", "n_sites"), r2(g("terrain", "low", "median_r_anom")), g("terrain", "low", "range"),
            g("terrain", "mid", "n_sites"), r2(g("terrain", "mid", "median_r_anom")), g("terrain", "mid", "range"),
            g("terrain", "high", "n_sites"), r2(g("terrain", "high", "median_r_anom")), g("terrain", "high", "range"),
            ptxt(tests$p[3]),
            r2(s_lon[1]), ptxt(s_lon[2]), r2(s_coast[1]), ptxt(s_coast[2]), r2(s_rel[1]), ptxt(s_rel[2]),
            as.character(m1$n_sites[1]), r2(m1$r2_base[1]), r2(m1$r2_with_geography[1]), r2(m1$r2_geography_only[1]),
            ptxt(m1$p_geography[1]),
            sprintf("%+.2f", term(m1, "west", "estimate_per_sd")), ptxt(term(m1, "west", "p")),
            sprintf("%+.2f", term(m1, "log_coast", "estimate_per_sd")), ptxt(term(m1, "log_coast", "p")),
            sprintf("%+.2f", term(m1, "log_relief", "estimate_per_sd")), ptxt(term(m1, "log_relief", "p")),
            sprintf("%+.2f", term(m1, "log_snr", "estimate_per_sd")), ptxt(term(m1, "log_snr", "p")),
            sprintf("%+.2f", term(m1, "smoke_share", "estimate_per_sd")), ptxt(term(m1, "smoke_share", "p")),
            sprintf("%.2f", SCALE_H_M / 1000), sprintf("%d", SCALE_T_K),
            r2(m2$r2_base[1]), r2(m2$r2_with_geography[1]), ptxt(m2$p_geography[1])),
  source = "R/25_geography.R")
check(!anyNA(nums$value) & !any(nums$value %in% c("NA", "")), "A geography number is missing: ",
      paste(nums$key[is.na(nums$value) | nums$value %in% c("NA", "")], collapse = ", "))
data.table::fwrite(nums, file.path(P$tables, "manuscript_numbers_25.csv"))

# ---- 7. figure -------------------------------------------------------------------
if (HAS_GG) {
  long <- bind_rows(
    transmute(geo, panel = "(a) longitude (deg E)", x = lon, r_anom, anom_n, coastal),
    transmute(geo, panel = "(b) distance to the ocean coast (km, log scale)", x = log10(pmax(coast_km, 0.1)), r_anom, anom_n, coastal),
    transmute(geo, panel = "(c) terrain relief in the 5 x 5 block (m, log scale)", x = log10(pmax(relief5_m, 1)), r_anom, anom_n, coastal)) |>
    mutate(panel = factor(panel, levels = unique(panel)),
           where = factor(ifelse(coastal, sprintf("within %d km of the ocean coast", COAST_KM), "inland"),
                          levels = c(sprintf("within %d km of the ocean coast", COAST_KM), "inland")))
  vline <- tibble(panel = factor(levels(long$panel)[1], levels = levels(long$panel)), x = WEST_LON)
  p25 <- ggplot(long, aes(x, r_anom)) +
    geom_hline(yintercept = 0, colour = "grey75") +
    geom_vline(data = vline, aes(xintercept = x), colour = "grey55", linetype = 2) +
    geom_smooth(method = "loess", formula = y ~ x, se = FALSE, colour = "grey35", linewidth = 0.6, span = 0.9) +
    geom_point(aes(size = anom_n, fill = where), shape = 21, colour = "white", stroke = 0.4, alpha = 0.9) +
    scale_fill_manual(values = c("#D55E00", "#0072B2"), name = NULL) +
    scale_size_area(max_size = 5, breaks = c(25, 50, 100), name = "anomaly\npairs") +
    # legend keys drawn grey and filled (the points' white outline would hide them)
    guides(size = guide_legend(override.aes = list(fill = "grey45", colour = "grey45")),
           fill = guide_legend(override.aes = list(size = 3.5))) +
    # panel (a) is longitude; (b) and (c) hold log10 values, labelled in km or m
    # at whole decades (longitude limits are always below -60, log10 values above -2)
    scale_x_continuous(
      breaks = function(lims) if (lims[1] < -20) pretty(lims) else seq(ceiling(lims[1]), floor(lims[2]), by = 1),
      labels = function(b) ifelse(b < -20, as.character(b), formatC(10^b, format = "fg", digits = 3, big.mark = ","))) +
    facet_wrap(~ panel, nrow = 1, scales = "free_x", strip.position = "bottom") +
    labs(x = NULL, y = "Within-month anomaly r, 24 h samples") +
    theme(strip.placement = "outside", strip.background = element_blank(), legend.position = "bottom")
  ggsave(file.path(P$figures, "fig25_geography.png"), p25, width = 9.5, height = 4.2, dpi = 300)
}
log_msg("Wrote geography_sites/groups/tests/models.csv, manuscript_numbers_25.csv",
        if (HAS_GG) " and fig25_geography.png" else "")
