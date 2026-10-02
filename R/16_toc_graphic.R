# =============================================================================
# 16_toc_graphic.R - the ES&T Table of Contents / abstract graphic
#
# ACS requires the TOC graphic at the size it will be used, "no larger than
# 3.25 inches by 1.75 inches", as TIFF at 300 dpi for colour, with sans-serif
# text "preferably at 8 pt. but no smaller than 6 pt." Both files are written
# at exactly that size, so nothing is rescaled later:
#   output/figures/toc_graphic.tiff  300 dpi, LZW  -> submit this one
#   output/figures/toc_graphic.png   600 dpi       -> for the manuscript file
#
# The graphic carries the paper's central result: day-to-day agreement between
# the TEMPO column and surface HCHO is positive at most monitors, near zero at
# some and negative at a few. That is polarity about zero, so the colour scale
# is diverging - two hues with a neutral midpoint, never a rainbow. The pair
# (#b35806 / #2166ac) passes CVD separation with a wide margin (deltaE 21.9
# under protanopia), and position on the map plus the annotated range carry the
# message independently of colour.
#
# Inputs : output/tables/national_stats_by_site.csv
#          the Census state boundaries cached by R/14_site_map.R
# Outputs: output/figures/toc_graphic.tiff, output/figures/toc_graphic.png
# =============================================================================
source("R/00_config.R")

for (pkg in c("sf")) {
  if (!requireNamespace(pkg, quietly = TRUE)) stop("Package '", pkg, "' is needed for the TOC graphic.")
}
suppressPackageStartupMessages(library(sf))

TOC_W <- 3.25   # inches, the ACS maximum
TOC_H <- 1.75

# ---- 1. the monitors the abstract quotes -------------------------------------
# Restricted to the 24 h arm. Twenty-three sites report both 24 h and 8 h
# formaldehyde, so a "one point per site" rule has to choose between two
# different correlations at the same place; taking whichever had more samples
# silently replaced 24 h values with 8 h ones and changed the range the graphic
# showed. The 24 h arm is the one the abstract summarises, so the graphic shows
# exactly that and nothing is chosen implicitly.
#
# Step 13 already restricts national_stats_by_site.csv to sites with >= 10
# matched samples and >= CFG$min_anom_pairs_site anomaly pairs, which is the
# site set the manuscript quotes; the filters below only pick the 24 h rows.
stats <- read_tbl(file.path(P$tables, "national_stats_by_site.csv")) |>
  dplyr::mutate(dplyr::across(c(lat, lon, anom_n, anom_pearson_r), as.numeric)) |>
  dplyr::filter(duration_class == "24 h",
                !is.na(anom_pearson_r), !is.na(lat), !is.na(lon), n >= 10) |>
  dplyr::filter(lon > -125, lon < -66.5, lat > 24.5, lat < 49.5)   # CONUS panel

if (anyDuplicated(stats$site)) stop("more than one row per site after filtering to 24 h")

r_min <- min(stats$anom_pearson_r); r_max <- max(stats$anom_pearson_r)
r_med <- median(stats$anom_pearson_r)
log_msg("TOC graphic: ", nrow(stats), " monitors sampling 24 h; day-to-day r from ",
        sprintf("%.2f", r_min), " to ", sprintf("%.2f", r_max),
        ", median ", sprintf("%.2f", r_med))

# The manuscript quotes these three numbers for the 24 h arm. The label below is
# generated from the data, so graphic and caption cannot drift apart; this check
# catches the other case - the DATA moving, leaving the manuscript text stale.
qk <- read_tbl(file.path(P$tables, "manuscript_numbers_13_sites.csv"))
qv <- function(k) as.numeric(qk$value[qk$key == k][1])
QUOTED <- c(min = qv("site_dd_min_24"), max = qv("site_dd_max_24"), med = qv("site_dd_median_24"))
drift <- c(abs(r_min - QUOTED[["min"]]), abs(r_max - QUOTED[["max"]]),
           abs(r_med - QUOTED[["med"]]))
if (any(drift > 0.005)) {
  warning("the 24 h day-to-day correlations no longer match the values quoted in ",
          "the manuscript (min/max/median ", sprintf("%.2f/%.2f/%.2f", r_min, r_max, r_med),
          " against ", sprintf("%.2f/%.2f/%.2f", QUOTED[["min"]], QUOTED[["max"]], QUOTED[["med"]]),
          "). Update the text before submitting.", call. = FALSE)
}

# ---- 2. basemap, from the cache R/14 already filled --------------------------
base_dir <- file.path("data/raw/basemap")
shp <- list.files(base_dir, pattern = "^cb_[0-9]+_us_state_5m\\.shp$",
                  recursive = TRUE, full.names = TRUE)
if (!length(shp)) {
  stop("No cached Census state boundaries under ", base_dir, ".\n",
       "  Run R/14_site_map.R first; it downloads and caches them.")
}
states <- sf::st_read(shp[1], quiet = TRUE)
conus <- states[!states$STUSPS %in% c("AK", "HI", "PR", "VI", "GU", "MP", "AS"), ]

# a true minus sign, so a negative limit typesets correctly at 6.5 pt
fmt_r <- function(x) sub("-", "−", sprintf("%.2f", x), fixed = TRUE)

# ---- 3. the graphic ----------------------------------------------------------
# Diverging scale centred on zero, spanning the observed range symmetrically so
# that the neutral midpoint really is r = 0 rather than the middle of the data.
lim <- max(abs(range(stats$anom_pearson_r)))

p <- ggplot() +
  geom_sf(data = conus, fill = "grey97", colour = "grey80", linewidth = 0.18) +
  geom_point(data = stats, aes(lon, lat, fill = anom_pearson_r),
             shape = 21, size = 1.5, stroke = 0.25, colour = "grey35") +
  scale_fill_gradient2(
    low = "#b35806", mid = "#f2f2f2", high = "#2166ac", midpoint = 0,
    limits = c(-lim, lim), breaks = c(-0.2, 0, 0.4, 0.8),
    name = NULL, guide = guide_colourbar(
      barwidth = unit(6, "pt"), barheight = unit(52, "pt"),
      ticks.colour = "grey30", frame.colour = "grey60", frame.linewidth = 0.2)) +
  coord_sf(xlim = c(-125, -66.5), ylim = c(24.5, 49.5), expand = FALSE, crs = 4326) +
  labs(title = "Day-to-day agreement, TEMPO vs surface HCHO",
       subtitle = sprintf("%d U.S. air toxics monitors, 24 h samples · r = %s to %s",
                          nrow(stats), fmt_r(r_min), fmt_r(r_max))) +
  theme_void(base_size = 7, base_family = "sans") +
  theme(
    # 7.5 pt bold overran the 3.25 in width and was clipped mid-word; ACS allows
    # down to 6 pt, so the title sits at 7 pt and the strings are kept short.
    plot.title    = element_text(size = 7, face = "bold", colour = "grey10",
                                 margin = margin(b = 1)),
    plot.subtitle = element_text(size = 6.2, colour = "grey30", margin = margin(b = 2)),
    legend.text   = element_text(size = 6, colour = "grey20"),
    legend.position = "right",
    legend.margin = margin(l = 2),
    plot.margin   = margin(3, 2, 2, 3),
    plot.background = element_rect(fill = "white", colour = NA))

ggsave(file.path(P$figures, "toc_graphic.tiff"), p,
       width = TOC_W, height = TOC_H, units = "in", dpi = 300,
       device = "tiff", compression = "lzw", bg = "white")
ggsave(file.path(P$figures, "toc_graphic.png"), p,
       width = TOC_W, height = TOC_H, units = "in", dpi = 600, bg = "white")

for (f in c("toc_graphic.tiff", "toc_graphic.png")) {
  path <- file.path(P$figures, f)
  log_msg("  ", f, ": ", sprintf("%.2f", file.size(path) / 1e6), " MB, ",
          TOC_W, " x ", TOC_H, " in")
}
log_msg("TOC graphic done. Submit the TIFF; the PNG is embedded in the manuscript.")
