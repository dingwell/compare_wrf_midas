#!/bin/bash
#   This script is used together with 
#           list_wrf_files.sh   and
#           plot_taylor.ncl
#   to compare different WRF runs with
#   midas observations.
# 
#   The bash script will create several files which will be read
#   by the ncl script.  It is therefore important not to modify
#   variables outside the section labeled PRESETS

START=$1
END=$2
FILES=${@:3}

#-- BEGIN PRESETS --#
path_midas='"$HOME/data/obs/midas"'
times_midas='@(00|03|06|09|12|15|18|21)'  # MIDAS observation times
#--  END PRESETS  --#

# Local variables:
NCLlist="./auto_presets.ncl"   # used in plot_taylor.ncl
WRFLIST="file_list_wrf.txt"

echo "Backing up previous settings"
if [ -e ./$WRFLIST ]; then
  mv $WRFLIST $WRFLIST.bak
fi
if [ -e ./$NCLlist ]; then
    mv ./$NCLlist ./$NCLlist.bak
fi
echo "Directory is clean from old files, moving on"

echo -e "$FILES"  \
  |sed 's/\s\s*/\n/g' \
  |sed '/\.nc$/!s/$/.nc/g' \
  > $WRFLIST
  # Replace white spaces with newlines
  # Find all rows NOT ending with ".nc" and append ".nc" to these lines

# Since sending arguments to ncl-scripts is a complete mess, we will instead
# generate a short ncl-script which can be loaded from the main ncl-script
# We want the following layout:
ncl_startdate=$( echo $START | sed 's/-/, /g')  # Convert date 'y, m, d'
ncl_line='START_DATE = (/ '$ncl_startdate' /)' # add line to $ncl_line
ncl_enddate=$( echo $END   | sed 's/-/, /g')   # Convert date 'y, m, d'
ncl_line=$ncl_line'\nEND_DATE   = (/ '$ncl_enddate' /)'   # add line to $ncl_line
# Change | to , and @(...) to (/.../) using sed:
ncl_midas_times=$(echo $times_midas | sed 's/|/,/g' | sed 's;@(\(.*\));(/\1/);g')  
ncl_line=$ncl_line'\nTIMES = '$ncl_midas_times

echo -e '\nContents of '$NCLlist':'
echo -e $ncl_line

# Print header:
echo "; Script automatically generated by compare_wrf_midas.sh" > $NCLlist
echo "; will be run by plot_taylor.ncl to read the presets defined"  >>$NCLlist
echo "; by the user in compare_wrf_midas.sh" >>$NCLlist
echo "; running compare_wrf_midas.sh will ensure up to date file lists" >>$NCLlist
# Print function
echo -e $ncl_line >> $NCLlist

exit
# Run ncl script for data comparision:
ncl plot_taylor.ncl
