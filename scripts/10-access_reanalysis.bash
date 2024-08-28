set -u

source scripts/setup/variables.bash

# Select only data I care about
echo "Selecting ACCESS-S2 ice data south of $top_lat"
cdo -L -setday,1 -$cdo_remap_nsidc -mergetime $access_reanalysis_dir/mi_aice_*.nc $access_renalysis_monthly

# Compute monthly climatolgy
echo "Computing Climatology"
cdo -L -ymonmean -seldate,1981-01-01,2011-12-31 $access_renalysis_monthly $access_renalysis_climatology_monthly

# Compute monthly anomalies
echo "Computing anomalies"
cdo -L -ymonsub $access_renalysis_monthly $access_renalysis_climatology_monthly $access_renalysis_anomaly_monthly

# Compute daily climatolgy
if [ ! -f $access_reanalysis_daily ]; then
    echo "Computing daily climatology"
    rm $data_temp/temp_*.nc
    for year in {1981..2024}; do
        (
            cdo -L -$cdo_remap_nsidc -setvrange,0,1 /g/data/ux62/access-s2/reanalysis/ice/aice/di_aice_$year.nc $data_temp/temp_$year.nc 
        ) &
    done
    wait
    cdo -L -O -del29feb -mergetime $data_temp/temp_*.nc $access_reanalysis_daily   

    rm $data_temp/temp_*.nc
fi

cdo_smooth_climatology 11 $access_reanalysis_daily $access_reanalysis_climatology_daily

cdo -L ydaysub $access_reanalysis_daily $access_reanalysis_climatology_daily $access_renalysis_anomaly_daily
