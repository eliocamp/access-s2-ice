

get_envars <- function(file = here::here("scripts/setup/variables.bash")) {
        old <- Sys.getenv()
        readRenviron(file)
        new <- Sys.getenv()
        new_names <- names(new)[!(names(new) %in% names(old))]
        Sys.unsetenv(new_names)

        as.list(new[!(names(new) %in% names(old))])
}

globals <- get_envars()

cdo_remap_nsidc <- function(ifile, ofile = NULL) {
        op <- rcdo::cdo_operator(command = globals$cdo_remap_nsidc, params = NULL, n_input = 1, n_output = 1)
        rcdo::cdo(op,  input = list(ifile), params = NULL, output = ofile)
}

cdo_extent <- function(ifile, ofile = NULL) {
        op <- rcdo::cdo_operator(command = globals$cdo_extent, params = NULL, n_input = 1, n_output = 1)
        rcdo::cdo(op,  input = list(ifile), params = NULL, output = ofile)
}

cdo_area<- function(ifile, ofile = NULL) {
        op <- rcdo::cdo_operator(command = globals$cdo_area, params = NULL, n_input = 1, n_output = 1)
        rcdo::cdo(op,  input = list(ifile), params = NULL, output = ofile)
}

cdo_iiee <- function(ifile1, ifile2, output, threshhold = 0.15) {
        file1 <- rcdo::cdo_gtc(ifile1, c = threshhold) |> 
                        rcdo::cdo_options_use("-L") |> 
                        rcdo::cdo_execute()

        file2 <- rcdo::cdo_gtc(ifile2, c = threshhold) |> 
                        rcdo::cdo_options_use("-L") |> 
                        rcdo::cdo_execute()

        out <- rcdo::cdo_ne(file1, file2) |> 
                rcdo::cdo_fldint()  |> 
                rcdo::cdo_execute(output = output)

        file.remove(c(file1, file2))
        return(out)
}


anchor_limits <- function(anchor = 0, binwidth = NULL, exclude = NULL,  bins = 10,
                          range = c(NA, NA), sym = TRUE) {
  force(range)
  force(anchor)
  force(binwidth)
  force(exclude)
  force(bins)
  function(x, binwidth2 = NULL) {
    if (sym) {
      D <- max(abs(x[1] - anchor), abs(x[2] - anchor))
      x <- c(anchor - D, anchor + D)
    }
    
    
    if (!is.null(binwidth)) binwidth2 <- binwidth
    if (is.null(binwidth2)) {
      binwidth2 <- diff(pretty(x, bins))[1]
    }
    
    mult <- ceiling((x[1] - anchor)/binwidth2) - 1L
    start <- anchor + mult*binwidth2
    b <- seq(start, x[2] + binwidth2, binwidth2)
    b <- b[!(b %in% exclude)]
    
    if (!is.na(range[1])) {
      m <- min(b)
      b <- c(b[b >= (range[1] + 1e-9)], -Inf)  # DAMN YOU FLOATING POINT ERRORS!!! 
    }
    
    if (!is.na(range[2])) {
      m <- max(b)
      b <- c(b[b <= (range[2] - 1e-9)], Inf)
    }
    sort(b)
    
  }
}

get <- `$`

sic_projection <- globals$nsidc_climatology_monthly |>  
  ncdf4::nc_open() |>  
  ncdf4::ncatt_get(varid = "crs") |> 
  get("proj_params")

topo <- cdo_topo(grid = globals$nsidc_grid, 
                 ofile = file.path(globals$data_derived, "topo.nc")) |> 
    cdo_execute(options = c("-f nc")) |> 
    ReadNetCDF(c(z = "topo")) |> 
    _[, .(x = xgrid, y = ygrid, z)]

contour <- StatContour$compute_group(topo, breaks = 0)
geom_antarctica_path <- geom_path(data = contour, aes(x, y, group = group), inherit.aes = FALSE, colour = "black")

geom_antarctica_fill <- geom_polygon(data = contour, aes(x, y, group = group), inherit.aes = FALSE, colour = "black", fill ="#FAFAFA")

geomcoord_antarctica <- list(NULL
    , coord_sf(crs = sic_projection, lims_method = "box")
    , scale_x_continuous(name = NULL, expand = c(0, 0))
    , scale_y_continuous(name = NULL, expand = c(0, 0))
    , geom_antarctica_path
)

scale_color_models <- scale_color_manual(NULL, 
                     values = c(access = "black", 
                                nsidc = "#e66100"),
                     labels = c(access = "ACCESS-S2",
                                nsidc = "NSIDC CDRV4"))

