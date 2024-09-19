library(furrr)

workers <- as.numeric(Sys.getenv("PBS_WORKERS", unset = 20))
message(workers, " workers")

plan(multisession, workers = workers)
library(rcdo)
cdo_options_set(c("-L", "--pedantic"))
library(data.table)
library(lubridate)
library(progressr)

source("scripts/setup/functions.R")

nsidc_data  <- globals$nsidc_daily_data

cdo_del29feb <- function(input, output = NULL) {
    del29feb <- list(command = "del29feb", 
                 params = NULL,
                 n_input = 1, 
                 n_output = 1)
    rcdo::cdo(operator = del29feb, input = list(input), output = output) 
}

dir <- "/g/data/ub7/access-s1/hc/raw_model/unchecked/ice/ice/daily/"

years <- list.files(file.path(dir, "e01")) |> 
    strcapture(pattern = "di_ice_(\\d{4})\\d{4}_e01.nc", 
               proto = list(time = numeric(1))) |> 
    range()

dates <- seq(as.Date(paste0(years[1], "-01-01")), 
             as.Date(paste0(years[2], "-01-01")), by = "month")

members <- gsub("e", "", list.files(dir))

iiee_dir <- file.path(globals$data_derived, "iiee-s1")
dir.create(iiee_dir, showWarnings = FALSE)

files <- CJ(time = dates, member = members) |> 
    _[, file := paste0(dir, "e", member, "/di_ice_", format(time, "%Y%m%d"), "_e", member, ".nc" )] |> 
    _[] |> 
    as.data.frame()

compute_metrics <- function(i) {
    # message(i)
    cdo_options_set(c("-L", "--pedantic"))
    file <- files[i, ]

    iiee_out <- file.path(iiee_dir, gsub("\\.nc", "_forecast.nc", basename(file$file)))

    if (all(file.exists(c(iiee_out)))) {
        return()
    }

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


    nc <- ncdf4::nc_open(nsidc_data_part)
    times_nsidc <- metR:::.parse_time(time = nc$dim$time$vals, units = nc$dim$time$units, calendar = nc$dim$time$calendar)
    ncdf4::nc_close(nc)

    if (!file.exists(iiee_out)) {
         remapped <- file$file |> 
                    cdo_selname("aice") |> 
                    cdo_remap_nsidc() |> 
                    cdo_del29feb() |> 
                    cdo_execute(output = tempfile(pattern = basename(file$file)))

        nc <- ncdf4::nc_open(remapped)
        times_access <- metR:::.parse_time(time = nc$dim$time$vals, units = nc$dim$time$units, calendar = nc$dim$time$calendar)
        ncdf4::nc_close(nc)

        if (length(times_access) != length(times_nsidc)) {
            stop("malos tiempos en ", i)
        }

        cdo_iiee(remapped, nsidc_data_part, output = iiee_out) 
        file.remove(remapped)
    }

    file.remove(nsidc_data_part)
}


out <- furrr::future_map(seq_len(nrow(files)), compute_metrics)

read_measures <- function(files) {  
  dates <- utils::strcapture("di_ice_(\\d{8})_e(\\d{2})_(\\w+).nc", basename(files),
                             proto = list(time_forecast = character(),
                                          member = character(),
                                          type = character())) |> 
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

list.files(file.path(globals$data_derived, "iiee-s1"), pattern = "di_ice_",
                          full.names = TRUE) |> 
            read_measures()  |> 
            _[, measure := "iiee"]  |> 
            saveRDS(file.path(globals$data_derived, "iiee-s1.Rds"))


