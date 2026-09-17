# =============================================================================
# helpers_screen.R - the TEMPO cell screen, defined once.
#
# Steps 04, 07 and 13 each carried their own copy of this screen, and the copies
# drifted: when the missing-value semantics were corrected in step 04, the 3 h
# and national arms kept admitting a cell whose ancillary QC value was absent,
# because coalesce(x, 0) substitutes the most permissive value each criterion
# allows. Three implementations of one rule is one too many to keep in step, so
# there is now one.
#
# Two different things look like a missing QC value and they are not alike:
#
#   absent from the collection  - the variable is not in the extraction at all.
#       It cannot be screened on, so the criterion is dropped, loudly, because
#       the resulting screen is weaker than the methods describe.
#   missing for this cell       - the variable exists but has no value here.
#       That is a gap in the ancillary data, not evidence of good quality, so
#       the cell fails.
#
# A third case used to be silently folded into the first: a variable that IS in
# the extraction but came back entirely empty. That is a broken extraction, and
# treating it as "the collection doesn't provide this" would quietly disable a
# criterion for every cell. It now stops the run.
# =============================================================================

HCHO_QC_VARS <- c("main_data_quality_flag", "eff_cloud_fraction",
                  "snow_ice_fraction", "solar_zenith_angle")

# Decide which criteria are available, create placeholders for anything the
# extraction does not carry, and report the per-cell gaps. Returns the cells and
# the names of the criteria that cannot be screened on.
hcho_prepare_cells <- function(cells) {
  present <- names(cells)                       # BEFORE any placeholder exists
  absent  <- setdiff(HCHO_QC_VARS, present)

  for (v in setdiff(c(HCHO_QC_VARS, "pbl_height", "vertical_column_uncertainty",
                      "surface_pressure"), present)) {
    cells[[v]] <- NA_real_
  }

  if (length(absent)) {
    warning("QC variable(s) absent from this collection, NOT screened on: ",
            paste(absent, collapse = ", "), call. = FALSE)
    log_msg("*** The screen is WEAKER than documented: ",
            paste(absent, collapse = ", "),
            " is not in the extraction at all. Report this with any result.")
  }

  # present in the file but empty everywhere: a failed extraction, not an
  # absent variable, and it must not be mistaken for one
  empty <- setdiff(HCHO_QC_VARS, absent)
  empty <- empty[vapply(empty, function(v) all(is.na(cells[[v]])), logical(1))]
  if (length(empty)) {
    stop("QC variable(s) present in the extraction but entirely missing: ",
         paste(empty, collapse = ", "),
         ". That is a broken extraction, not a collection without the variable. ",
         "Re-run step 03 rather than screening without the criterion.")
  }

  for (v in setdiff(HCHO_QC_VARS, absent)) {
    n_gap <- sum(is.na(cells[[v]]) & !is.na(cells$vertical_column))
    if (n_gap) log_msg("  ", v, ": ", n_gap,
                       " cell(s) have a column but no QC value -> failed")
  }

  list(cells = cells, absent = absent)
}

# A cell passes only if every criterion the extraction supports is present and
# within its limit. Criteria in `absent` are skipped, having been reported by
# hcho_prepare_cells().
hcho_screen_pass <- function(d, max_ecf, absent = character(0)) {
  ok <- function(v, lim) {
    if (v %in% absent) return(rep(TRUE, nrow(d)))
    !is.na(d[[v]]) & d[[v]] <= lim
  }
  !is.na(d$vertical_column) &
    ok("main_data_quality_flag", CFG$qc_max_quality_flag) &
    ok("eff_cloud_fraction",     max_ecf) &
    ok("solar_zenith_angle",     CFG$qc_max_sza) &
    ok("snow_ice_fraction",      CFG$qc_max_snow_ice)
}

# A scan counts when enough of its block cells pass.
hcho_scan_valid <- function(n_pass, n_cells) {
  n_pass >= pmax(1, ceiling(CFG$qc_min_cell_fraction * n_cells))
}
