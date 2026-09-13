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
  three_h <- isTRUE(cfg_env$CFG$run_three_hour_arm)
  smoke   <- isTRUE(cfg_env$CFG$run_smoke_flags)
  diag    <- isTRUE(cfg_env$CFG$run_diagnostics)
  aqs     <- isTRUE(cfg_env$CFG$run_aqs_inventory)
  aqs_s   <- isTRUE(cfg_env$CFG$run_aqs_samples)
  aqs_t   <- isTRUE(cfg_env$CFG$run_aqs_tempo)
  aqs_a   <- isTRUE(cfg_env$CFG$run_aqs_analysis) &&
             file.exists(file.path("data", "processed", "aqs_tempo_site_cells.csv.gz"))

  steps <- data.frame(script = character(), arm = character())
  add <- function(script, arm, when = TRUE) if (when) steps[nrow(steps) + 1, ] <<- list(script, arm)
  add("R/01_coatts.R",          "coatts")
  add("R/02_tempo_manifest.R",  "coatts")
  add("R/03_tempo_extract.R",   "coatts")
  add("R/04_match.R",           "coatts")
  add("R/06_threeh_samples.R",  "threeh", three_h)
  add("R/02_tempo_manifest.R",  "threeh", three_h)
  add("R/03_tempo_extract.R",   "threeh", three_h)
  add("R/08_smoke_hms.R",       "coatts", smoke)
  add("R/05_analysis.R",        "coatts")
  add("R/07_threeh_analysis.R", "threeh", three_h)
  add("R/09_diagnostics.R",     "coatts", diag)
  add("R/10_aqs_inventory.R",   "coatts", aqs)
  add("R/11_aqs_samples.R",     "coatts", aqs_s)
  add("R/12_tempo_national.R",  "coatts", aqs_t)
  add("R/13_national_analysis.R", "coatts", aqs_a)

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

  jsonlite::write_json(cfg_env$CFG, file.path("logs", paste0("config_", stamp, ".json")),
                       auto_unbox = TRUE, pretty = TRUE, digits = NA)
  writeLines(capture.output(sessionInfo()), file.path("logs", paste0("sessionInfo_", stamp, ".txt")))
  message("\nAll steps complete. Log: ", log_file)
}
main()
