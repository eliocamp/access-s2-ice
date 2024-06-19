grid <- "data/data_raw/hadisst.nc" |> 
  metR::ReadNetCDF(vars = c(ice = "sic"), 
                   subset = list(time = "2000-01-01")) |> 
  _[time == time[1], .(xgrid = lat, ygrid = lon)]

rx <- grid[, unique(xgrid)] |> 
  sort() |> 
  diff() |> 
  _[[1]]

ry <- grid[, unique(ygrid)] |> 
  sort() |> 
  diff() |> 
  _[[1]]

data <- list(
  gridtype = "lonlat",
  xsize = data.table::uniqueN(grid$xgrid),
  ysize = data.table::uniqueN(grid$ygrid),

  xfirst = min(grid$xgrid),
  xinc = rx,
  yfirst = min(grid$ygrid),
  yinc = ry
)

data2 <- vapply(data, paste0, collapse = " ", FUN.VALUE = character(1))

writeLines(paste0(names(data), " = ", data2), "data/data_derived/hadisst_grid.txt")
