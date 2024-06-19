url=https://www.metoffice.gov.uk/hadobs/hadisst/data/HadISST_ice.nc.gz

hadisst_data="data/data_raw/hadisst.nc"
rm $hadisst_data

# Download HadISST data
curl $url -o $hadisst_data.gz

gunzip $hadisst_data.gz

temp=$(mktemp)
cdo -L setday,1 -selname,sic $hadisst_data ${temp}
mv ${temp} ${hadisst_data}



# Select only data I care about
top_lat=-47
temp=$(mktemp)
cdo -L sellonlatbox,0,360,-90,${top_lat} $hadisst_data ${temp}
mv ${temp} ${hadisst_data}

# Compute climatolgy
hadisst_climatology=${data_derived}/hadisst_climatology.nc
rm $hadisst_climatology
echo "Computing Climatology"
cdo -L ymonmean -seldate,1981-01-01,2011-12-31 ${hadisst_data} ${hadisst_climatology}

 
# Compute anomalies
hadisst_anomaly=${data_derived}/hadisst_anomaly.nc
echo "Computing anomalies"
cdo -L ymonsub ${hadisst_data} ${hadisst_climatology} ${hadisst_anomaly}


