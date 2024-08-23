set -u

cdo -L remapbil,$nsidc_grid -seltimestep,1 $access_reanalysis_dir/mi_aice_1981.nc temp.nc

cdo -L -gec,0 temp.nc mask_access.nc
cdo -L -gec,0 -seltimestep,1 $nsidc_data_monthly mask_nsidc.nc

cdo -L mul mask_access.nc mask_nsidc.nc $land_mask

rm temp.nc mask_access.nc mask_nsidc.nc
