top_lat=-47

# Global locations
data_raw="data/raw"
data_derived="data/derived"
data_temp="data/temp"

# Static files
land_mask="data/derived/land_mask.nc"
nsidc_grid="data/raw/nsidc_grid.txt"

# NSIDC
nsidc_data_monthly="${data_raw}/nsidc_data_monthly.nc"
nsidc_anomaly_monthly="${data_derived}/nsidc_anomaly_monthly.nc"

nsidc_daily_data="${data_raw}/nsidc_data_daily.nc"
nsidc_climatology_daily="${data_derived}/nsidc_climatology_daily.nc"
nsidc_daily_anomaly="${data_derived}/nsidc_daily_anomaly.nc"

# HADISST
hadisst_data="${data_raw}/hadisst_data.nc"
hadisst_anomaly="${data_derived}/hadisst_anomaly.nc"

# ACCESS Reanalysis
access_reanalysis_dir="/g/data/ux62/access-s2/reanalysis/ice/aice"

access_renalysis_monthly="${data_derived}/access_subset.nc"
access_renalysis_climatology_monthly="${data_derived}/access_climatology.nc"
access_renalysis_anomaly_monthly="${data_derived}/access_anomaly.nc"

access_reanalysis_daily="${data_derived}/access_daily.nc"
access_reanalysis_climatology_daily="${data_derived}/access_climatology_daily.nc"
access_renalysis_anomaly_daily="${data_derived}/access_anomaly_daily.nc"

# Derived variables
## Extent & area

nsidc_extent_monthly="${data_derived}/nsidc_extent_monthly.nc"
nsidc_area_monthly="${data_derived}/nsidc_area_monthly.nc"
nsidc_extent_daily="${data_derived}/nsidc_extent_daily.nc"
nsidc_area_daily="${data_derived}/nsidc_area_daily.nc"

hadisst_extent_monthly="${data_derived}/hadisst_extent_monthly.nc"
hadisst_area_monthly="${data_derived}/hadisst_area_monthly.nc"

access_extent_monthly="${data_derived}/access_extent_monthly.nc"
access_area_monthly="${data_derived}/access_area_monthly.nc"

access_extent_daily="${data_derived}/access_extent_daily.nc"
access_area_daily="${data_derived}/access_area_daily.nc"


# Operations
cdo_remap_nsidc="mul ${land_mask} -remapbil,${nsidc_grid}"
cdo_extent="fldint -gtc,0.15"
cdo_area="fldint -setvrange,0.15,1"



access_sst="${data_derived}/access_sst.nc"
era5_sst="${data_derived}/era5_sst.nc"