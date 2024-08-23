set -u
source scripts/setup/variables.bash
access_reanalysis_dir_sst=/g/data/ux62/access-s2/reanalysis/ocean/sst/


echo "Selecting ACCESS-S2 SST data south of $top_lat"
cdo -L -setday,1 -fldmean -cat -apply,"-sellonlatbox,0,360,-90,$top_lat -selname,sst" [ $access_reanalysis_dir_sst/mo_sst_*.nc ] $access_sst

era5_dir=/g/data/rt52/era5/single-levels/monthly-averaged/sst/
cdo -L -setday,1 -fldmean -sellonlatbox,0,360,-90,$top_lat -selname,sst -cat [ $era5_dir/{1981..2023}/*.nc ] $era5_sst