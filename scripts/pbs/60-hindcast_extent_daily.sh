#!/bin/bash

#PBS -P dx2
#PBS -q normal
#PBS -l ncpus=40
#PBS -l mem=190GB
#PBS -l walltime=03:00:00
#PBS -l wd
#PBS -l jobfs=400GB
#PBS -l storage=gdata/ux62+scratch/k10

# Load module, always specify version number.
module load R/4.3.1
module load cdo/2.0.5

# Must include `#PBS -l storage=scratch/ab12+gdata/yz98` if the job
# needs access to `/scratch/ab12/` and `/g/data/yz98/`. Details on:
# https://opus.nci.org.au/display/Help/PBS+Directives+Explained

# Run R application
Rscript scripts/60-hindcast_area_daily.R > log-hindcast_area.txt