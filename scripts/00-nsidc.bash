# Download nsidc data
nsidc_url="https://polarwatch.noaa.gov/erddap/griddap/nsidcG02202v4shmday.nc?cdr_seaice_conc_monthly[(1979-01-01T00:00:00Z):1:(2023-12-01T00:00:00Z)][(4350000.0):1:(-3950000.0)][(-3950000.0):1:(3950000.0)]"
data_path="data/data_raw"
nsidc_file="nsidc.nc"
nsidc_grid_file="nsidc_grid.nc"
nsidc_data=${data_path}/${nsidc_file}


echo "Downloading NSDCI data"
curl --globoff ${nsidc_url} -o ${nsidc_data}

temp=$(mktemp)
cdo -L setvrange,0,1 -setgrid,data/data_derived/nsidc_grid.txt ${nsidc_data} ${temp}
mv ${temp} ${nsidc_data}



# Compute NSIDC climatology
nsidc_climatology="data/data_derived/nsidc_climatology.nc"


echo "Computing Climatology"
cdo -L ymonmean -seldate,1981-01-01,2011-12-31 ${nsidc_data} ${nsidc_climatology}

# Compute NSIDC anomaly
nsidc_anomaly="data/data_derived/nsidc_anomaly.nc"

echo "Computing anomalies"
cdo -L ymonsub ${nsidc_data} ${nsidc_climatology} ${nsidc_anomaly}
