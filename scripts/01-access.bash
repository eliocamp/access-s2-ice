source scripts/variables.bash

access_reanalysis_dir="/g/data/ux62/access-s2/reanalysis/ice/aice"

# Select only data I care about

echo "Selecting ACCESS-S2 data south of $top_lat"
cdo -L setday,1 -sellonlatbox,0,360,-90,$top_lat -cat $access_reanalysis_dir/mi_aice_*.nc $access_susbet_data

# Compute climatolgy

echo "Computing Climatology"
cdo -L ymonmean -seldate,1981-01-01,2011-12-31 $access_susbet_data $access_climatology

# Compute daily climatolgy

if [ ! -f $access_climatology_daily ]; then
    echo "Computing daily climatology"

    for year in 1981..2011; do
        cdo -L -remapbil,$nsidc_data /g/data/ux62/access-s2/reanalysis/ice/aice/di_aice_$year.nc $data_temp/temp_$year.nc
    done
    cdo -L ydaymean -cat $data_temp/temp_*.nc $access_climatology_daily
    rm $data_temp/temp_{1981..2011}.nc
fi

# Compute anomalies
echo "Computing anomalies"
cdo -L ymonsub $access_susbet_data $access_climatology $access_anomaly
