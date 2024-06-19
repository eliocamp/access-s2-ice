data_derived="data/data_derived"
access_data_dir="/g/data/ux62/access-s2/reanalysis/ice/aice"

# Select only data I care about
top_lat=-47
access_susbet_data=${data_derived}/access_subset.nc
echo "Selecting ACCESS-S2 data south of $top_lat"
cdo -L sellonlatbox,0,360,-90,${top_lat} -cat ${access_data_dir}/mi_aice_*.nc ${access_susbet_data}

# Compute climatolgy
access_climatology=${data_derived}/access_climatology.nc
echo "Computing Climatology"
cdo -L ymonmean -seldate,1981-01-01,2011-12-31 ${access_susbet_data} ${access_climatology}

 
# Compute anomalies
access_anomaly=${data_derived}/access_anomaly.nc
echo "Computing anomalies"
cdo -L ymonsub ${access_susbet_data} ${access_climatology} ${access_anomaly}


