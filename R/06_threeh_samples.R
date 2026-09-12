# =============================================================================
# 06_threeh_samples.R - 3-hour formaldehyde samples at ozone-precursor sites
#
# Littleton (CHCO) and Platteville (PVCO) belong to CDPHE's COOPs network. Their
# formaldehyde samples are 3-h (duration 10,800 s in the 2025 AQDx packets;
# CDPHE confirmed the 2024 wide packets hold the same 3-h samples), stamped 09:00.
# This step downloads those packets, keeps ambient 3-h formaldehyde (QC samples
# and rows with AQS Null Data Qualifiers removed, as in step 01) and writes one
# row per site x sample stamp. The 09:00 stamp is the END of sampling: EPA's AQS
# holds these samples with a start time of 06:00 MST (step 10).
# The TEMPO scans are then
# listed and extracted by steps 02 and 03 with options(hcho.arm = "threeh"),
# and matched in step 07.
# Output: data/processed/threeh_hcho.csv
# =============================================================================
source("R/00_config.R")

# ---- 1. find and download packets -------------------------------------------
log_msg("Reading repository page: ", CFG$coatts_repo_url)
page  <- public_request(CFG$coatts_repo_url) |> httr2::req_perform() |> httr2::resp_body_html()
a     <- xml2::xml_find_all(page, "//a[@href]")
href  <- xml2::url_absolute(xml2::xml_attr(a, "href"), CFG$coatts_repo_url)
fname <- str_match(href, "file=([^&]+\\.xlsx)")[, 2]
fname <- vapply(fname, function(x) if (is.na(x)) NA_character_ else utils::URLdecode(x), character(1), USE.NAMES = FALSE)
site_pat <- paste(CFG$threeh_sites, collapse = "|")

files <- tibble(file = fname, url = href) |>
  filter(!is.na(file)) |>
  mutate(layout = case_when(str_detect(file, sprintf("^(%s)_AQDxLite", site_pat)) ~ "aqdx",
                            str_detect(file, sprintf("^\\d{4}_AnnualFile_(%s)", site_pat)) ~ "wide",
                            TRUE ~ NA_character_),
         site = coalesce(str_match(file, sprintf("^(%s)_AQDxLite", site_pat))[, 2],
                         str_match(file, sprintf("^\\d{4}_AnnualFile_(%s)", site_pat))[, 2])) |>
  filter(!is.na(layout), layout == "aqdx" | CFG$threeh_include_2024) |>
  distinct(file, .keep_all = TRUE)
if (!nrow(files)) stop("No packets found for ", paste(CFG$threeh_sites, collapse = ", "))
log_msg("Packets: ", paste(files$file, collapse = ", "))

is_xlsx <- function(path) file.exists(path) && file.size(path) > 4 &&
  identical(readBin(path, "raw", n = 2), charToRaw("PK"))
files$path <- file.path(P$raw_coatts, files$file)
for (i in seq_len(nrow(files))) {
  if (is_xlsx(files$path[i]) && !CFG$coatts_refresh) next
  log_msg("Downloading ", files$file[i])
  tmp <- tempfile(fileext = ".xlsx")
  resp <- public_request(files$url[i]) |> httr2::req_error(is_error = function(r) FALSE) |>
    httr2::req_perform(path = tmp)
  if (httr2::resp_status(resp) >= 400 || !is_xlsx(tmp)) {
    stop("Download failed for ", files$file[i], " (HTTP ", httr2::resp_status(resp), ").")
  }
  file.copy(tmp, files$path[i], overwrite = TRUE); unlink(tmp)
  Sys.sleep(1)
}
files <- mutate(files, bytes = file.size(path), md5 = unname(tools::md5sum(path)),
                file_mtime = format(file.mtime(path), "%Y-%m-%d %H:%M:%S %Z"))
data.table::fwrite(select(files, site, layout, file, url, bytes, md5, file_mtime),
                   file.path(P$raw_coatts, "download_manifest_threeh.csv"))

# ---- 2. parse ------------------------------------------------------------------
parse_threeh_aqdx <- function(path) {
  if (!"Carbonyls_data" %in% readxl::excel_sheets(path)) return(NULL)
  d <- readxl::read_excel(path, sheet = "Carbonyls_data", col_types = "text") |>
    mutate(stamp_local = excel_or_text_datetime(datetime),
           duration = suppressWarnings(as.numeric(duration)),
           value = suppressWarnings(as.numeric(parameter_value)),
           lat = suppressWarnings(as.numeric(lat)),
           lon = suppressWarnings(as.numeric(lon)))
  hc_all <- filter(d, str_detect(parameter_name, regex("^formaldehyde$", ignore_case = TRUE)))
  hc <- hc_all |> filter(!is.na(duration), abs(duration - CFG$threeh_duration_s) < 1)
  if (nrow(hc_all) > nrow(hc)) {
    log_msg("  ", basename(path), ": ", nrow(hc_all) - nrow(hc), " formaldehyde rows with other durations skipped")
  }
  if (!nrow(hc)) return(NULL)
  hc |>
    drop_qc_rows(qc = qc_code, flags = qualifier_codes, file = basename(path),
                 null_codes = null_qualifiers_of(path)) |>
    transmute(stamp_local, lat, lon, value, duration_s = duration,
              qc_code = suppressWarnings(as.integer(qc_code)), flags = qualifier_codes)
}

parse_threeh_wide <- function(path) {
  sh <- readxl::excel_sheets(path)
  s <- sh[str_detect(sh, regex("^Carbonyls Field Samples$", ignore_case = TRUE))]
  if (!length(s)) return(NULL)
  d <- readxl::read_excel(path, sheet = s[1], col_types = "text")
  vcol <- grep("^Formaldehyde_ug", names(d), value = TRUE)[1]
  fcol <- grep("^Formaldehyde_flags", names(d), value = TRUE)[1]
  tcol <- grep("^Datetime", names(d), value = TRUE)[1]
  if (is.na(vcol) || is.na(tcol)) return(NULL)
  tibble(stamp_local = excel_or_text_datetime(d[[tcol]]),
         lat = NA_real_, lon = NA_real_,
         value = suppressWarnings(as.numeric(d[[vcol]])),
         duration_s = NA_real_,             # not in the 2024 layout; 3-h per CDPHE
         qc_code = NA_integer_,             # field-sample sheet (QC samples are on a separate sheet)
         flags = if (!is.na(fcol)) d[[fcol]] else NA_character_) |>
    drop_qc_rows(qc = qc_code, flags = flags, file = basename(path),
                 null_codes = null_qualifiers_of(path))
}

parsed <- pmap(select(files, file, site, layout, path), function(file, site, layout, path) {
  res <- tryCatch(if (layout == "aqdx") parse_threeh_aqdx(path) else parse_threeh_wide(path),
                  error = function(e) { warning(file, ": ", conditionMessage(e)); NULL })
  if (is.null(res) || !nrow(res)) { log_msg("  no 3-h formaldehyde in ", file); return(NULL) }
  log_msg("  ", file, ": ", nrow(res), " 3-h formaldehyde rows")
  mutate(res, site = site, source_file = file)
}) |> list_rbind()
if (is.null(parsed) || !nrow(parsed)) stop("No 3-h formaldehyde rows parsed.")

site_names <- c(CHCO = "Littleton", PVCO = "Platteville")
coords <- parsed |> filter(!is.na(lat), !is.na(lon)) |>
  group_by(site) |> summarise(lat = median(lat), lon = median(lon), .groups = "drop")

# Stamps other than the usual time of day (e.g. a 23:59 entry) are kept but flagged
modal_time <- parsed |> count(t = format(stamp_local, "%H:%M")) |> slice_max(n, n = 1, with_ties = FALSE) |> pull(t)

mean_or_na <- function(x) if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
threeh <- parsed |>
  filter(!is.na(stamp_local),
         as.Date(stamp_local) >= CFG$date_range[1], as.Date(stamp_local) <= CFG$date_range[2]) |>
  group_by(site, stamp_local) |>
  summarise(n_rows = n(),
            hcho_ugm3 = mean_or_na(value),
            below_mdl = any(has_flag(flags, "MD")),
            qc_codes = paste(sort(unique(na.omit(qc_code))), collapse = ";"),
            flags = { f <- unique(unlist(str_split(na.omit(flags), "[ ,;]+"))); paste(sort(f[nzchar(f)]), collapse = " ") },
            source_file = paste(unique(source_file), collapse = ";"),
            .groups = "drop") |>
  left_join(coords, by = "site") |>
  mutate(site_name = unname(site_names[site]),
         program = "COOPs (3-h)",
         sample_date = as.Date(stamp_local),
         stamp_time_unusual = format(stamp_local, "%H:%M") != modal_time,
         stamp_local = format(stamp_local, "%Y-%m-%d %H:%M"),
         hcho_molec_cm3 = ugm3_to_molec_cm3(hcho_ugm3),
         season = season_of(sample_date),
         year = year(sample_date)) |>
  relocate(site, site_name, program, lat, lon, sample_date, stamp_local) |>
  arrange(site, stamp_local)

if (any(is.na(threeh$lat))) warning("Missing coordinates for: ", paste(unique(threeh$site[is.na(threeh$lat)]), collapse = ", "))
if (any(threeh$stamp_time_unusual)) {
  log_msg("NOTE: ", sum(threeh$stamp_time_unusual), " samples stamped at a time other than ", modal_time,
          " (kept here, flagged stamp_time_unusual; ",
          if (CFG$threeh_exclude_unusual_stamps) "left out of" else "included in", " the TEMPO matching): ",
          paste(threeh$site[threeh$stamp_time_unusual], threeh$stamp_local[threeh$stamp_time_unusual], collapse = "; "))
}

data.table::fwrite(threeh, A_threeh <- arm_paths("threeh")$samples)
inv <- threeh |>
  group_by(site, site_name, year) |>
  summarise(samples = n(), with_value = sum(!is.na(hcho_ugm3)),
            first = min(sample_date), last = max(sample_date),
            usual_stamp = modal_time, unusual_stamps = sum(stamp_time_unusual),
            median_ugm3 = round(median(hcho_ugm3, na.rm = TRUE), 2), .groups = "drop")
data.table::fwrite(inv, file.path(P$tables, "threeh_inventory.csv"))
print(inv)
log_msg("Wrote ", nrow(threeh), " 3-h samples to ", A_threeh)
