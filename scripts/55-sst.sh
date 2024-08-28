set -u
source scripts/setup/variables.bash

access_reanalysis_dir_sst=/g/data/ux62/access-s2/reanalysis/ocean/sst/


echo "Selecting ACCESS-S2 SST data south of $top_lat"

cdo -L -O -setday,1 -mergetime -apply,"-sellonlatbox,0,360,-90,$top_lat -selname,sst" [ $access_reanalysis_dir_sst/mo_sst_*.nc ] $access_sst
cdo -L -setday,1 -fldmean $access_sst $access_sst_mean


era5_dir=/g/data/rt52/era5/single-levels/monthly-averaged/sst

max_jobs=10
job_count=0

for year in {1981..2011}; do
    (
       cdo -L -b F32 -remapbil,$access_sst -selname,sst -mergetime [ $era5_dir/$year/sst_era5_moda_sfc_*.nc ] $data_temp/era5sst_$year.nc
    ) &

    job_count=$((job_count + 1))
    if [ "$job_count" -ge "$max_jobs" ]; then
        wait -n
        job_count=$((job_count - 1))
    fi
done

wait

cdo -L -O -mergetime [ $data_temp/era5sst_{1981..2011}.nc ] $era5_sst

cdo -L -setday,1 -fldmean $era5_sst $era5_sst_mean