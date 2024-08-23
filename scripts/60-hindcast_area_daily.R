library(rcdo)
library(data.table)
library(furrr)

dates <- seq(as.Date("1981-01-01"), as.Date("2018-12-01"), by = "month")
members <- paste0("0", 1:9)

dir <- "/g/data/ux62/access-s2/hindcast/raw_model/ice/aice/daily/"

files <- CJ(time = dates, member = members) |>
    _[, file := paste0(dir, "e", member, "/di_aice_", format(time, "%Y%m%d"), "_e", member, ".nc")] |>
    _[]


antarctic_regions <- list(
    Antarctic = "0,360,-90,-47",
    Bellinghausen = "-110,-70,-90,-47",
    Weddell = "-70,-15,-90,-47",
    KingHakon = "-15,70,-90,-47",
    EAntarctic = "70,165,-90,-47",
    RossAmundsen = "165,250,-90,-47"
)

cdo_remap_nsidc <- function(file) {
    land_mask <- "data/derived/land_mask.nc"
    nsidc <- "data/raw/nsidc_grid.txt"
    file |>
        cdo_remapbil(nsidc) |>
        cdo_mul(land_mask)
}

cdo_area <- function(file) {
    file |>
        cdo_setvrange(rmin = 0.15, rmax = 1) |>
        cdo_fldint()
}

cdo_seaice_area <- function(file) {
    outputs <- file.path("data", "derived", "hindcast_area", "daily", names(antarctic_regions), basename(file))

    if (all(file.exists(outputs))) {
        return("done")
    }
    message("Processing ", basename(file))
    for (region in names(antarctic_regions)) {
        output <- file.path("data", "derived", "hindcast_area", "daily", region, basename(file))
        dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
        if (file.exists(output)) {
            next
        }
        message("   Processing ", region)
        r <- strsplit(antarctic_regions[[region]], ",")[[1]]

        file_region <- cdo_selname(file, "aice") |>
            cdo_options_use("L") |>
            cdo_sellonlatbox(0, 360, -90, -47) |>
            cdo_sellonlatbox(
                lon1 = r[1], lon2 = r[2],
                lat1 = r[3], lat2 = r[4]
            )  |> 
            cdo_remap_nsidc() |> 
            cdo_execute()
        
        cdo_area(file_region) |>
            cdo_options_use("L") |>
            cdo_execute(output = output)
        
        file.remove(file_region)
    }
    return("did")
}

plan(multisession, workers = 20)
library(progressr)

with_progress({
    p <- progressr::progressor(along = files$file)

    a <- furrr::future_map(files$file, \(x) {
        p()
        cdo_seaice_area(x)
    })
})
