# test_app.R - exercise the app's server for a range of sites before deploying.
# Run from the project root:  Rscript app/tests/test_app.R
# Every output is computed for each site and control combination below; the
# script prints one line per check and stops with an error if any failed.
suppressPackageStartupMessages(library(shiny))

app <- shinyAppDir("app")
fails <- character()
try_out <- function(label, expr) {
  ok <- tryCatch({ force(expr); TRUE }, error = function(e) {
    # validate()/need() messages are intended for empty selections, not failures
    if (inherits(e, "shiny.silent.error") || inherits(e, "validation")) TRUE else {
      message("  FAIL ", label, ": ", conditionMessage(e)); FALSE }
  })
  if (ok) message("  ok   ", label) else fails <<- c(fails, label)
}

testServer(app, {
  cases <- list(
    list(site = "08-001-0010"),                                   # COATTS, national + Colorado arms
    list(site = "08-001-0010", arm = "colorado_24h"),
    list(site = "08-059-0015"),                                   # Wheat Ridge: Colorado arm only
    list(site = "08-035-0004", arm = "colorado_3h", lag = "3"),   # Chatfield, +3 h
    list(site = "08-123-0008", arm = "colorado_3h", lag = "9"),   # Platteville, +9 h
    list(site = "06-019-0011", dur = "8"),                        # Fresno, 8 h record
    list(site = "11-001-0043", smoke = "none", seasons = c("JJA", "SON")),
    list(site = "06-019-0011", seasons = character())             # nothing selected
  )
  for (cs in cases) {
    message("case: ", paste(names(cs), unlist(lapply(cs, paste, collapse = "+")), sep = "=", collapse = ", "))
    args <- modifyList(list(smoke = "all", seasons = c("DJF", "MAM", "JJA", "SON")), cs)
    do.call(session$setInputs, args)
    for (o in c("site_card", "arm_ui", "dur_ui", "lag_ui", "tempo_boxes", "p_ts", "p_scatter", "p_anom", "p_obs",
                "tox_class_ui", "tox_param_ui", "tox_body")) {
      try_out(paste(cs$site, o), session$getOutput(o))
    }
    if (nrow(tox_site())) {
      for (cl in classes_here()) {
        session$setInputs(tox_class = cl)
        session$setInputs(tox_param = names(params_here())[1], tox_log = TRUE, tox_cmp = TRUE)
        for (o in c("tox_boxes", "t_ts", "t_season", "t_cmp", "t_table")) try_out(paste(cs$site, cl, o), session$getOutput(o))
      }
    }
  }
  try_out("map", session$getOutput("map"))
})

if (length(fails)) stop(length(fails), " check(s) failed: ", paste(fails, collapse = "; "))
message("All app checks passed.")
