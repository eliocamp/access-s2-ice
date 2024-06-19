# Compute sea ice extent
data_derived="data/data_derived"
data_raw="data/data_raw"

nsidc_data=${data_raw}/nsidc.nc
nsidc_anomaly="data/data_derived/nsidc_anomaly.nc"

hadisst_data=${data_raw}/hadisst.nc
hadisst_anomaly=${data_derived}/hadisst_anomaly.nc

access_data=${data_derived}/access_subset.nc
access_anomaly=${data_derived}/access_anomaly.nc

# Compute sea ice extent
nsidc_extent=${data_derived}/nsidc_extent.nc
hadisst_extent=${data_derived}/hadisst_extent.nc
access_extent=${data_derived}/access_extent.nc

echo "--- Computing sea ACCESS-S2 extent"
cdo -L -fldsum -mul -gtc,0.15 ${access_data} -gridarea ${access_data} ${access_extent}

echo "--- Computing sea HadISST extent"
cdo -L -fldsum -mul -gtc,0.15 ${hadisst_data} -gridarea ${hadisst_data} ${hadisst_extent}

echo "--- Computing sea NSIDC extent"
cdo -L -fldsum -mul -gtc,0.15 ${nsidc_data} -gridarea ${nsidc_data} ${nsidc_extent}

nsidc_temp=$(mktemp)
access_temp=$(mktemp)
haddist_temp=$(mktemp)

echo "--- Selecting dates"
cdo -L -selname,aice -seldate,1981-01-01,2018-12-31 $access_anomaly $access_temp

echo "--- Remaping to ACCESS grid"
cdo -L remapbil,$access_anomaly -seldate,1981-01-01,2018-12-31 --selname,cdr_seaice_conc_monthly $nsidc_anomaly $nsidc_temp
cdo -L remapbil,$access_anomaly -seldate,1981-01-01,2018-12-31 --selname,sic $hadisst_anomaly $haddist_temp

echo "--- Computing spatial correlations"
cdo -L fldcor $nsidc_temp $access_temp $data_derived/correlation_space_nsidc.nc
cdo -L fldcor $haddist_temp $access_temp $data_derived/correlation_space_hadisst.nc

echo "--- Computing temporal correlations"
temp_dir=`mktemp -d /tmp/cdo_ymoncorr.XXXXXXXXXXXX`

mon_list="01 02 03 04 05 06 07 08 09 10 11 12" 

for mon in $mon_list ; do
    cdo -L timcor -selmon,$mon $nsidc_temp -selmon,$mon $access_temp $temp_dir/corr_$mon.nc
done

cdo -L -O mergetime ${temp_dir}/corr_??.nc $data_derived/correlation_time.nc
rm -rf $temp_dir

