
top_lat=-47
nsidc_data=data/data_derived/nsidc_anomaly.nc
access_climatology=data/data_derived/access_climatology.nc

temp_access_anom=$(mktemp)
persistence=$(mktemp)
temp_nsidc=$(mktemp)

Acá la persistencia está mal. Tiene que ser la persitencia del valor del día en el que se hizo el prono, no el promedio del mes!!!

for ensemble in "01" "02" "03"; do 
    dir=/g/data/ux62/access-s2/hindcast/raw_model/ice/aice/monthly/e$ensemble
    for file in $dir/mi_aice_??????01_e${ensemble}.nc; do
        correlation=data/data_derived/correlations/$(basename $file .nc)_forecast.nc
        correlation_persistence=data/data_derived/correlations/$(basename $file .nc)_persistence.nc

        rmse=data/data_derived/rmse/$(basename $file .nc)_forecast.nc
        rmse_persistence=data/data_derived/rmse/$(basename $file .nc)_persistence.nc
        
        for file2 in $correlation $correlation_persistence $rmse $rmse_persistence; do
            if [[ ! -f $file2 ]]; then
                echo "------ Cutting and remapping ------"
                cdo -L -remapbil,$nsidc_data -setday,1 -ymonsub -sellonlatbox,0,360,-90,$top_lat -selname,aice $file $access_climatology $temp_access_anom
                cdo -L -mul -seltimestep,1 $temp_access_anom -expr,'aice=1' $temp_access_anom $persistence
                start_date=$(cdo -s showdate $temp_access_anom | awk '{print $1}')
                end_date=$(cdo -s showdate $temp_access_anom | awk '{print $NF}')
                cdo -L seldate,$start_date,$end_date $nsidc_data $temp_nsidc 
                break
            fi
        done

        if [ ! -f ${correlation} ]; then
            echo "------ Computing spatial correlation for $(basename $file) ------"
            cdo -L  fldcor $temp_access_anom $temp_nsidc $correlation
        fi

        if [ ! -f ${correlation_persistence} ]; then
            echo "------ Computing persistence spatial correlation for $(basename $file) ------"
            cdo -L  fldcor $persistence $temp_nsidc $correlation_persistence
        fi

        if [ ! -f ${rmse} ]; then
            echo "------ Computing RMSE for $(basename $file) ------"
            cdo -L sqrt -fldmean -sqr -sub $temp_access_anom $temp_nsidc $rmse
        fi

        if [ ! -f ${rmse_persistence} ]; then
            echo "------ Computing persistence RMSE for $(basename $file) ------"
            cdo -L sqrt -fldmean -sqr -sub $persistence $temp_nsidc $rmse_persistence
        fi

        rm $temp_access_anom
        rm $persistence
        rm $temp_nsidc
    done
done
