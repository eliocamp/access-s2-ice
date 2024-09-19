library(rcdo)
library(data.table)
library(furrr)
library(lubridate)
plan(multisession, workers = 100)
source("scripts/setup/functions.R")

cdo_options_set("-L")

dates <- seq(as.Date("1981-01-01"), as.Date("2018-12-01"), by = "month")
lags  <- c(1, 10, 100, 200)

members <- paste0("0", 1:9)

dir <- "/g/data/ux62/access-s2/hindcast/raw_model/ice/aice/daily/"

files <- CJ(forecast_time = dates, lag = lags, member = members) |>
    _[, time := forecast_time + lag] |> 
    _[, file := paste0(dir, "e", member, "/di_aice_", format(forecast_time, "%Y%m%d"), "_e", member, ".nc")] |>
    _[, times_noyear := update(time, year = 2000)]

time <- files$times_noyear[1]

file <- files[times_noyear == unique(times_noyear)[[10]] & lag == 10]

cdo_hindcast_rmse <- function(file) {
    cdo_options_set("-L")

    output <- file.path("data", "derived", "hindcast_extent", "daily", region, basename(file))
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

