source scripts/variables.bash

# Download nsidc data
nsidc_url="https://polarwatch.noaa.gov/erddap/griddap/nsidcG02202v4shmday.nc?cdr_seaice_conc_monthly[(1979-01-01T00:00:00Z):1:(2023-12-01T00:00:00Z)][(4350000.0):1:(-3950000.0)][(-3950000.0):1:(3950000.0)]"
nsidc_grid_file="nsidc_grid.nc"

echo "Downloading NSDCI data"
curl --globoff $nsidc_url -o $nsidc_data

temp=$(mktemp)
cdo -L -chname,cdr_seaice_conc_monthly,aice -setvrange,0,1 -setgrid,data/data_raw/nsidc_grid.txt $nsidc_data $temp
mv $temp $nsidc_data

source scripts/05-common_mask.bash

temp=$(mktemp)
cdo -mul $land_mask $nsidc_data $temp
mv $temp $nsidc_data

# Compute NSIDC anomaly
echo "Computing anomalies"
cdo -L -ymonsub $nsidc_data -ymonmean -seldate,1981-01-01,2011-12-31 $nsidc_data $nsidc_anomaly

for year in {1981..2023}; do
    nsidc_daily_url="https://polarwatch.noaa.gov/erddap/griddap/nsidcG02202v4sh1day.nc?cdr_seaice_conc[($year-01-01T00:00:00Z):1:($year-12-01T00:00:00Z)][(4350000.0):1:(-3950000.0)][(-3950000.0):1:(3950000.0)]"
    file=$nsidc_daily_data.$year
    # Download if doesn't exist
    if [ ! -f $file ]; then
        echo "Downloading NSDCI data $year"
        curl --globoff $nsidc_daily_url -o $file
    fi
done

cdo -L -chname,cdr_seaice_conc,aice -mul $land_mask -setvrange,0,1 -setgrid,$nsidc_grid -mergetime $nsidc_daily_data.{1981..2023} $nsidc_daily_data

# Compute NSIDC anomaly
echo "Computing anomalies"
cdo -L -ydaysub $nsidc_daily_data -ydaymean -seldate,1981-01-01,2011-12-31 $nsidc_daily_data $nsidc_daily_anomaly
