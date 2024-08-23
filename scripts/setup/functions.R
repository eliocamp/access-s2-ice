

get_envars <- function(file = "scripts/setup/variables.bash") {
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

cdo_iiee <- function(ifile1, ifile2, threshhold = 0.15) {
        file1 <- rcdo::cdo_gtc(ifile1, c = threshhold) |> 
                        rcdo::cdo_options_use("-L") |> 
                        rcdo::cdo_execute()

        file2 <- rcdo::cdo_gtc(ifile2, c = threshhold) |> 
                        rcdo::cdo_options_use("-L") |> 
                        rcdo::cdo_execute()

        rcdo::cdo_ne(file1, file2) |> 
                rcdo::cdo_fldint() 
}