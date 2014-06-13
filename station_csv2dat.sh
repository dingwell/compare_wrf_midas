#!/bin/bash
# Short tool to convert csv lists of MIDAS stations
# Downloaded from BADC to Excel and exported to csv
# Requires the variable $MIDAS_DATA_DIR to be set

cat $MIDAS_DATA_DIR/station_list.csv  \
  |sed 's/\s*,\s*/ /g'  \
  |tail -n+3  \
  > $MIDAS_DATA_DIR/station_list.dat
