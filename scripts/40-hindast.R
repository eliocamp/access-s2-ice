library(furrr)
workers <- as.numeric(Sys.getenv("PBS_WORKERS", unset = 25))
message(workers, " workers")

plan(multisession, workers = workers)

library(rcdo)
cdo_options_set(c("-L", "--pedantic"))
library(data.table)
library(lubridate)
library(progressr)

source("scripts/setup/functions.R")

nsidc_anomaly <- globals$nsidc_daily_anomaly
nsidc_data  <- globals$nsidc_daily_data
climatology <- globals$access_reanalysis_climatology_daily
nsidc_climatology <- globals$nsidc_climatology_daily


cdo_del29feb <- function(input, output = NULL) {
    del29feb <- list(command = "del29feb", 
                 params = NULL,
                 n_input = 1, 
                 n_output = 1)
    rcdo::cdo(operator = del29feb, input = list(input), output = output) 
}

climatology_twice <-  cdo_mergetime(list(cdo_setyear(nsidc_climatology, 2001), cdo_setyear(nsidc_climatology, 2002))) |> 
    cdo_del29feb() |>
    cdo_execute(options = "-L")


dates  <- seq(as.Date("1981-01-01"), as.Date("2018-12-01"), by = "month")
members  <- paste0("0", 1:9)

dir <- "/g/data/ux62/access-s2/hindcast/raw_model/ice/aice/daily/"

rmse_dir <- file.path(globals$data_derived, "rmse")
dir.create(rmse_dir, showWarnings = FALSE)

iiee_dir <- file.path(globals$data_derived, "iiee")
dir.create(iiee_dir, showWarnings = FALSE)


files <- CJ(time = dates, member = members) |> 
    _[, file := paste0(dir, "e", member, "/di_aice_", format(time, "%Y%m%d"), "_e", member, ".nc")] |> 
    _[] |> 
    as.data.frame()

files <- rbind(files, 
 CJ(time = dates, member = "mm")  |> 
    _[, file := file.path(globals$data_derived, "hindcast_ensmean", 
                         paste0("di_aice_", format(time, "%Y%m%d"), "_e", member, ".nc"))]  
)

cdo_rmse <- function(file1, file2) {
    cdo_sub(file1, file2) |> 
        cdo_sqr() |> 
        cdo_fldmean() |> 
        cdo_sqrt()
}


cdo_persist <- function(file, file2, init_time) {
    first_day <- cdo_seldate(file, startdate = as.character(init_time)) |> 
        cdo_execute(output = tempfile(pattern = basename(file2)))

    out <- file2 |>
        cdo_expr(instr = "aice=1") |> 
        cdo_mul(first_day) |> 
        cdo_execute(output = tempfile(pattern = basename(file2)))
    
    file.remove(first_day)
    return(out)
}

cdo_climextrapolate <- function(climatology_twice, first_time, last_time) {
    dif <- 2001 - year(first_time)
    
    year(first_time) <- year(first_time) + dif
    year(last_time) <- year(last_time) + dif

    climatology_twice |> 
        cdo_seldate(paste(first_time, last_time, sep = ",")) |> 
        cdo_execute()
}

remove_if_exists <- function(variable_names) {
    vapply(variable_names, \(x) {
        if (exists(x) && file.exists(get(x))) {
            return(file.remove(get(x)))
        }

        return(FALSE)
    }, FUN.VALUE = logical(1))    
}

compute_metrics <- function(i) {
    # message(i)
    cdo_options_set(c("-L", "--pedantic"))
    file <- files[i, ]

    rmse_out <- file.path(rmse_dir, gsub("\\.nc", "_forecast.nc", basename(file$file)))
    iiee_out <- file.path(iiee_dir, gsub("\\.nc", "_forecast.nc", basename(file$file)))

    rmse_out_persistence <- file.path(rmse_dir, gsub("\\_e[\\da-z]{2}.nc", "_e01_persistence.nc", basename(file$file), perl = TRUE))
    iiee_out_persistence <- file.path(iiee_dir, gsub("\\_e[\\da-z]{2}.nc", "_e01_persistence.nc", basename(file$file), perl = TRUE))

    rmse_out_climatology <- file.path(rmse_dir, gsub("\\_e[\\da-z]{2}.nc", "_e01_climatology.nc", basename(file$file), perl = TRUE))
    iiee_out_climatology  <- file.path(iiee_dir, gsub("\\_e[\\da-z]{2}.nc", "_e01_climatology.nc", basename(file$file), perl = TRUE))

    if (all(file.exists(c(rmse_out_persistence, rmse_out, iiee_out, iiee_out_persistence, rmse_out_climatology, iiee_out_climatology)))) {
        return()
    }

    ff <- c(rmse_out_persistence, rmse_out, iiee_out, iiee_out_persistence, rmse_out_climatology, iiee_out_climatology)
    
    stopifnot(!any(grepl("e\\d{2}.nc", ff)))

    nc <- ncdf4::nc_open(file$file)
    times <- metR:::.parse_time(time = nc$dim$time$vals, units = nc$dim$time$units, calendar = nc$dim$time$calendar)
    ncdf4::nc_close(nc)
    
    last_time <- max(times)
    first_time <- min(times)

    nsidc_data_part <- cdo_seldate(nsidc_data, 
                              startdate = as.character(first_time), 
                              enddate = as.character(last_time)) |> 
                    cdo_del29feb() |> 
                    cdo_execute(output = tempfile(pattern = basename(file$file)))                    

    nsidc_anomaly_part <- nsidc_data_part |> 
        cdo_ydaysub(globals$nsidc_climatology_daily) |> 
        cdo_execute()

    nc <- ncdf4::nc_open(nsidc_data_part)
    times_nsidc <- metR:::.parse_time(time = nc$dim$time$vals, units = nc$dim$time$units, calendar = nc$dim$time$calendar)
    ncdf4::nc_close(nc)

    remap_file <- tempfile(pattern = basename(file$file))

    remapped <- function() {   
        if (file.exists(remap_file)) {
            return(remap_file)
        }

        remap_file <- file$file |> 
                cdo_selname("aice") |> 
                cdo_remap_nsidc() |> 
                cdo_del29feb() |> 
                cdo_execute(output = remap_file)
        
        nc <- ncdf4::nc_open(remap_file)
        times_access <- metR:::.parse_time(time = nc$dim$time$vals, units = nc$dim$time$units, calendar = nc$dim$time$calendar)
        ncdf4::nc_close(nc)

        if (length(times_access) != length(times_nsidc)) {
            stop("malos tiempos en ", i)
        }

        return(remap_file)
    }
    
    if (!file.exists(rmse_out)) {
        remapped() |> 
            cdo_ydaysub(climatology) |>        
            cdo_rmse(nsidc_anomaly_part) |> 
            cdo_execute(output = rmse_out)
    }

    if (!file.exists(iiee_out)) {
        cdo_iiee(remapped(), nsidc_data_part, output = iiee_out) 
    }

    if (!file.exists(rmse_out_persistence)) {
        persistence <- cdo_persist(globals$nsidc_daily_anomaly, nsidc_anomaly_part, init_time = as.character(file$time)) 

        nc <- ncdf4::nc_open(persistence)
        times_persistence <- metR:::.parse_time(time = nc$dim$time$vals, units = nc$dim$time$units, calendar = nc$dim$time$calendar)
        ncdf4::nc_close(nc)

        if (length(times_persistence) != length(times_nsidc)) {
            stop("malos tiempos en la persistencia de ", i)
        }

        rmse_persistence <- cdo_rmse(persistence, nsidc_anomaly_part) |> 
            cdo_execute(output = rmse_out_persistence)        
    }

    if (!file.exists(iiee_out_persistence)) {
        if (!exists(persistence)) {
            persistence <- cdo_persist(globals$nsidc_daily_data, nsidc_data_part, init_time = as.character(file$time))
        }
        
        iiee_persistence <- cdo_iiee(persistence, nsidc_data_part, output = iiee_out_persistence)
    }

    if (!file.exists(rmse_out_climatology)) {
        clim  <- cdo_climextrapolate(climatology_twice, first_time, last_time)

        nc <- ncdf4::nc_open(clim)
        times_clim <- metR:::.parse_time(time = nc$dim$time$vals, units = nc$dim$time$units, calendar = nc$dim$time$calendar)
        ncdf4::nc_close(nc)

        if (length(times_clim) != length(times_nsidc)) {
            stop("malos tiempos en la climatología de ", i)
        }
                
        cdo_iiee(nsidc_data_part, clim, output = iiee_out_climatology)
    }

    file.remove(c(remap_file, nsidc_data_part, nsidc_anomaly_part))
    
    remove_if_exists(c("persistence", "clim"))
}


out <- furrr::future_map(seq_len(nrow(files)), compute_metrics)

read_measures <- function(files) {  
  dates <- utils::strcapture("di_aice_(\\d{8})_e([\\dm]{2})_(\\w+).nc", basename(files),
                             proto = list(time_forecast = character(),
                                          member = character(),
                                          type = character()), perl = TRUE) |> 
    as.data.table() |> 
    _[, time_forecast := as.Date(time_forecast, format = "%Y%m%d")] |> 
    _[]
  
  read <- function(i) {
    data <- try(metR::ReadNetCDF(files[[i]], vars = c(value = "aice")), silent = TRUE)
    
    if (inherits(data, "try-error")) {
      file.remove(files[[i]])
      warning("file ", basename(files[[i]]), " deleted")
      return(NULL)
    }

    data |> 
      _[, let(lat = NULL, lon = NULL)] |> 
      _[] |> 
      _[, let(time_forecast = dates$time_forecast[[i]],
              member = dates$member[[i]],
              type = dates$type[[i]],
              file = files[[i]])] |> 
      _[] 
  }
  
  furrr::future_map(seq_along(files), read) |> 
    rbindlist() 
}


list.files(file.path(globals$data_derived, "rmse"), pattern = "di_aice_",
                          full.names = TRUE) |> 
            read_measures() |>
            _[, measure := "rmse"]  |> 
            saveRDS(file.path(globals$data_derived, "rmse.Rds"))


list.files(file.path(globals$data_derived, "iiee"), pattern = "di_aice_",
                          full.names = TRUE) |> 
            read_measures() |>
            _[, measure := "iiee"]  |> 
            saveRDS(file.path(globals$data_derived, "iiee.Rds"))