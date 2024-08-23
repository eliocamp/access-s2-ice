proj <- "+proj=stere +lat_0=-90 +lat_ts=-70 +lon_0=0 +k=1 +x_0=0 +y_0=0 +a=6378273 +b=6356889.449 +units=m"
r <- 25000
  
grid <- "data/derived/nsidc_climatology.nc" |> 
  metR::ReadNetCDF(vars = c(ice = "cdr_seaice_conc_monthly")) |> 
  _[time == time[1], .(ygrid, xgrid)]



xbounds <- c(vapply(grid$xgrid, function(x) x + r/2*c(-1, -1, 1, 1), FUN.VALUE = numeric(4)))
ybounds <- c(vapply(grid$ygrid, function(x) x + r/2*c(1, -1, -1, 1), FUN.VALUE = numeric(4)))


xyvals <- proj4::project(list(grid$xgrid, grid$ygrid), proj, inverse = TRUE)
xybounds <- proj4::project(list(xbounds, ybounds), proj, inverse = TRUE)


data <- list(
  gridtype = "curvilinear",
  xsize = data.table::uniqueN(grid$xgrid),
  ysize = data.table::uniqueN(grid$ygrid),
  gridsize = data.table::uniqueN(grid$xgrid)*data.table::uniqueN(grid$ygrid),
  xvals = xyvals$x,
  yvals = xyvals$y,
  
  xbounds = xybounds$x,
  ybounds = xybounds$y
)

data2 <- vapply(data, paste0, collapse = " ", FUN.VALUE = character(1))

writeLines(paste0(names(data), " = ", data2), "data/derived/nsidc_grid.txt")
