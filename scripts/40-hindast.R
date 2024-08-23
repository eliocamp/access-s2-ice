library(rcdo)
library(data.table)
library(progressr)
library(furrr)

nsidc <- "data/data_derived/nsidc_daily/nsidc_daily_anomaly.nc"
climatology <- "data/data_derived/access_climatology_daily.nc"

dates  <- seq(as.Date("1981-01-01"), as.Date("2018-12-01"), by = "month")
members  <- paste0("0", 1:9)

dir <- "/g/data/ux62/access-s2/hindcast/raw_model/ice/aice/daily/"

files <- CJ(time = dates, member = members) |> 
    _[, file := paste0(dir, "e", member, "/di_aice_", format(time, "%Y%m%d"), "_e", member, ".nc" )] |> 
    _[] |> 
    as.data.frame()

cdo_remap_nsidc  <- function(file) {
    nsidc_grid <- "data/data_raw/nsidc_grid.txt"
    land_mask  <- "data/data_derived/land_mask.nc"
    
    file |> 
        cdo_remapbil(nsidc_grid) |> 
        cdo_mul(land_mask)
}

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
    rcdo:::cdo(operator = del29feb, input = list(input), output = output) 
}

cdo_persist <- function(file, file2, init_time) {
    first_day <- cdo_seldate(file, startdate = as.character(init_time)) |> 
        cdo_set_options("L") |> 
        cdo_execute()

    file2 |>
        cdo_expr(instr = "aice=1") |> 
        cdo_mul(first_day) |> 
        cdo_set_options("L") |> 
        cdo_execute()
}

compute_rmse <- function(i) {
    file <- files[i, ]

    # TODO: Calcular IIEE. 

    rmse_out <- file.path("data", "data_derived", "rmse", gsub("\\.nc", "_forecast.nc", basename(file$file)))
    rmse_out_persistence <- file.path("data", "data_derived", "rmse", gsub("\\.nc", "_persistence.nc", basename(file$file)))

    if (all(file.exists(c(rmse_out_persistence, rmse_out)))) {
        return()
    }

    nc <- ncdf4::nc_open(file$file)
    len_time <- nc$dim$time$len
    ncdf4::nc_close(nc)

    last_time <- file$time + len_time
    first_time <- file$time + 1
    nsidc_part <- cdo_seldate(nsidc, 
                              startdate = as.character(first_time), 
                              enddate = as.character(last_time)) |> 
                    cdo_del29feb() |> 
                    cdo_set_options("L") |> 
                    cdo_execute()

    if (!file.exists(rmse_out)) {
        remapped <- file$file |> 
            cdo_selname("aice") |> 
            cdo_del29feb() |> 
            cdo_remap_nsidc() |> 
            cdo_ydaysub(climatology) |> 
            cdo_set_options("L") |> 
            cdo_execute()
            
        cdo_rmse(remapped, nsidc_part) |> 
            cdo_set_options("L") |> 
            cdo_execute(output = rmse_out)
    }

    if (!file.exists(rmse_out_persistence)) {
        persistence <- cdo_persist(nsidc, nsidc_part, init_time = as.character(file$time))

        rmse_persistence <- cdo_rmse(persistence, nsidc_part) |> 
            cdo_set_options("L") |>
            cdo_execute(output = rmse_out_persistence)
    }

    file.remove(c(nsidc_part, persistence, remapped))
}

plan(multisession, workers = 20)


out <- furrr::future_map(seq_len(nrow(files)), compute_rmse)
