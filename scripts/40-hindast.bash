# source scripts/setup/variables.bash
# # TODO: hacer para diario. 


# temp_access_anom=$(mktemp)
# persistence=$(mktemp)
# first_day=$(mktemp)
# temp_nsidc=$(mktemp)

# cdo_rmse="-sqrt -fldmean -sqr -sub"

# max_jobs=30
# job_count=0

# for ensemble in "01" "02" "03"; do
#     dir=/g/data/ux62/access-s2/hindcast/raw_model/ice/aice/daily/e$ensemble
#     for file in $dir/mi_aice_??????01_e${ensemble}.nc; do
#         (
#             echo "------------ $(basename $file .nc) ------------"
#             correlation=$data_derived/correlations/$(basename $file .nc)_forecast.nc
#             correlation_persistence=$data_derived/correlations/$(basename $file .nc)_persistence.nc

#             rmse=$data_derived/rmse/$(basename $file .nc)_forecast.nc
#             rmse_persistence=$data_derived/rmse/$(basename $file .nc)_persistence.nc
#             rmse_persistence_month=$data_derived/rmse/$(basename $file .nc)_persistence_month.nc

#             for file2 in $correlation $correlation_persistence $rmse $rmse_persistence; do
#                 if [[ ! -f $file2 ]]; then
#                     # Hay que buscar en /g/data/ux62/access-s2/hindcast/raw_model/ice/aice/daily/
#                     start_date=$(cdo -s showdate $file | awk '{print $1}')
#                     day=01
#                     year=$(echo $start_date | cut -d"-" -f1)
#                     month=$(echo $start_date | cut -d"-" -f2)

#                     # Select the previous month
#                     if [[ $month == "01" ]]; then
#                         month=12
#                         year=$((10#$year + 1))
#                     else
#                         month=$((10#$month - 1))
#                     fi

#                     echo "------ Cutting and remapping ------"
#                     cdo -L -remapbil,$nsidc_anomaly_monthly  -setday,1 -ymonsub -sellonlatbox,0,360,-90,$top_lat -selname,aice $file $access_renalysis_climatology_monthly $temp_access_anom

#                     echo "------ Selecting dates in nsidc ------"
#                     start_date=$(cdo -s showdate $temp_access_anom | awk '{print $1}')
#                     end_date=$(cdo -s showdate $temp_access_anom | awk '{print $NF}')
#                     cdo -L -chname,cdr_seaice_conc_monthly,aice -setday,1 -seldate,$start_date,$end_date $nsidc_anomaly_monthly $temp_nsidc
                    
#                     echo "------ Creating persistence forecast ------"
#                     cdo -L -seldate,$year-$month-01 $nsidc_anomaly_monthly $first_day
#                     cdo -L -mul -expr,"aice=1" $temp_nsidc $first_day $persistence
#                     break
#                 fi
#             done

#             if [ ! -f ${correlation} ]; then
#                 echo "------ Computing spatial correlation for $(basename $file) ------"
#                 cdo -L -fldcor $temp_access_anom $temp_nsidc $correlation
#             fi

#             if [ ! -f ${correlation_persistence} ]; then
#                 echo "------ Computing persistence spatial correlation for $(basename $file) ------"
#                 cdo -L -fldcor $persistence $temp_nsidc $correlation_persistence
#             fi

#             if [ ! -f ${rmse} ]; then
#                 echo "------ Computing RMSE for $(basename $file) ------"
#                 cdo -L -sqrt -fldmean -sqr -sub $temp_access_anom $temp_nsidc $rmse
#             fi

#             if [ ! -f ${rmse_persistence} ]; then
#                 echo "------ Computing persistence RMSE for $(basename $file) ------"
#                 cdo -L -sqrt -fldmean -sqr -sub $persistence $temp_nsidc $rmse_persistence
#             fi
#         ) & 

#         job_count=$((job_count + 1))
#         if [ "$job_count" -ge "$max_jobs" ]; then
#             wait -n
#             job_count=$((job_count - 1))
#         fi
#     done
# done
