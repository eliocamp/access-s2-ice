source scripts/variables.bash

temp_access_anom=$(mktemp)
persistence=$(mktemp)
first_day=$(mktemp)
temp_nsidc=$(mktemp)

for ensemble in "01" "02" "03"; do
    dir=/g/data/ux62/access-s2/hindcast/raw_model/ice/aice/monthly/e$ensemble
    for file in $dir/mi_aice_??????01_e${ensemble}.nc; do
        correlation=$data_derived/correlations/$(basename $file .nc)_forecast.nc
        correlation_persistence=$data_derived/correlations/$(basename $file .nc)_persistence.nc

        rmse=$data_derived/rmse/$(basename $file .nc)_forecast.nc
        rmse_persistence=$data_derived/rmse/$(basename $file .nc)_persistence.nc

        # Hay que buscar en /g/data/ux62/access-s2/reanalysis/ice/aice/di_aice_YYYY.nc y seleccionar el primero del mes.
        start_date=$(cdo -s showdate $file | awk '{print $1}')
        day=1
        year=$(echo $start_date | cut -d"-" -f1)
        month=$(echo $start_date | cut -d"-" -f2)
        start_date=$year-$month-$day
        #
        if [ $day$month -eq "0101" ]; then
            year=$(($year - 1))
        fi
        file_daily=/g/data/ux62/access-s2/reanalysis/ice/aice/di_aice_$year.nc

        # I think this is only for the first timestep (1981-01-01 doesn't exist in the reanalysis??)
        if [[ ! -f $file_daily ]]; then
            continue
        fi

        for file2 in $correlation $correlation_persistence $rmse $rmse_persistence; do
            if [[ ! -f $file2 ]]; then
                echo "------ Cutting and remapping ------"
                cdo -L remapbil,$nsidc_data -setday,1 -ymonsub -sellonlatbox,0,360,-90,$top_lat -selname,aice $file $access_climatology $temp_access_anom

                cdo -L ydaysub -remapbil,$nsidc_data -sellonlatbox,0,360,-90,$top_lat -seldate,$start_date $file_daily $access_climatology_daily $first_day
                cdo -L mul -expr,"aice=1" $temp_access_anom $first_day $persistence

                start_date=$(cdo -s showdate $temp_access_anom | awk '{print $1}')
                end_date=$(cdo -s showdate $temp_access_anom | awk '{print $NF}')
                cdo -L seldate,$start_date,$end_date $nsidc_data $temp_nsidc
                break
            fi
        done

        if [ ! -f ${correlation} ]; then
            echo "------ Computing spatial correlation for $(basename $file) ------"
            cdo -L fldcor $temp_access_anom $temp_nsidc $correlation
        fi

        if [ ! -f ${correlation_persistence} ]; then
            echo "------ Computing persistence spatial correlation for $(basename $file) ------"
            cdo -L fldcor $persistence $temp_nsidc $correlation_persistence
        fi

        if [ ! -f ${rmse} ]; then
            echo "------ Computing RMSE for $(basename $file) ------"
            cdo -L sqrt -fldmean -sqr -sub $temp_access_anom $temp_nsidc $rmse
        fi

        if [ ! -f ${rmse_persistence} ]; then
            echo "------ Computing persistence RMSE for $(basename $file) ------"
            cdo -L sqrt -fldmean -sqr -sub $persistence $temp_nsidc $rmse_persistence
        fi

    done
done
