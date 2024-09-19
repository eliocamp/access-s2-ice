library(rcdo)
library(data.table)
library(furrr)
plan(multisession, workers = 100)
source("scripts/setup/functions.R")

cdo_options_set("-L")

dir <- "/g/data/ub7/access-s1/hc/raw_model/unchecked/ice/ice/daily/"

years <- list.files(file.path(dir, "e01")) |> 
    strcapture(pattern = "di_ice_(\\d{4})\\d{4}_e01.nc", 
               proto = list(time = numeric(1))) |> 
    range()

dates <- seq(as.Date(paste0(years[1], "-01-01")), 
             as.Date(paste0(years[2], "-01-01")), by = "month")

members <- gsub("e", "", list.files(dir))

antarctic_regions <- list(
    Antarctic = "0,360,-90,-47",
    Bellinghausen = "-110,-70,-90,-47",
    Weddell = "-70,-15,-90,-47",
    KingHakon = "-15,70,-90,-47",
    EAntarctic = "70,165,-90,-47",
    RossAmundsen = "165,250,-90,-47"
)

files <- CJ(time = dates, member = members, region = names(antarctic_regions)) |>
    _[, file := paste0(dir, "e", member, "/di_ice_", format(time, "%Y%m%d"), "_e", member, ".nc")] |>
    _[]


cdo_seaice_extent <- function(file, region) {
    cdo_options_set("-L")

    output <- file.path("data", "derived", "hindcast_extent_s1", "daily", region, basename(file))
    dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
    
    if (file.exists(output)) {
        return("already done")
    }
    message("   Processing ", region)

    r <- strsplit(antarctic_regions[[region]], ",")[[1]]

    file_region <- cdo_selname(file, "aice") |>
        cdo_sellonlatbox(0, 360, -90, -47) |>
        cdo_sellonlatbox(
            lon1 = r[1], lon2 = r[2],
            lat1 = r[3], lat2 = r[4]
        )  |> 
        cdo_remap_nsidc() |> 
        cdo_execute()

    cdo_extent(file_region) |>
        cdo_execute(output = output)
    
    file.remove(file_region)
    
    return("did")
}

furrr::future_map2(files$file, files$region, cdo_seaice_extent)



files[, outfile := file.path("data", "derived", "hindcast_extent", "daily", region, basename(file))]

hindcast_data <- "data/derived/hindcast_extent/daily/"
extent_daily <- list.files(hindcast_data, recursive = TRUE)

extract_info <- function(x) {
  utils::strcapture("di_aice_(\\d{8})_e(\\d{2}).nc", 
                    basename(x), 
                    proto = list(init_time = character(1), 
                                member = character(1)))
}

extent_daily_data <- furrr::future_map(extent_daily, function(file) {
  # message(file)
  metR::ReadNetCDF(file.path(hindcast_data, file), "aice")  |> 
    _[, file := file] |> 
    _[, let(lon = NULL, lat = NULL)] |> 
    _[, region := dirname(file)] |> 
    _[, c("init_time", "member") := extract_info(file)] |> 
    _[, init_time := lubridate::as_datetime(init_time)] |> 
    _[, file := NULL]
}) |> 
  rbindlist() 

saveRDS(extent_daily_data, file.path(globals$data_derived, "hindcast_extent_daily_regions.Rds"))
