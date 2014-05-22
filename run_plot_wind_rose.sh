#!/bin/bash
export WRF_MIDAS_ROOT=$HOME/programming/git/compare_wrf_midas # Location of this script
export MIDAS_DATA_DIR=$HOME/data/obs/midas  # Location of midas station-wise data files
export NCL_TYPE=x11

STATION_LIST="18341 18340 60276 20340 21084 20358 21097 17708 20326 20476 22558 22783 21097 20241 19705 20797 21751 19466"
export STATION
for i in $STATION_LIST; do
  echo $i
  STATION=$i.txt
  ncl plot_wind_rose.ncl >/dev/null
done
