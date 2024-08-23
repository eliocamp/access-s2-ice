source scripts/variables.bash

# Select only data I care about

echo "Selecting ACCESS-S2 ice data south of $top_lat"
cdo -L -setday,1 $cdo_remap_nsidc -mergetime $access_reanalysis_dir/mi_aice_*.nc $access_subset_data

# Compute monthly climatolgy
echo "Computing Climatology"
cdo -L -ymonmean -seldate,1981-01-01,2011-12-31 $access_subset_data $access_climatology

# Compute monthly anomalies
echo "Computing anomalies"
cdo -L -ymonsub $access_subset_data $access_climatology $access_anomaly

# Compute daily climatolgy
if [ ! -f $access_daily ]; then
    echo "Computing daily climatology"
    rm $data_temp/temp_*.nc
    for year in {1981..2024}; do
        (
            cdo -L $cdo_remap_nsidc -setvrange,0,1 /g/data/ux62/access-s2/reanalysis/ice/aice/di_aice_$year.nc $data_temp/temp_$year.nc 
        ) &
    done
    wait
    cdo -L -O -del29feb -mergetime $data_temp/temp_*.nc $access_daily   

    rm $data_temp/temp_*.nc
fi


cdo -L -ydaymean -seldate,1981-01-01,2011-12-31 $access_daily $access_climatology_daily
