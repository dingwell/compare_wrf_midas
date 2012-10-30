#!/bin/bash
#  This script will scan a given directory for any wrf output files between
#  two dates matching midas observation times
#   (e.g. all files between wrfout_d03_2010-04-20_00:00:00 and
#                           wrfout_d03_2010-04-21_23:00:00
#  The full list dumped to stdout
#
#       !!! first time must be 00 hrs and last must be 21 hrs !!!
#  --- not true, an update provides the "times" argument, see below ---
#
#  File names must follow the pattern:
#       wrfout_d0X_YYYY-MM-DD_HH:MM:SS
#  e.g.:
#       wrfout_d03_2010-04-22_09:00:00
#
#   Usage:
#      list_wrf_files.sh [/path/to/data] [domain_nr] [start_date] [end_date] [times]
#
#   where domain_nr is on the format "d01"
#   and   start_date, end_date are on the format "YYYY-MM-DD"

# data_dir="./wsm3"         # $1
# domain="d01"              # $2
# start_date="2010-04-22"   # $3
# end_date="2010-04-23"     # $4
# times='@(00,03,06,09)'    # $5

shopt -s extglob
#         domain:       hours wanted:     (see comment below)
#echo "$1/wrfout_$2"*"_"$5":00:00"
ls "$1/wrfout_$2"*"_"$5":00:00" \
        | sed -n '/'$3'_00/,/'$4'_21/p'         \
        | sed 's/.*/&.nc/'

# Row:  explanation:
#  1    list all files in data directory ($1) matching domain ($2) and hours
#  2    only print files between start_date ($3) and end_date ($4) (including start_date & end_date)
#       will assume that that data for every hour (00,03,...,21) are present
#  3    Append ".nc" to each line

