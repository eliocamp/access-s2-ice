source scripts/variables.bash

url=https://www.metoffice.gov.uk/hadobs/hadisst/data/HadISST_ice.nc.gz

rm $hadisst_data

# Download HadISST data
curl $url -o $hadisst_data.gz

gunzip $hadisst_data.gz

temp=$(mktemp)
cdo -L setday,1 -chname,sic,aice -selname,sic $hadisst_data $temp
mv $temp $hadisst_data

# Select only data I care about
temp=$(mktemp)
cdo -L sellonlatbox,0,360,-90,$top_lat $hadisst_data $temp
mv $temp $hadisst_data

# Compute anomalies
echo "Computing anomalies"
cdo -L ymonsub $hadisst_data -ymonmean -seldate,1981-01-01,2011-12-31 $hadisst_data $hadisst_anomaly


