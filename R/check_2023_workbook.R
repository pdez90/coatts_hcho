# =============================================================================
# check_2023_workbook.R - does CDPHE's 2023 workbook agree with AQS?
#
# The 2023 three-hour samples enter the analysis through AQS (step 06), because
# AQS carries the sample start time and the workbook carries only the 09:00 end
# stamp. The workbook is therefore a cross-check rather than a data source, and
# it answers two questions that matter for splicing 2023 onto 2024-2025:
#
#   1. Do the two sources report the same concentrations for the same days?
#   2. Are the 2023 values on the same standard-conditions basis (25 C, 1 atm)
#      as the packets? If they were at local conditions instead, the ratio would
#      sit near 0.88 at Platteville's elevation rather than near 1.
#
# A ONE-OFF DIAGNOSTIC: reads only, writes only a table, changes no result.
# Usage: cd ~/HCHO && Rscript R/check_2023_workbook.R
# =============================================================================
source("R/00_config.R")

if (!requireNamespace("readxl", quietly = TRUE)) stop("readxl is needed for the workbook check.")

# ---- 1. locate the workbook --------------------------------------------------
cand <- c(list.files(".", pattern = "Precursor Summary_Data-2023.*\\.xlsx$",
                     full.names = TRUE, ignore.case = TRUE),
          list.files(P$raw_coatts, pattern = "Precursor Summary_Data-2023.*\\.xlsx$",
                     full.names = TRUE, ignore.case = TRUE))
if (!length(cand)) {
  stop("The 2023 precursor workbook was not found in the project root or ", P$raw_coatts, ".\n",
       "  Download 'Raw CDPHE Precursor Summary_Data-2023.xlsx' from\n",
       "  https://www.colorado.gov/airquality/air_toxics_repo.aspx")
}
book <- cand[1]
log_msg("Workbook: ", basename(book))

# ---- 2. read the carbonyl sheets ---------------------------------------------
# Long format, one row per analyte: Site | Lab sample ID | Sample/Prep/Analysis
# Date | Analyte | CAS | Result | Qualifier | Detection Limit | Units, under a
# title block, so the header row is found rather than assumed.
read_carbonyl <- function(sheet) {
  raw <- readxl::read_excel(book, sheet = sheet, col_names = FALSE, col_types = "text")
  hdr <- which(apply(raw, 1, function(r) any(tolower(trimws(r)) %in% "analyte", na.rm = TRUE)))[1]
  if (is.na(hdr)) { log_msg("  ", sheet, ": no header row found"); return(NULL) }
  d <- readxl::read_excel(book, sheet = sheet, skip = hdr - 1, col_types = "text")
  names(d) <- make.unique(tolower(trimws(names(d))))
  sitecol <- names(d)[1]; datecol <- names(d)[3]
  d |>
    transmute(site_raw = .data[[sitecol]],
              stamp = excel_or_text_datetime(.data[[datecol]]),
              analyte = analyte,
              result = suppressWarnings(as.numeric(result)),
              qualifier = if ("qualifier" %in% names(d)) qualifier else NA_character_,
              units = if ("units" %in% names(d)) units else NA_character_) |>
    filter(!is.na(stamp), str_detect(coalesce(analyte, ""), regex("^formaldehyde$", ignore_case = TRUE)))
}

sheets <- readxl::excel_sheets(book)
carb <- sheets[str_detect(sheets, regex("^carbonyl", ignore_case = TRUE))]
log_msg("Carbonyl sheets: ", paste(carb, collapse = ", "))

wb <- map(carb, function(s) { d <- read_carbonyl(s); if (is.null(d)) NULL else mutate(d, sheet = s) }) |>
  list_rbind()
if (is.null(wb) || !nrow(wb)) stop("No formaldehyde rows found in the workbook's carbonyl sheets.")

# "PVCO" is an ambient sample, "PVCO D1" the primary of a duplicate pair, "D2"
# the duplicate and "FB" a field blank. Blanks are dropped; a duplicate pair is
# averaged, as duplicate ambient samples are elsewhere in this analysis.
wb <- wb |>
  mutate(code = str_extract(str_trim(site_raw), "^[A-Z]{4}"),
         kind = str_trim(str_replace(str_trim(site_raw), "^[A-Z]{4}", "")),
         sample_date = as.Date(stamp)) |>
  filter(!str_detect(kind, regex("FB", ignore_case = TRUE)))

wb_day <- wb |>
  group_by(code, sample_date) |>
  summarise(workbook_ugm3 = mean(result, na.rm = TRUE), rows = n(),
            units = paste(sort(unique(na.omit(units))), collapse = "; "), .groups = "drop")
log_msg(nrow(wb_day), " ambient workbook sample days; units: ",
        paste(sort(unique(wb_day$units)), collapse = ", "))
print(count(wb_day, code, name = "sample_days"))

# ---- 3. compare with what the pipeline used ----------------------------------
sp <- arm_paths("threeh")$samples
if (!file.exists(sp)) stop("Run R/06_threeh_samples.R first (no ", sp, ")")
used <- read_tbl(sp) |>
  mutate(sample_date = as.Date(sample_date)) |>
  filter(year(sample_date) == CFG$threeh_aqs_year) |>
  select(code = site, sample_date, pipeline_ugm3 = hcho_ugm3, source_file)

cmp <- inner_join(wb_day, used, by = c("code", "sample_date")) |>
  mutate(ratio = workbook_ugm3 / pipeline_ugm3)
log_msg("\n", nrow(cmp), " days present in both the workbook and the analysis file")
if (!nrow(cmp)) {
  log_msg("  Nothing overlaps. The pipeline keeps only ", format(CFG$date_range[1]),
          " onwards, which is when TEMPO granules begin; the workbook covers the whole year.")
} else {
  log_msg(sprintf("  workbook / pipeline ratio: median %.4f, min %.4f, max %.4f",
                  median(cmp$ratio, na.rm = TRUE), min(cmp$ratio, na.rm = TRUE), max(cmp$ratio, na.rm = TRUE)))
  log_msg("  A ratio near 1 means the two sources agree and 2023 is on the same")
  log_msg("  standard-conditions basis as the packets. Near 0.88 would mean the")
  log_msg("  workbook reports at local conditions and the splice would be wrong.")
  print(head(arrange(cmp, desc(abs(ratio - 1))), 8))
  data.table::fwrite(cmp, file.path(P$tables, "check_2023_workbook_vs_aqs.csv"))
  log_msg("  wrote ", file.path(P$tables, "check_2023_workbook_vs_aqs.csv"))
}

# ---- 4. what the workbook holds that the analysis does not --------------------
extra <- anti_join(wb_day, used, by = c("code", "sample_date"))
log_msg("\nWorkbook days not in the analysis: ", nrow(extra))
print(extra |> mutate(month = format(sample_date, "%Y-%m")) |> count(code, month, name = "days"))
log_msg("Denver-CAMP (DECO) appears in the workbook but is not an AQS formaldehyde")
log_msg("site in 2024-2025, so it is outside the study network and not added here.")
