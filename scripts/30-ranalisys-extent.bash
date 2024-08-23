set -u
source scripts/setup/variables.bash

# Compute sea ice extent

echo "--- Computing ACCESS-S2 monthly extent"
cdo -L -$cdo_extent $access_renalysis_monthly $access_extent_monthly &
cdo -L -$cdo_area   $access_renalysis_monthly $access_area_monthly &

echo "--- Computing HadISST monthly extent"
cdo -L -$cdo_extent $hadisst_data $hadisst_extent_monthly &
cdo -L -$cdo_area   $hadisst_data $hadisst_area_monthly &

echo "--- Computing NSIDC monthly extent"
cdo -L -$cdo_extent $nsidc_data_monthly $nsidc_extent_monthly & 
cdo -L -$cdo_area   $nsidc_data_monthly $nsidc_area_monthly &

echo "--- Computing ACCESS-S2 daily extent"
cdo -L -$cdo_extent $access_reanalysis_daily $access_extent_daily &
cdo -L -$cdo_area   $access_reanalysis_daily $access_area_daily &

echo "--- Computing NSIDC daily extent"
cdo -L -$cdo_extent $nsidc_daily_data $nsidc_extent_daily &
cdo -L -$cdo_area   $nsidc_daily_data $nsidc_area_daily &

wait 
# nsidc_temp=$(mktemp)
# access_temp=$(mktemp)
# haddist_temp=$(mktemp)

# echo "--- Selecting dates"
# cdo -L -selname,aice -seldate,1981-01-01,2018-12-31 $access_renalysis_anomaly_monthly $access_temp

# echo "--- Remaping to ACCESS grid"
# cdo -L remapbil,$access_renalysis_anomaly_monthly -seldate,1981-01-01,2018-12-31 --selname,cdr_seaice_conc_monthly $nsidc_anomaly_monthly $nsidc_temp
# cdo -L remapbil,$access_renalysis_anomaly_monthly -seldate,1981-01-01,2018-12-31 --selname,sic $hadisst_anomaly $haddist_temp

# echo "--- Computing spatial correlations"
# cdo -L fldcor $nsidc_temp $access_temp $data_derived/correlation_space_nsidc.nc
# cdo -L fldcor $haddist_temp $access_temp $data_derived/correlation_space_hadisst.nc

# echo "--- Computing temporal correlations"
# temp_dir=`mktemp -d /tmp/cdo_ymoncorr.XXXXXXXXXXXX`

# mon_list="01 02 03 04 05 06 07 08 09 10 11 12" 

# for mon in $mon_list ; do
#     cdo -L timcor -selmon,$mon $nsidc_temp -selmon,$mon $access_temp $temp_dir/cor_$mon.nc
#     cdo -L timcovar -selmon,$mon $nsidc_temp -selmon,$mon $access_temp $temp_dir/cov_$mon.nc
# done

# cdo -L -O mergetime $temp_dir/cor_??.nc $data_derived/correlation_time.nc
# cdo -L -O mergetime $temp_dir/cov_??.nc $data_derived/covariance_time.nc
# rm -rf $temp_dir

