# =============================================================================
# 11_aqs_samples.R - sample-level formaldehyde from EPA's AQS for the national arm
#
# Step 10 lists the candidate monitors; this step pulls their individual samples
# (AQS parameter 43502) for CFG$aqs_years and writes one row per sample with the
# start and end of the sampling period in UTC. AQS records the time each sample
# began, in local standard time, and also gives the GMT date and time, so the
# sampling window needs no time-zone assumption.
#
# The request, the on-disk cache and the screen (units, null qualifiers, POC
# averaging) are defined once in R/helpers_aqs.R and shared with steps 01 and 06,
# so the national arm and the Colorado record cannot be screened differently.
# Requests go state by state (one call per state and year, cached on disk).
# Needs AQS_EMAIL and AQS_KEY in ~/.Renviron; see the README.
# Outputs: data/processed/aqs_hcho_samples.csv        (one row per sample)
#          output/tables/aqs_sample_clocks.csv        (start hours by site)
#          output/tables/aqs_samples_inventory.csv    (site x duration summary)
#          data/raw/aqs/samples/sample_<state>_<year>.csv.gz  (cached responses)
# =============================================================================
source("R/00_config.R")

source("R/helpers_aqs.R")   # one definition of the AQS request and screen
invisible(aqs_credentials()) # fail here, before any work, if the keys are missing
cand_path <- file.path(P$processed, "aqs_candidate_sites.csv")
if (!file.exists(cand_path)) stop("Run R/10_aqs_inventory.R first (no ", cand_path, ")")

sample_dir <- file.path(P$raw_aqs, "samples")
dir.create(sample_dir, recursive = TRUE, showWarnings = FALSE)

cand <- read_tbl(cand_path, colClasses = list(character = c("site_id", "years"))) |>
  filter(duration_class %in% CFG$aqs_durations)
states <- sort(unique(substr(cand$site_id, 1, 2)))
log_msg(nrow(cand), " candidate monitors at ", n_distinct(cand$site_id), " sites in ",
        length(states), " states; ", length(states) * length(CFG$aqs_years), " AQS requests at most")

# ---- 1. one request per state and year, cached --------------------------------
raw <- aqs_fetch_state_years(states, CFG$aqs_years, sample_dir, CFG$aqs_refresh)
if (!nrow(raw)) stop("AQS returned no sample-level formaldehyde data.")
log_msg(nrow(raw), " raw sample rows downloaded or cached")

# ---- 2. clean --------------------------------------------------------------------
# aqs_clean_samples() types the columns, converts ppb to ug/m3, drops null-
# qualifier rows and averages duplicate POCs. Only the duration and date filters
# and the site metadata join are specific to this step.
samples <- aqs_clean_samples(raw, keep_site_ids = cand$site_id) |>
  filter(duration_class %in% CFG$aqs_durations,
         sample_date_local >= CFG$date_range[1], sample_date_local <= CFG$date_range[2]) |>
  left_join(cand |> group_by(site_id) |>
              summarise(site_name = first(site_name), state = first(state), county = first(county),
                        networks = paste(sort(unique(networks[!is.na(networks) & nzchar(networks)])), collapse = "; "),
                        .groups = "drop"), by = "site_id") |>
  arrange(site_id, start_utc)

data.table::fwrite(samples, file.path(P$processed, "aqs_hcho_samples.csv"))
log_msg("Wrote ", nrow(samples), " samples at ", n_distinct(samples$site_id), " sites to ",
        file.path(P$processed, "aqs_hcho_samples.csv"))

# ---- 2b. the sampling method, as AQS records it -----------------------------------
# Compendium Method TO-11A in three variants: a DNPH cartridge behind a potassium
# iodide ozone scrubber, a bare cartridge, and a heated ozone denuder. Classified
# by keyword and refused if a method string matches none, so a new variant cannot
# be folded silently into one of these. The shares are what the Methods quote.
method_class <- case_when(
  str_detect(samples$method, regex("denuder", ignore_case = TRUE))              ~ "heated ozone denuder",
  str_detect(samples$method, regex("\\bKI\\b|potassium iodide|O3 SCRUB",
                                   ignore_case = TRUE))                          ~ "KI ozone scrubber",
  str_detect(samples$method, regex("DNPH", ignore_case = TRUE))                 ~ "bare DNPH cartridge",
  TRUE ~ NA_character_)
if (anyNA(method_class)) {
  stop("Unclassified AQS method string(s): ",
       paste(unique(samples$method[is.na(method_class)]), collapse = "; "))
}
methods_tbl <- tibble(method_class = method_class, method = samples$method) |>
  count(method_class, method, name = "samples") |>
  mutate(pct = round(100 * samples / sum(samples), 1)) |>
  arrange(desc(samples))
data.table::fwrite(methods_tbl, file.path(P$tables, "aqs_sample_methods.csv"))
print(methods_tbl)
n_total <- nrow(samples)          # outside the pipe: inside it, `samples` is the count column
pct_class <- methods_tbl |>
  group_by(method_class) |>
  summarise(pct = 100 * sum(samples) / n_total, .groups = "drop")
pc <- function(k) {
  v <- pct_class$pct[match(k, pct_class$method_class)]
  if (length(v) != 1 || !is.finite(v)) stop("No share for method class '", k, "'")
  sprintf("%.0f", v)
}
data.table::fwrite(
  tibble(key = c("pct_method_ki", "pct_method_bare", "pct_method_denuder"),
         value = c(pc("KI ozone scrubber"), pc("bare DNPH cartridge"), pc("heated ozone denuder")),
         source = "R/11_aqs_samples.R"),
  file.path(P$tables, "manuscript_numbers_11.csv"))

# ---- 3. what clock does each site sample on? -------------------------------------
clocks <- samples |>
  count(site_id, site_name, state, duration_class, start_hour_local, name = "samples") |>
  arrange(site_id, duration_class, start_hour_local)
data.table::fwrite(clocks, file.path(P$tables, "aqs_sample_clocks.csv"))

inv <- samples |>
  group_by(duration_class, site_id, site_name, state, networks, lat, lon) |>
  summarise(samples = n(), days = n_distinct(sample_date_local),
            first = min(sample_date_local), last = max(sample_date_local),
            start_hours = paste(sort(unique(round(start_hour_local))), collapse = ","),
            median_ugm3 = round(median(hcho_ugm3), 2), .groups = "drop") |>
  arrange(duration_class, desc(samples))
data.table::fwrite(inv, file.path(P$tables, "aqs_samples_inventory.csv"))

for (dc in sort(unique(samples$duration_class))) {
  x <- filter(samples, duration_class == dc)
  hrs <- sort(unique(round(x$start_hour_local)))
  log_msg(dc, ": ", n_distinct(x$site_id), " sites, ", nrow(x), " samples, ",
          n_distinct(x$sample_date_local), " distinct dates; start hours ",
          paste(hrs, collapse = ", "))
}
print(inv |> group_by(duration_class) |> slice_head(n = 5) |>
        select(duration_class, site_id, site_name, state, samples, days, start_hours))

# ---- 4. what the TEMPO extraction will cost --------------------------------------
# Sites are grouped into boxes; step 12 makes one OPeNDAP request per box and
# scan. The estimate covers what step 12 is CONFIGURED to extract, so it filters
# to CFG$aqs_arm_durations the way step 12 does. Without that filter the figure
# would be an upper bound across every duration in CFG$aqs_durations, which
# includes "1 h". Today that is the same number - AQS holds no 1 h formaldehyde
# at all, the PAMS hourly option being unused - so this changes nothing now and
# keeps the estimate honest if a 1 h site ever appears.
#
# It is an estimate either way: step 12 drops sites without coordinates or
# without granules, and counts the scans it actually retrieves rather than
# aqs_scans_per_day_guess. What the extraction actually contained is counted by
# step 13 from the cells file (manuscript_numbers_13_extraction.csv).
clus <- samples |>
  filter(duration_class %in% CFG$aqs_arm_durations) |>
  distinct(site_id, lat, lon, duration_class, sample_date_local) |>
  mutate(cluster = cluster_of(lat, lon))   # the rule step 12 uses (R/00_config.R)
cost <- clus |>
  group_by(cluster) |>
  summarise(sites = n_distinct(site_id), dates = n_distinct(sample_date_local), .groups = "drop")
log_msg(nrow(cost), " site clusters (", CFG$aqs_cluster_deg_lat, " deg lat x ",
        CFG$aqs_cluster_deg_lon, " deg lon); ", sum(cost$dates), " cluster-days; roughly ",
        format(sum(cost$dates) * CFG$aqs_scans_per_day_guess, big.mark = ","),
        " OPeNDAP requests for step 12")
data.table::fwrite(cost, file.path(P$tables, "aqs_cluster_cost.csv"))
print(arrange(cost, desc(dates)) |> head(10))
log_msg("AQS sample pull done.")
