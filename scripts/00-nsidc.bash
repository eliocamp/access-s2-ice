set -u
source scripts/setup/variables.bash

# Download nsidc data
nsidc_url="https://polarwatch.noaa.gov/erddap/griddap/nsidcG02202v4shmday.nc?cdr_seaice_conc_monthly[(1979-01-01T00:00:00Z):1:(2023-12-01T00:00:00Z)][(4350000.0):1:(-3950000.0)][(-3950000.0):1:(3950000.0)]"
nsidc_grid_file="nsidc_grid.nc"

if [ ! -f $nsidc_data_monthly ]; then
    echo "Downloading NSIDC monthly data"
    curl --globoff $nsidc_url -o $nsidc_data_monthly

    temp=$(mktemp)
    cdo -L -chname,cdr_seaice_conc_monthly,aice -setvrange,0,1 -setgrid,data/raw/nsidc_grid.txt $nsidc_data_monthly $temp
    mv $temp $nsidc_data_monthly
fi

source scripts/05-common_mask.bash

temp=$(mktemp)
cdo -mul $land_mask $nsidc_data_monthly $temp
mv $temp $nsidc_data_monthly

# Compute NSIDC anomaly
echo "Computing anomalies"

cdo -L -ymonmean -seldate,1981-01-01,2011-12-31 $nsidc_data_monthly $nsidc_climatology_monthly &

cdo -L -ymonsub $nsidc_data_monthly $nsidc_climatology_monthly $nsidc_anomaly_monthly & 

mkdir $data_raw/nsidc_daily/


max_jobs=8
job_count=0

for year in {1981..2023}; do
        nsidc_daily_url="https://polarwatch.noaa.gov/erddap/griddap/nsidcG02202v4sh1day.nc?cdr_seaice_conc[($year-01-01T00:00:00Z):1:($year-12-31T00:00:00Z)][(4350000.0):1:(-3950000.0)][(-3950000.0):1:(3950000.0)]"
    file=$data_raw/nsidc_daily/$year.nc
    
    # Download if doesn't exist
    if [ ! -f $file ]; then
        (
            echo "Downloading NSIDC daily data $year"
            curl --globoff $nsidc_daily_url -o $file
        ) & 
        job_count=$((job_count + 1))
        echo "jobs= $job_count"
    fi
    
    if [ "$job_count" -ge "$max_jobs" ]; then
        
        wait -n
        job_count=$((job_count - 1))
    fi
done
wait

echo "Merging and masking daily data"
cdo -L -chname,cdr_seaice_conc,aice -mul $land_mask -setvrange,0,1  -setgrid,$nsidc_grid -mergetime  $data_raw/nsidc_daily/{1981..2023}.nc $nsidc_daily_data

# Compute NSIDC anomaly
echo "Computing daily climagology and anomalies"

cdo_smooth_climatology 11 $nsidc_daily_data $nsidc_climatology_daily

cdo -L ydaysub $nsidc_daily_data $nsidc_climatology_daily $nsidc_daily_anomaly
