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

#-- BEGIN PRESETS --#
data_dirs=" ./neurope1
            ./neurope2"
#data_dirs=" ./wsm3
#            ./wsm5
#            ./wsm6
#            ./thompson"
path_midas='"$HOME/data/obs/midas"'
domains="d02"   # currently only supports one entry
start_date="2010-01-02"
end_date="2010-01-30"
times_midas='@(00|03|06|09|12|15|18|21)'  # MIDAS observation times
#--  END PRESETS  --#

# Local variables:
NCLlist="./auto_presets.ncl"   # used in plot_taylor.ncl

# Prepare the working directory
echo "Checking for old file list in working directory"
echo "Backing up old files"
    # backup lists of wrf files
for i in  ./file_list_wrf*.txt
do
    mv $i $i.bak
done
    # backup midas data files
for i in $path_midas/midas_[0-9][0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9].dat
do                                      # e.g. midas_12345_6789.dat
    mv $i $i.bak
done
    # backup automatically created NCL-script
if [ -e ./$NCLlist ]; then
    mv ./$NCLlist ./$NCLlist.bak  # ask for permission to remove old ncl list script
fi
echo "Directory is clean from old files, moving on"

echo "Searching for WRF data"
fnames=""   # Will be filled with a list of list files (lists within lists!)
for current_dir in $data_dirs  # For each data set (wrf model run)
do  
    # Get the name of the current data set (based on folder name)
    # We don't want the complete path, only the name of the last folder
    # (if the path is '/path/to/set' we will set the name to 'set' )
    name=$(echo $current_dir | rev | sed 's/\/.*//' | rev)
        # What we do:
        # echo prints $current_dir (e.g. '/path/to/set') to the pipe.
        # rev reverses the output ('/path/to/set' becomes 'tes/ot/htap/')
        # sed looks for the first occurence of '/' ('\/') and all characters
        # thereafter ('.*'), which in this case would be '/ot/htap/',
        # and replaces the entire match with '' (nothing) so that
        # 'tes/ot/htap/' becomes 'tes'.
        # the last rev once again reverses the output and we get 'set',
        # which is stored in $name.
    echo $name

    # The name of the list file to be created:
    fname='file_list_wrf_'$name'.txt'
    fnames=$fnames" "$fname # append current filename to list of lists
                            # the " " will not be added in the first iteration
                            # of the loop, due to bash's handling of white spaces
                            # We will take advantage of this later on

    # The following script will print a list of the matching data files to an ascii file
    ./list_wrf_files.sh $current_dir $domains $start_date $end_date $times_midas \
      > 'file_list_wrf_'$name'.txt'

done
echo "list of lists:"
echo $fnames

# THE FOLLOWING COMMENTED OUT SECTION COULD BE MOVED TO ANOTHER SCRIPT IN A LATER VERSION
# SO FAR HOWEVER, IT IS UNFINISHED AND WILL NOT BE RUN!
# Now we want to prepare the midas data sets for the comparison
#match_1=$(echo $start_date | sed 's/-/,/g')',00'    # where midas series should begin
#match_2=$(echo   $end_date | sed 's/-/,/g')',21'    # and end
        # Here, sed replaces '-' with',' which is used in the midas files
        # the tailing numbers are the the start/end times in (HH)

#for i in $path_midas/midas_[0-9][0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9].dat
    # extract filenames (same as before but add a suffix)
#    name=$(echo $current_dir | rev | sed 's/\/.*//' | rev)
    
#        cat $i | sed -n '/'$3'_00/,/'$4'_21/p'         \


# We finish off by writing a quick NCL script with the list-files defined natively
#   (easier than sending attributes to a ncl script when run from bash)
    # We want the following layout:
        # lists = (/ file1.txt, file2.txt, file3.txt \)
    # To fix this we must re-write the list of lists which currently looks like:
        # fnames = "file1.txt file2.txt file3.txt"
  ncl_line=$( echo $fnames | sed 's/ /", "/g')    # Add ', ' between each pair of files
                                                  # and adds some quoute marks (")
                                                  # (replaces every ' ' with '", "')
  ncl_line='LISTS = (/ "'$ncl_line'" /)'  # Add beginning and end of line
  #echo $ncl_line
  ncl_startdate=$( echo $start_date | sed 's/-/, /g')  # Convert date 'y, m, d'
  ncl_line=$ncl_line'\nSTART_DATE = (/ '$ncl_startdate' /)' # add line to $ncl_line
  #echo -e $ncl_line
  ncl_enddate=$( echo $end_date   | sed 's/-/, /g')   # Convert date 'y, m, d'
  #echo -e $ncl_enddate
  ncl_line=$ncl_line'\nEND_DATE   = (/ '$ncl_enddate' /)'   # add line to $ncl_line
  #echo -e $ncl_line
  ncl_line=$ncl_line'\nMIDAS_ROOT = '$path_midas    # add line to $ncl_line
  # Change | to , and @(...) to (/.../) using sed:
  ncl_midas_times=$(echo $times_midas | sed 's/|/,/g' | sed 's;@(\(.*\));(/\1/);g')  
  ncl_line=$ncl_line'\nTIMES = '$ncl_midas_times
  ncl_names_test=$(echo $data_dirs | sed 's;./;";g' | sed 's; ;", ;g')
  ncl_line=$ncl_line'\nNAMES_TEST = (/ '$ncl_names_test'" /)'

  echo -e '\nContents of '$NCLlist':'
  echo -e $ncl_line

    # Print header:
    echo "; Script automatically generated by compare_wrf_midas.sh" > $NCLlist
    echo "; will be run by plot_taylor.ncl to read the presets defined"  >>$NCLlist
    echo "; by the user in compare_wrf_midas.sh" >>$NCLlist
    #echo "; compare_wrf_midas.sh will automatically call plot_taylor.ncl"   >>$NCLlist
    echo "; running compare_wrf_midas.sh will ensure up to date file lists" >>$NCLlist
    # Print function
    echo -e $ncl_line >> $NCLlist

# Run ncl script for data comparision:
# ncl plot_taylor.ncl #script is not finished yet!
