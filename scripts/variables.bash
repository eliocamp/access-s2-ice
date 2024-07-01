set -u # Treat unset variables as an error

top_lat=-47

data_raw="data/data_raw"
data_derived="data/data_derived"
data_temp="data/data_temp"

nsidc_data=$data_raw/nsidc.nc
nsidc_anomaly=$data_derived/nsidc_anomaly.nc

hadisst_data=$data_raw/hadisst.nc
hadisst_anomaly=$data_derived/hadisst_anomaly.nc

access_susbet_data=$data_derived/access_subset.nc
access_climatology=$data_derived/access_climatology.nc
access_anomaly=$data_derived/access_anomaly.nc

access_sst=$data_derived/access_sst.nc

era5_sst=$data_derived/era5_sst.nc

access_climatology_daily=$data_derived/access_climatology_daily.nc

nsidc_extent=$data_derived/nsidc_extent.nc
hadisst_extent=$data_derived/hadisst_extent.nc
access_extent=$data_derived/access_extent.nc
