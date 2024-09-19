#!/bin/bash

#PBS -P dx2
#PBS -q normal
#PBS -l ncpus=48
#PBS -l mem=190GB
#PBS -l walltime=03:00:00
#PBS -l wd
#PBS -l jobfs=400GB
#PBS -l storage=gdata/ux62+scratch/k10+gdata/ub7

# Load module, always specify version number.
module load R/4.3.1
module load cdo/2.0.5

# Must include `#PBS -l storage=scratch/ab12+gdata/yz98` if the job
# needs access to `/scratch/ab12/` and `/g/data/yz98/`. Details on:
# https://opus.nci.org.au/display/Help/PBS+Directives+Explained

# Run R application
export PBS_WORKERS=100
Rscript scripts/45-hindast_s1.R > log-hindcast.txt