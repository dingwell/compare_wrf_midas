#!/bin/bash
# Short tool to convert csv lists of MIDAS stations
# Downloaded from BADC to Excel and exported to csv

path_midas=$HOME/data/obs/midas


cat $path_midas/station_list.csv  \
  |sed 's/\s*,\s*/ /g'  \
  |head -n-1  \
  > $path_midas/station_list.dat
