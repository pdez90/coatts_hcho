# =============================================================================
# run_all.R - run the COATTS x TEMPO formaldehyde pipeline end to end
#   Terminal:  cd ~/HCHO && Rscript run_all.R
#   RStudio:   setwd("~/HCHO"); source("run_all.R")
# Each step caches its outputs, so re-running resumes where it stopped.
# Every run writes a log, the configuration and sessionInfo() to logs/.
#
# Order:
#   24-h arm data     01 coatts -> 02 manifest -> 03 extract -> 04 match
#   3-h arm data      06 samples -> 02 manifest -> 03 extract    (arm "threeh")
#   smoke flags       08 NOAA HMS (needs the sample files of both arms)
#   analyses          05 (24-h) -> 07 (3-h)
#   diagnostics       09 (tests of explanations; no downloads)
#   national data     10 (AQS inventory) -> 11 (samples) -> 12 (TEMPO) -> 13 (analysis)
#   national figures  17 (noise ceiling, time of day) -> 14 (site map) ->
#                     15 (observability) -> 16 (TOC graphic)
#   meteorology       18 (NOAA HRRR at every monitor; runs after 01, 06 and 11)
#                     19 (HRRR vs TEMPO vs the CDPHE sensors; after 13)
#   manuscript        20 (why agreement differs) -> 21 (Table 1) -> 22 (by season)
#                     -> 25 (by geography and terrain)
#   release           23 (the matched dataset, written to dataset/, which git tracks)
#   app               24 (data and manifest for the Shiny explorer in app/)
# =============================================================================
main <- function() {
  if (!file.exists("R/00_config.R")) stop("Set the working directory to the project root (~/HCHO).")
  stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  dir.create("logs", showWarnings = FALSE)
  log_file <- file.path("logs", paste0("run_", stamp, ".log"))
  old <- options(hcho.log_file = log_file, warn = 1, hcho.arm = "coatts")
  on.exit(options(old), add = TRUE)
  note <- function(...) cat(paste0(...), "\n", sep = "", file = log_file, append = TRUE)

  cfg_env <- new.env(); source("R/00_config.R", local = cfg_env)

  # Provenance is written now rather than after the last step: a run that stops
  # early should still leave behind the configuration and session it was using.
  jsonlite::write_json(cfg_env$CFG, file.path("logs", paste0("config_", stamp, ".json")),
                       auto_unbox = TRUE, pretty = TRUE, digits = NA)
  writeLines(capture.output(sessionInfo()), file.path("logs", paste0("sessionInfo_", stamp, ".txt")))

  three_h <- isTRUE(cfg_env$CFG$run_three_hour_arm)
  smoke   <- isTRUE(cfg_env$CFG$run_smoke_flags)
  diag    <- isTRUE(cfg_env$CFG$run_diagnostics)
  aqs     <- isTRUE(cfg_env$CFG$run_aqs_inventory)
  aqs_s   <- isTRUE(cfg_env$CFG$run_aqs_samples)
  aqs_t   <- isTRUE(cfg_env$CFG$run_aqs_tempo)

  # Step 11 stops() without AQS credentials. That has to be decided here: the
  # withCallingHandlers() below logs an error but does not catch it, so an
  # uncredentialed step 11 would abort the whole run rather than be skipped.
  has_aqs_key <- nzchar(Sys.getenv("AQS_EMAIL")) && nzchar(Sys.getenv("AQS_KEY"))
  # Colorado's 24-h record now comes from AQS as well (step 01), so credentials
  # are no longer optional for any arm. Stopping here is kinder than letting
  # step 01 fail after the TEMPO downloads have already started.
  if (!has_aqs_key) {
    stop("AQS_EMAIL and AQS_KEY are not set, and every arm now reads AQS.\n",
         "  Sign up at https://aqs.epa.gov/data/api/signup, put both in ~/.Renviron,\n",
         "  then restart R.")
  }
  map_fig   <- isTRUE(cfg_env$CFG$run_site_map)
  clear_sky <- isTRUE(cfg_env$CFG$run_clear_sky_bias)
  toc_fig   <- isTRUE(cfg_env$CFG$run_toc_graphic)
  hrrr      <- isTRUE(cfg_env$CFG$run_hrrr_met)
  met_cmp   <- isTRUE(cfg_env$CFG$run_met_comparison)
  # Steps 12-16 all consume the national arm. Each is gated on its input being
  # EITHER already on disk OR produced earlier in this same run, so that one
  # invocation of run_all.R on a fresh clone schedules the whole chain. Gating
  # only on file.exists() decided everything before any step executed, so step
  # 12 could be scheduled to build the national cells while step 13 stayed off
  # because those cells did not exist yet - and a second invocation was needed.
  aqs_t    <- aqs_t && (aqs_s ||
              file.exists(file.path("data", "processed", "aqs_hcho_samples.csv")))
  aqs_a    <- isTRUE(cfg_env$CFG$run_aqs_analysis) &&
              (aqs_t ||
               file.exists(file.path("data", "processed", "aqs_tempo_site_cells.csv.gz")))
  nat_done <- aqs_a ||
              file.exists(file.path("data", "processed", "aqs_matched_primary.csv.gz"))

  steps <- data.frame(script = character(), arm = character())
  add <- function(script, arm, when = TRUE) if (when) steps[nrow(steps) + 1, ] <<- list(script, arm)
  add("R/01_coatts.R",          "coatts")
  # Step 18 runs wherever a new set of sample windows has just appeared, as
  # step 08 does: after 01 it can see only the Colorado 24 h windows, after 06
  # the 3 h windows, after 11 the national ones. Days already downloaded are
  # skipped, so the second and third passes cost a directory listing.
  add("R/18_hrrr_met.R",        "coatts", hrrr)
  add("R/02_tempo_manifest.R",  "coatts")
  add("R/03_tempo_extract.R",   "coatts")
  add("R/04_match.R",           "coatts")
  add("R/06_threeh_samples.R",  "threeh", three_h)
  add("R/18_hrrr_met.R",        "coatts", hrrr && three_h)
  add("R/02_tempo_manifest.R",  "threeh", three_h)
  add("R/03_tempo_extract.R",   "threeh", three_h)
  add("R/08_smoke_hms.R",       "coatts", smoke)
  add("R/05_analysis.R",        "coatts")
  add("R/07_threeh_analysis.R", "threeh", three_h)
  add("R/09_diagnostics.R",     "coatts", diag)
  add("R/10_aqs_inventory.R",   "coatts", aqs)
  add("R/11_aqs_samples.R",     "coatts", aqs_s)
  add("R/18_hrrr_met.R",        "coatts", hrrr && aqs_s)
  # Step 08 runs a second time once the national samples exist, so the smoke
  # flags cover all three arms before step 13 reads them. The first run, before
  # step 05, gives the Colorado arms the flags they need; HMS downloads are
  # cached, so the repeat costs only the point-in-polygon pass.
  add("R/08_smoke_hms.R",       "coatts", smoke && aqs_s)
  add("R/12_tempo_national.R",  "coatts", aqs_t)
  add("R/13_national_analysis.R", "coatts", aqs_a)
  add("R/17_national_diagnostics.R", "coatts", diag && nat_done)   # noise ceiling and time of day at every 24 h site
  add("R/15_clear_sky_bias.R",  "coatts", clear_sky && nat_done)
  add("R/16_toc_graphic.R",     "coatts", toc_fig   && nat_done)
  add("R/19_met_comparison.R",  "coatts", met_cmp   && hrrr)
  add("R/20_agreement_diagnostics.R", "coatts", diag && nat_done && hrrr)  # duration, noise ceiling, temporal averaging, mixing depth
  add("R/21_manuscript_tables.R", "coatts", nat_done)   # Table 1 as the build renders it
  add("R/22_seasonal_analysis.R", "coatts", nat_done)   # agreement by season (Wang et al. 2022 comparison)
  # agreement by longitude, distance to the coast and terrain relief (needs step 20's site model)
  add("R/25_geography.R",       "coatts", diag && nat_done && hrrr)
  # the matched data of all three arms, with smoke flags, for release in dataset/
  add("R/23_export_dataset.R",  "coatts", nat_done && three_h && smoke)
  # the Shiny explorer's data (dataset/ plus every air toxic in the CDPHE packets)
  add("R/24_app_data.R",        "coatts", nat_done && three_h && smoke)
  # Fig. S1 is a figure only and runs last, so a missing map package cannot stop the
  # analysis steps; it needs the Colorado 24 h and 3 h samples and the AQS inventory
  # (step 11), not the national TEMPO arm
  add("R/14_site_map.R",        "coatts", map_fig && three_h &&
        (aqs_s || file.exists(file.path("output", "tables", "aqs_samples_inventory.csv"))))
  if (!nat_done)
    note("SKIPPED steps 15-17 and 20-25: the national analysis (step 13) has not been run")

  for (k in seq_len(nrow(steps))) {
    s <- steps$script[k]; arm <- steps$arm[k]
    options(hcho.arm = arm)
    message("\n==== ", s, " [", arm, "] ====")
    note("\n==== ", s, " [", arm, "] started ", format(Sys.time()), " ====")
    t0 <- Sys.time()
    withCallingHandlers(
      source(s, local = new.env()),
      warning = function(w) note("WARNING: ", conditionMessage(w)),
      error   = function(e) note("ERROR in ", s, ": ", conditionMessage(e))
    )
    note("==== ", s, " finished in ", format(round(Sys.time() - t0, 1)), " ====")
  }
  options(hcho.arm = "coatts")
  message("\nAll steps complete. Log: ", log_file,
          "\nConfiguration and sessionInfo: logs/config_", stamp, ".json, logs/sessionInfo_", stamp, ".txt")
}
main()
