library(rcdo)
library(data.table)
library(furrr)
library(lubridate)
plan(multisession, workers = 120)
source("scripts/setup/functions.R")

cdo_options_set("-L")

dates <- seq(as.Date("1981-01-01"), as.Date("2018-12-01"), by = "month")
members <- paste0("0", 1:9)

dir <- "/g/data/ux62/access-s2/hindcast/raw_model/ice/aice/daily/"

cdo_compute_ensmean <- function(time_of_forecast) {
    
    ensmean <- file.path(globals$data_derived, "hindcast_ensmean", paste0("di_aice_", format(time_of_forecast, "%Y%m%d"), "_emm.nc"))

    dir.create(dirname(ensmean), showWarnings = FALSE, recursive = TRUE)

    if (file.exists(ensmean)) {
        return("exists")
    }

    f <- paste0(dir, "e", members, "/di_aice_", format(time_of_forecast, "%Y%m%d"), "_e", members, ".nc")

    chunk1 <- tempfile()
    cmd1 <- paste0("cdo -O -L  -ensmean -apply,\"-sellonlatbox,0,360,-90,-47 -selname,aice -seltimestep,1/42\" [ ", 
                        f, " ] ", chunk1) 

    f <- paste0(dir, "e", members[1:3], "/di_aice_", format(time_of_forecast, "%Y%m%d"), "_e", members[1:3], ".nc")
    chunk2 <- tempfile()
    cmd2 <- paste0("cdo -O -L -ensmean -apply,\"-sellonlatbox,0,360,-90,-47 -selname,aice -seltimestep,43/279\" [ ", 
                        f, " ] ", chunk2) 

    system(paste0(cmd1, " & ", cmd2))
    
    c(chunk1, chunk2) |> 
        cdo_mergetime() |> 
        cdo_remap_nsidc() |> 
        cdo_options_use(c("-L", "-O")) |> 
        cdo_execute(output = ensmean)

    file.remove(c(chunk1, chunk2))
    return("did")
}


furrr::future_map(dates, cdo_compute_ensmean)