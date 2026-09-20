# =============================================================================
# helpers_basemap.R - US Census cartographic boundaries, fetched and cached once.
#
# Figure 1 (step 13, the national agreement map) and Figure S1 (step 14, the
# Colorado map with its CONUS inset) both need the same state outlines. This is
# the one place that downloads them.
#
# Everything here degrades rather than fails. A map with no basemap is worse
# than a map with one, but it is much better than a pipeline that stops because
# the Census server is down or 'sf' is not installed - step 13's job is the
# analysis, and the figure is a by-product. Callers get NULL and carry on.
# =============================================================================

BASEMAP_DIR <- file.path("data/raw/basemap")

have_sf <- function() requireNamespace("sf", quietly = TRUE)

# Census cartographic boundary file, trying successive vintages. Returns an sf
# object, or stops - use cb_try() when a missing basemap should not be fatal.
cb_get <- function(kind, res, base_dir = BASEMAP_DIR) {
  if (!have_sf()) stop("Package 'sf' is needed for boundary files: install.packages(\"sf\")")
  dir.create(base_dir, recursive = TRUE, showWarnings = FALSE)
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

cb_try <- function(kind, res, base_dir = BASEMAP_DIR) {
  tryCatch(cb_get(kind, res, base_dir), error = function(e) {
    log_msg("  basemap unavailable (", conditionMessage(e), ") - drawing without boundaries")
    NULL
  })
}

NON_CONUS <- c("AK", "HI", "PR", "VI", "GU", "MP", "AS")

# State polygons for the contiguous United States, or NULL if unavailable.
us_conus_states <- function(base_dir = BASEMAP_DIR) {
  s <- cb_try("state", "5m", base_dir)
  if (is.null(s)) return(NULL)
  s[!s$STUSPS %in% NON_CONUS, ]
}

# The CONUS extent used by both figures, so Figure 1 and the Figure S1 inset
# frame the country identically.
CONUS_XLIM <- c(-125, -66.5)
CONUS_YLIM <- c(24.5, 49.5)
