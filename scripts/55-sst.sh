set -u
source scripts/setup/variables.bash

access_reanalysis_dir_sst=/g/data/ux62/access-s2/reanalysis/ocean/sst/

echo "Selecting ACCESS-S2 SST data south of $top_lat"

cdo -L -O -setday,1 -mergetime -apply,"-sellonlatbox,0,360,-90,0 -selname,sst" [ $access_reanalysis_dir_sst/mo_sst_*.nc ] $access_sst
cdo -L -setday,1 -fldmean -sellonlatbox,0,360,-90,$top_lat $access_sst $access_sst_mean

era5_dir=/g/data/rt52/era5/single-levels/monthly-averaged/sst

max_jobs=15
job_count=0

for year in {1981..2024}; do
    (
       cdo -L -O -b F32 -selname,sst -mergetime [ $era5_dir/$year/sst_era5_moda_sfc_*.nc ] $data_temp/era5sst_$year.nc
    ) &

    job_count=$((job_count + 1))
    if [ "$job_count" -ge "$max_jobs" ]; then
        wait -n
        job_count=$((job_count - 1))
    fi
done

wait

cdo -L -O -sellonlatbox,0,360,-90,0 -mergetime [ $data_temp/era5sst_{1981..2024}.nc ] $era5_sst

cdo -L -setday,1 -fldmean -sellonlatbox,0,360,-90,$top_lat  $era5_sst $era5_sst_mean