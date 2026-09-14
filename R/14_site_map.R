# =============================================================================
# 14_site_map.R - Figure 1: the Colorado case-study sites, with a CONUS inset
#
# Main panel: the seven COATTS 24-h sites and the two COOPs 3-h sites over
# shaded terrain and county outlines. Inset: the 123 national AQS sites by
# sample duration, so the reader can place the case study inside the network.
#
# Inputs : data/processed/coatts_hcho.csv, threeh_hcho.csv
#          output/tables/aqs_samples_inventory.csv
#          a DEM from AWS terrain tiles (elevatr) and Census cartographic
#          boundary files - both cached under data/raw/basemap/
# Output : output/figures/fig0_site_map.png
#
# Extra packages: elevatr and terra (terrain). Install once with
#   install.packages(c("elevatr", "terra"))
# =============================================================================
source("R/00_config.R")

for (pkg in c("elevatr", "terra", "sf")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("Package '", pkg, "' is needed for the site map.\n",
         '  install.packages(c("elevatr", "terra", "sf"))')
  }
}
suppressPackageStartupMessages(library(sf))

base_dir <- file.path("data/raw/basemap")
dir.create(base_dir, recursive = TRUE, showWarnings = FALSE)

# Colorado panel extent, and where the inset sits (empty NW corner of the state)
co_xlim <- c(-109.30, -101.95)
co_ylim <- c(36.90, 41.10)
ins_x   <- c(-109.22, -106.55)
ins_y   <- c(39.80, 41.02)

# ---- 1. sites ---------------------------------------------------------------
# names as used in the manuscript (AQS names where they differ from the packets)
# dx/dy offset each label from its point; hjust anchors it. The Front Range
# sites are close together (La Salle and Platteville ~10 km apart, Commerce City
# and Wheat Ridge ~15 km), so those two pairs are separated vertically as well.
co_sites <- tibble::tribble(
  ~site,  ~label,              ~arm,              ~lat,      ~lon,       ~hjust, ~dx,   ~dy,
  "GPCO", "Grand Junction",    "COATTS (24 h)",   39.064289, -108.56155,  0,      0.13,  0.00,
  "LSCO", "La Salle",          "COATTS (24 h)",   40.261400, -104.70645,  0,      0.13,  0.05,
  "ADCO", "Commerce City",     "COATTS (24 h)",   39.828100, -104.93647,  0,      0.13,  0.07,
  "JFCO", "Wheat Ridge",       "COATTS (24 h)",   39.781069, -105.107621, 1,     -0.13, -0.07,
  "COCO", "Colorado Springs",  "COATTS (24 h)",   38.848014, -104.828564, 0,      0.13,  0.00,
  "POCO", "Pueblo",            "COATTS (24 h)",   38.236232, -104.58138,  0,      0.13,  0.00,
  "CNCO", "Ca\u00f1on City",      "COATTS (24 h)",   38.469492, -105.208334, 1,     -0.13,  0.00,
  "CHCO", "Chatfield State Park", "COOPs (3 h)",  39.534488, -105.070358, 1,     -0.13,  0.00,
  "PVCO", "Platteville",       "COOPs (3 h)",     40.209387, -104.82405,  1,     -0.13, -0.05
) |>
  dplyr::mutate(label2 = paste0(label, " (", site, ")"),
                arm = factor(arm, levels = c("COATTS (24 h)", "COOPs (3 h)")))

# cross-check the coordinates against the data actually analysed
chk <- dplyr::bind_rows(
  read_tbl(file.path(P$processed, "coatts_hcho.csv")) |>
    dplyr::distinct(site, lat, lon),
  read_tbl(file.path(P$processed, "threeh_hcho.csv")) |>
    dplyr::distinct(site, lat, lon)
) |> dplyr::distinct(site, .keep_all = TRUE)
cmp <- dplyr::inner_join(co_sites, chk, by = "site", suffix = c("", "_data"))
off <- with(cmp, max(abs(lat - lat_data), abs(lon - lon_data)))
if (nrow(cmp) != nrow(co_sites) || off > 1e-4) {
  stop("Site coordinates in this script disagree with the processed data (max ",
       signif(off, 3), " deg over ", nrow(cmp), " of ", nrow(co_sites), " sites).")
}
log_msg("Site coordinates agree with the processed data (", nrow(cmp), " sites)")

nat <- read_tbl(file.path(P$tables, "aqs_samples_inventory.csv")) |>
  dplyr::distinct(site_id, duration_class, lat, lon) |>
  dplyr::mutate(duration_class = factor(duration_class, levels = c("24 h", "8 h", "3 h")))
log_msg(nrow(nat), " national site-duration rows at ", dplyr::n_distinct(nat$site_id), " sites for the inset")

# ---- 2. basemap: Census cartographic boundaries, cached ---------------------
cb_get <- function(kind, res) {
  for (yr in c(2023L, 2022L, 2021L)) {
    f <- file.path(base_dir, sprintf("cb_%d_us_%s_%s.zip", yr, kind, res))
    if (!file.exists(f) || file.size(f) < 1000) {
      url <- sprintf("https://www2.census.gov/geo/tiger/GENZ%d/shp/cb_%d_us_%s_%s.zip",
                     yr, yr, kind, res)
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
  stop("Could not obtain the Census ", kind, " boundary file.")
}

counties <- cb_get("county", "500k")
states   <- cb_get("state", "5m")
co_fips  <- "08"
co_counties <- counties[counties$STATEFP == co_fips, ]
co_state    <- states[states$STATEFP == co_fips, ]
conus <- states[!states$STUSPS %in% c("AK", "HI", "PR", "VI", "GU", "MP", "AS"), ]
log_msg("Basemap: ", nrow(co_counties), " Colorado counties, ", nrow(conus), " CONUS states")

# ---- 3. terrain -------------------------------------------------------------
dem_file <- file.path(base_dir, "colorado_dem_z7.tif")
if (!file.exists(dem_file)) {
  log_msg("Downloading the Colorado DEM (AWS terrain tiles, zoom 7) ...")
  bb <- sf::st_as_sf(data.frame(x = co_xlim, y = co_ylim), coords = c("x", "y"), crs = 4326)
  elev <- elevatr::get_elev_raster(locations = bb, z = 7, clip = "bbox", verbose = FALSE)
  terra::writeRaster(terra::rast(elev), dem_file, overwrite = TRUE)
}
dem <- terra::rast(dem_file)
names(dem) <- "elev"
# keep the raster light enough for a figure
while (terra::ncell(dem) > 6e5) dem <- terra::aggregate(dem, fact = 2, fun = "mean")
log_msg("DEM: ", paste(dim(dem)[1:2], collapse = " x "), " cells")

dem_df <- as.data.frame(dem, xy = TRUE, na.rm = TRUE)
names(dem_df) <- c("x", "y", "elev")

hill_df <- tryCatch({
  slope  <- terra::terrain(dem, "slope",  unit = "radians")
  aspect <- terra::terrain(dem, "aspect", unit = "radians")
  hs <- terra::shade(slope, aspect, angle = 40, direction = 315)
  d <- as.data.frame(hs, xy = TRUE, na.rm = TRUE)
  names(d) <- c("x", "y", "shade")
  d
}, error = function(e) { log_msg("  hillshade unavailable: ", conditionMessage(e)); NULL })

# ---- 4. the inset -----------------------------------------------------------
p_inset <- ggplot() +
  geom_sf(data = conus, fill = "grey97", colour = "grey70", linewidth = 0.15) +
  geom_point(data = nat, aes(lon, lat, colour = duration_class),
             size = 0.55, alpha = 0.85) +
  geom_sf(data = co_state, fill = NA, colour = "grey15", linewidth = 0.45) +
  scale_colour_manual(values = c("24 h" = "#1f78b4", "8 h" = "#e6550d", "3 h" = "#33a02c"),
                      name = NULL, drop = FALSE) +
  coord_sf(xlim = c(-125, -66.5), ylim = c(24.5, 49.5), expand = FALSE, crs = 4326) +
  guides(colour = guide_legend(override.aes = list(size = 1.6))) +
  theme_void(base_size = 7) +
  theme(legend.position = "bottom",
        legend.key.height = unit(6, "pt"),
        legend.margin = margin(t = -3, b = 0),
        legend.text = element_text(size = 6),
        plot.background = element_rect(fill = "white", colour = "grey40", linewidth = 0.3),
        plot.margin = margin(3, 3, 1, 3))

# ---- 5. the main panel ------------------------------------------------------
# Elevation carries the only fill scale; the hillshade is drawn over it as a
# semi-transparent dark layer whose opacity is the inverse of illumination.
# (Using alpha rather than a second fill scale avoids a ggnewscale dependency.)
p <- ggplot() +
  geom_raster(data = dem_df, aes(x, y, fill = elev)) +
  scale_fill_gradientn(colours = c("#4d7f52", "#9fb87a", "#d9cfa3", "#b99a78", "#8c6f5e", "#f2f2f2"),
                       name = "Elevation (m)", na.value = NA)
if (!is.null(hill_df)) {
  p <- p +
    geom_raster(data = hill_df, aes(x, y, alpha = shade), fill = "grey5") +
    scale_alpha_continuous(range = c(0.55, 0), guide = "none")
}
p <- p +
  geom_sf(data = co_counties, fill = NA, colour = "white", linewidth = 0.22, alpha = 0.7) +
  geom_sf(data = co_state, fill = NA, colour = "grey10", linewidth = 0.5) +
  geom_point(data = co_sites, aes(lon, lat, shape = arm),
             size = 2.6, colour = "black", fill = "#d7191c", stroke = 0.6) +
  geom_text(data = co_sites, aes(lon + dx, lat + dy, label = label2, hjust = hjust),
            size = 2.4, colour = "grey10", fontface = "bold") +
  scale_shape_manual(values = c("COATTS (24 h)" = 21, "COOPs (3 h)" = 24), name = NULL) +
  annotation_custom(ggplotGrob(p_inset),
                    xmin = ins_x[1], xmax = ins_x[2], ymin = ins_y[1], ymax = ins_y[2]) +
  coord_sf(xlim = co_xlim, ylim = co_ylim, expand = FALSE, crs = 4326) +
  labs(x = NULL, y = NULL) +
  guides(shape = guide_legend(order = 1, override.aes = list(size = 2.6)),
         fill = guide_colourbar(order = 2, barheight = unit(28, "pt"), barwidth = unit(7, "pt"))) +
  theme_bw(base_size = 9) +
  theme(panel.grid = element_line(colour = alpha("grey50", 0.25), linewidth = 0.2),
        legend.position = "right",
        legend.spacing.y = unit(4, "pt"),
        legend.title = element_text(size = 7.5),
        legend.text = element_text(size = 7))

ggsave(file.path(P$figures, "fig0_site_map.png"), p, width = 7.6, height = 5.4, dpi = 300)
log_msg("  figure: fig0_site_map.png")
log_msg("Site map done.")
