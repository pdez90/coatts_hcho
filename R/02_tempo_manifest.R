# =============================================================================
# 02_tempo_manifest.R - list TEMPO HCHO L3 V04 granules for each sample day
#
# Serves both analysis arms (options(hcho.arm = "coatts" | "threeh")).
#   coatts: a sample covers 00:00-24:00 MST (07:00 UTC to 07:00 UTC next day)
#   threeh: scans between threeh_query_local_hours (MST) are listed; step 07
#           assigns them to each 3-h sample window
# A scan belongs to the window containing its midpoint. CMR is public (no login).
# Output: A$manifest (data/processed/tempo_manifest.csv for coatts)
# =============================================================================
source("R/00_config.R")
log_msg("Arm: ", ARM)

coatts <- read_tbl(A$samples) |>
  mutate(sample_date = as.Date(sample_date))
sites  <- coatts |> distinct(site, lat, lon) |> filter(!is.na(lat))
dates  <- sort(unique(coatts$sample_date[!is.na(coatts$hcho_ugm3)]))

bbox <- sprintf("%.3f,%.3f,%.3f,%.3f", min(sites$lon) - 0.1, min(sites$lat) - 0.1,
                max(sites$lon) + 0.1, max(sites$lat) + 0.1)

cmr_window <- function(d) {
  day0  <- as.POSIXct(paste(d, "00:00:00"), tz = "UTC")
  start <- day0 + (A$query_local_hours[1] - CFG$utc_offset_hours) * 3600
  end   <- day0 + (A$query_local_hours[2] - CFG$utc_offset_hours) * 3600
  req <- public_request(CFG$cmr_url) |>
    httr2::req_url_query(
      collection_concept_id = CFG$tempo_collection,
      temporal = paste(format(start, "%Y-%m-%dT%H:%M:%SZ"), format(end - 1, "%Y-%m-%dT%H:%M:%SZ"), sep = ","),
      bounding_box = bbox,
      page_size = 200,
      sort_key = "start_date"
    )
  resp  <- httr2::req_perform(req)
  items <- httr2::resp_body_json(resp, simplifyVector = FALSE)$items
  if (!length(items)) return(NULL)
  map(items, function(it) {
    u <- it$umm
    urls <- map_chr(u$RelatedUrls %||% list(), ~ .x$URL %||% NA_character_)
    types <- map_chr(u$RelatedUrls %||% list(), ~ paste(.x$Type %||% "", .x$Subtype %||% ""))
    od <- urls[str_detect(types, "OPENDAP")][1]
    if (is.na(od)) od <- file.path(CFG$opendap_base, CFG$tempo_collection, "granules", u$GranuleUR)
    tibble(sample_date = d,
           granule = u$GranuleUR,
           begin_utc = ymd_hms(u$TemporalExtent$RangeDateTime$BeginningDateTime),
           end_utc = ymd_hms(u$TemporalExtent$RangeDateTime$EndingDateTime),
           opendap_url = od,
           cmr_queried_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  }) |> list_rbind()
}

out_path <- A$manifest
# Cached rows are read as text and re-typed: fread turns ISO timestamps such as
# cmr_queried_utc into datetimes, which would not bind with newly queried rows.
done <- if (file.exists(out_path)) {
  read_tbl(out_path, colClasses = "character") |>
    transmute(sample_date = as.Date(sample_date), granule,
              begin_utc = ymd_hms(begin_utc), end_utc = ymd_hms(end_utc),
              opendap_url, cmr_queried_utc)
} else NULL
todo <- setdiff(as.character(dates), as.character(unique(done$sample_date))) |> as.Date()
log_msg(length(dates), " sample days; ", length(todo), " still to query in CMR")

new <- map(seq_along(todo), function(k) {
  if (k %% 25 == 0) log_msg("  CMR ", k, "/", length(todo))
  tryCatch(cmr_window(todo[k]), error = function(e) {
    warning("CMR failed for ", todo[k], ": ", conditionMessage(e)); NULL })
}) |> list_rbind()

if (is.null(done) && (is.null(new) || !nrow(new))) stop("CMR returned no TEMPO granules.")
manifest <- bind_rows(
  done,
  if (!is.null(new)) mutate(new, cmr_queried_utc = as.character(cmr_queried_utc))
) |>
  distinct(granule, sample_date, .keep_all = TRUE) |>
  mutate(mid_utc = begin_utc + (end_utc - begin_utc) / 2,
         day0 = as.POSIXct(paste(sample_date, "00:00:00"), tz = "UTC"),
         window_start = day0 + (A$query_local_hours[1] - CFG$utc_offset_hours) * 3600,
         window_end   = day0 + (A$query_local_hours[2] - CFG$utc_offset_hours) * 3600) |>
  # a scan straddling the window edge belongs to the window containing its midpoint
  filter(mid_utc >= window_start, mid_utc < window_end) |>
  select(-day0, -window_start, -window_end) |>
  mutate(
         mid_local = mid_utc + CFG$utc_offset_hours * 3600,
         local_hour = hour(mid_local) + minute(mid_local) / 60) |>
  filter(sample_date %in% dates) |>          # only days in the current analysis
  arrange(begin_utc)

data.table::fwrite(manifest, out_path)
log_msg("Manifest: ", nrow(manifest), " granules over ", n_distinct(manifest$sample_date),
        " sample days (", length(setdiff(dates, unique(manifest$sample_date))), " days with no granules)")
