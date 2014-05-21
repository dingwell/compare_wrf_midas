#!/bin/bash
# Expects data files to be on the format:
#   [PREFIX][YEAR0][MONTH0]-[YEAR1][MONTH1][SUFFIX]
# Where:
#   [PREFIX]  is the first part of the filename (e.g. "midas_glblwx-africa_")
#   [YEAR0]   is the starting year of data in the file (e.g. "1974")
#   [MONTH0]  is the starting month of data in the file (e.g. "01")
#   [YEAR1]   is the ending year of data in the file (e.g. "1974")
#   [MONTH1]  is the ending month of data in the file (e.g. "12")
#   [SUFFIX]  is the file suffix (e.g. ".txt" OR ".txt.gz")
#
#   This example would look for the file:
#     midas_glblwx-africa_197401-197412.txt
#   Or:
#     midas_glblwx-africa_197401-197412.txt.gz
#
# If the suffix ".txt.gz" is used, then get_stns.sh will assume that the file
# is compressed using gzip.

# GLOBAL VARIABLES:
STATIONS="18341 18340 60276 20340 21084 20358 21097 17708 20326 20476 22558 22783 21097 20241 19705"
#STATIONS="18341 18300"
INPREFIX="midas_glblwx-africa_"
#SUFFIX=".txt"
SUFFIX=".txt.gz"
#MATCH1=197401-197412  # Unique string in filename of first file to read
#MATCH2=197501-197512  # Unique string in filename of last file ot read
MATCH1=197401-197412  # Unique string in filename of first file to read
MATCH2=201301-201312  # Unique string in filename of last file ot read

# FUNCTIONS

# MAIN
# Get a list of all files within the desired range:
FILES=$(ls $INPREFIX*$SUFFIX|sed -n "/$MATCH1/,/$MATCH2/p")
if [ -z "$FILES" ]; then
  echo "ERROR: No files found matching $MATCH1 and/or $MATCH2"
  echo "Recheck with list of files in working directory"
  exit 1
fi


# Create a command string from the station list:
if [ ! -z $(echo $SUFFIX|grep .gz) ]; then
  echo ".gz extension found, will attempt to use zcat"
else
  echo "Assuming non-compressed source files, will use cat"
fi
STR1='zcat $f |tee >(grep "SYNOP, '
STR2=$(echo $STATIONS|sed 's/\([0-9][0-9]*\) /\1" >\1.txt) >(grep "SYNOP, /g')
STR3=$(echo $STATIONS|sed 's/.* \([0-9][0-9]*\)/" >\1.txt)/')
STR4="|grep -i error"
# What this does:
# STR1: The first part of the command
# STR2: The second part is generated from the station list, we wrap the stn_id (NNNNN) in ">(grep NNNNN>NNNNN.txt)"
# STR3: Same as for STR2 but only for the last station (only the second part needed)
# STR4: Used to prevent the contents of the original files from printing to stdout
FIRST=true
echo "Extracting data from file:"
for f in $FILES; do
  echo "$f"

  STR="$STR1$STR2$STR3$STR4"
  #echo "STR: $STR"

  # Evaluate command string:
  eval "$STR"

  # Change from > to >> after first iteration (subsequent iteration will append data to files)
  if $FIRST; then 
    STR2=$(echo "$STR2"|sed 's/\(>[0-9]\)/>\1/g')
    STR3=$(echo "$STR3"|sed 's/\(>[0-9]\)/>\1/g')
    FIRST=false
  fi
  #exit
done
  #STR='zcat $f|tee <(grep '"$(echo $STATIONS|sed 's/ \([0-9]\)/>) <(\1/g')"|grep error
  #STR='zcat $f|tee <(grep '"$(echo $STATIONS|sed 's/ \([0-9]\)/>) <(\1/g')"')|grep error
  #eval 'zcat
  #zcat $f|tee <(grep 



exit
# SCRATCH:
DATE_START=197401     # (YYYYMM)
DATE_END=197412       # (YYYYMM)
SEC_END=$(date --utc -d "$DATE_END" +%s)
DATE_CURRENT_START=$START_DATE
DATE_CURRENT_END=$START_DATE
SEC_CURRENT_START=$(date --utc -d "$DATE_CURRENT_START" +%s)
#while [ $SEC_CURRENT_START -lt $SEC_END ]; do
#  $SEC_CURRENT_START=$(date --utc -d "$DATE_CURRENT_START" +%s)
#done
#echo $FILES"
#exit
       

#for i in $@; do
#  ./get_midas_stations.pl


./get_midas_stations.pl midas_glblwx-europe_201001-201012.txt 17103
./get_midas_stations.pl midas_glblwx-europe_201001-201012.txt 17104
./get_midas_stations.pl midas_glblwx-europe_201001-201012.txt 17105
./get_midas_stations.pl midas_glblwx-europe_201001-201012.txt 17106
./get_midas_stations.pl midas_glblwx-europe_201001-201012.txt 19029
./get_midas_stations.pl midas_glblwx-europe_201001-201012.txt 19030
./get_midas_stations.pl midas_glblwx-europe_201001-201012.txt 23547
./get_midas_stations.pl midas_glblwx-europe_201001-201012.txt 23548
./get_midas_stations.pl midas_glblwx-europe_201001-201012.txt 23550
./get_midas_stations.pl midas_glblwx-europe_201001-201012.txt 24238
./get_midas_stations.pl midas_glblwx-europe_201001-201012.txt 24265
./get_midas_stations.pl midas_glblwx-europe_201001-201012.txt 24319
./get_midas_stations.pl midas_glblwx-europe_201001-201012.txt 24320
./get_midas_stations.pl midas_glblwx-europe_201001-201012.txt 24432
#./get_midas_stations.pl midas_glblwx-europe_201001-201012.txt 24403  # EMPTY!!
#./get_midas_stations.pl midas_glblwx-europe_201001-201012.txt 23549  # EMPTY!!
#./get_midas_stations.pl midas_glblwx-europe_201001-201012.txt 24242  # EMPTY!!
#./get_midas_stations.pl midas_glblwx-europe_201001-201012.txt 24298  # EMPTY!!
#./get_midas_stations.pl midas_glblwx-europe_201001-201012.txt 24402  # EMPTY!!
