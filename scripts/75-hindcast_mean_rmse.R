library(rcdo)
library(data.table)
library(furrr)
library(lubridate)
plan(multisession, workers = 120)
source("scripts/setup/functions.R")

cdo_options_set("-L")

cdo_del29feb <- function(input, output = NULL) {
    del29feb <- list(command = "del29feb", 
                 params = NULL,
                 n_input = 1, 
                 n_output = 1)
    rcdo::cdo(operator = del29feb, input = list(input), output = output) 
}


dates <- seq(as.Date("1981-01-01"), as.Date("2018-12-01"), by = "month")

dir <- "/g/data/ux62/access-s2/hindcast/raw_model/ice/aice/daily/"
time_of_forecast <- as.Date("1989-01-01")

cdo_compute_rmse <- function(time_of_forecast) {
    cdo_options_set("-L")
    file <- paste0("di_aice_", format(time_of_forecast, "%Y%m%d"), "_emm.nc")    
    
    rmse_out <- file.path(globals$data_derived, "rmse_spatial_mean", file)
    dir.create(dirname(rmse_out), showWarnings = FALSE, recursive = TRUE)

    if (file.exists(rmse_out)) {
        return("done")
    }

    ensmean <- file.path(globals$data_derived, "hindcast_ensmean", file)

    ensdates <- cdo_showdate(ensmean) |> 
        cdo_execute(options = c("-L", "-s")) |> 
        strsplit(" ") |> 
        _[[1]]  |> 
        Filter(nzchar, x = _)
    
    
    nsidc <- globals$nsidc_daily_anomaly |> 
        cdo_seldate(paste(range(ensdates), collapse = ",")) |> 
        cdo_del29feb() |> 
        cdo_execute()

    ensmean_anom <- ensmean |> 
        cdo_del29feb() |> 
        cdo_ydaysub(globals$access_reanalysis_climatology_daily) |> 
        cdo_execute()

    rmse <- cdo_sub(nsidc, ensmean_anom) |> 
        cdo_sqr() |> 
        cdo_timmean()  |> 
        cdo_sqrt() |> 
        cdo_execute(output = rmse_out)
    
    file.remove(c(ensmean_anom, nsidc))
    return("did")
}


furrr::future_map(dates, cdo_compute_rmse)