library(furrr)
plan(multisession, workers = 20)

library(rcdo)
library(data.table)
library(progressr)

source("scripts/setup/functions.R")

nsidc <- globals$nsidc_daily_anomaly
climatology <- globals$access_reanalysis_climatology_daily


dates  <- seq(as.Date("1981-01-01"), as.Date("2018-12-01"), by = "month")
members  <- paste0("0", 1:9)

dir <- "/g/data/ux62/access-s2/hindcast/raw_model/ice/aice/daily/"

rmse_dir <- file.path(globals$data_derived, "rmse")
dir.create(rmse_dir, showWarnings = FALSE)

iiee_dir <- file.path(globals$data_derived, "iiee")
dir.create(iiee_dir, showWarnings = FALSE)


files <- CJ(time = dates, member = members) |> 
    _[, file := paste0(dir, "e", member, "/di_aice_", format(time, "%Y%m%d"), "_e", member, ".nc" )] |> 
    _[] |> 
    as.data.frame()

cdo_rmse <- function(file1, file2) {
    cdo_sub(file1, file2) |> 
        cdo_sqr() |> 
        cdo_fldmean() |> 
        cdo_sqrt()
}

cdo_del29feb <- function(input, output = NULL) {
    del29feb <- list(command = "del29feb", 
                 params = NULL,
                 n_input = 1, 
                 n_output = 1)
    rcdo::cdo(operator = del29feb, input = list(input), output = output) 
}

cdo_persist <- function(file, file2, init_time) {
    first_day <- cdo_seldate(file, startdate = as.character(init_time)) |> 
        cdo_execute(output = tempfile(pattern = basename(file2)))

    file2 |>
        cdo_expr(instr = "aice=1") |> 
        cdo_mul(first_day) |> 
        cdo_execute(output = tempfile(pattern = basename(file2)))
}

compute_metrics <- function(i) {
    message(i)
    cdo_options_set(c("-L", "--pedantic"))
    file <- files[i, ]

    rmse_out <- file.path(rmse_dir, gsub("\\.nc", "_forecast.nc", basename(file$file)))
    iiee_out <- file.path(iiee_dir, gsub("\\.nc", "_forecast.nc", basename(file$file)))

    rmse_out_persistence <- file.path(rmse_dir, gsub("\\.nc", "_persistence.nc", basename(file$file)))
    iiee_out_persistence <- file.path(iiee_dir, gsub("\\.nc", "_persistence.nc", basename(file$file)))

    if (all(file.exists(c(rmse_out_persistence, rmse_out, iiee_out, iiee_out_persistence)))) {
        return()
    }

    nc <- ncdf4::nc_open(file$file)
    times <- metR:::.parse_time(time = nc$dim$time$vals, units = nc$dim$time$units, calendar = nc$dim$time$calendar)
    ncdf4::nc_close(nc)
    
    last_time <- max(times)
    first_time <- min(times)

    nsidc_part <- cdo_seldate(nsidc, 
                              startdate = as.character(first_time), 
                              enddate = as.character(last_time)) |> 
                    cdo_del29feb() |> 
                    cdo_execute(output = tempfile(pattern = basename(file$file)))

    nc <- ncdf4::nc_open(nsidc_part)
    times_nsidc <- metR:::.parse_time(time = nc$dim$time$vals, units = nc$dim$time$units, calendar = nc$dim$time$calendar)
    ncdf4::nc_close(nc)
    
    if (!all(file.exists(rmse_out, iiee_out))) {
        remapped <- file$file |> 
                    cdo_selname("aice") |> 
                    cdo_remap_nsidc() |> 
                    cdo_del29feb() |> 
                    cdo_ydaysub(climatology) |> 
                    cdo_execute(output = tempfile(pattern = basename(file$file)))

        nc <- ncdf4::nc_open(remapped)
        times_access <- metR:::.parse_time(time = nc$dim$time$vals, units = nc$dim$time$units, calendar = nc$dim$time$calendar)
        ncdf4::nc_close(nc)

        if (length(times_access) != length(times_nsidc)) {
            stop("malos tiempos en ", i)
        }

    }
    

    if (!file.exists(rmse_out)) {        
        cdo_rmse(remapped, nsidc_part) |> 
            cdo_execute(output = rmse_out)
    }

    if (!file.exists(iiee_out)) {
        cdo_iiee(remapped, nsidc_part) |> 
            cdo_execute(output = iiee_out)
    }

    if (!file.exists(rmse_out_persistence)) {
        persistence <- cdo_persist(nsidc, nsidc_part, init_time = as.character(file$time))

        nc <- ncdf4::nc_open(persistence)
        times_persistence <- metR:::.parse_time(time = nc$dim$time$vals, units = nc$dim$time$units, calendar = nc$dim$time$calendar)
        ncdf4::nc_close(nc)

        if (length(times_persistence) != length(times_nsidc)) {
            stop("malos tiempos en la persistencia de ", i)
        }

        rmse_persistence <- cdo_rmse(persistence, nsidc_part) |> 
            cdo_execute(output = rmse_out_persistence)
        
        
        file.remove(persistence)
    }

    if (!file.exists(iiee_out_persistence)) {
        persistence <- cdo_persist(nsidc, nsidc_part, init_time = as.character(file$time))

        rmse_persistence <- cdo_iiee(persistence, nsidc_part) |> 
            cdo_execute(output = iiee_out_persistence)
    }

    # file.remove(c(nsidc_part, remapped))
}


out <- furrr::future_map(seq_len(nrow(files)), compute_metrics)
