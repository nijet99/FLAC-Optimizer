#!/bin/bash

#################################################################################
#                                                                               #
# Copyright (C) 2010, FLAC-Optimizer team                                       #
#                                                                               #
# FLAC-Optimizer is free software: you can redistribute it and/or modify        #
# it under the terms of the GNU General Public License as published by          #
# the Free Software Foundation, either version 3 of the License, or             #
# (at your option) any later version.                                           #
#                                                                               #
# FLAC-Optimizer is distributed in the hope that it will be useful,             #
# but WITHOUT ANY WARRANTY; without even the implied warranty of                #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the                  #
# GNU General Public License for more details.                                  #
#                                                                               #
# You should have received a copy of the GNU General Public License             #
# along with FLAC-Optimizer. If not, see <http://www.gnu.org/licenses/>.        #
#                                                                               #
#################################################################################



#################################################################################
#                              DEFINE VARIABLES                                 #
#################################################################################



# Define the path from where you want to search for flac files/folders
# Trailing slash required
source="/tmp/FLAC/"

# Define the path from where you want save the optimized flacs and files to
# Trailing slash required
destination="/tmp/test/"

# Define the further files types that you also want to copy
# All other files that are not flacs and none of the file types below will not get copied over
file_arr[1]="jpg"
file_arr[2]="bmp"
file_arr[3]="gif"
file_arr[4]="png"
file_arr[5]="cue"
file_arr[6]="log"

# Define the compression rate from 1 to 8 where 8 is highest compression
compression="8"

# Do you want to add replay gain? Set 1 to add replay gain, set 0 to not add it.
# Currently, replay gain can't be added to flacs recorded at 96khz
replaygain="1"

# Set seekpoints at X seconds. The value can also be a float. Set it to 0 to not add seekpoints.
seekpoint="0.5"

# Remove embedded pictures? Set 1 for removing
removepic="1"

# Remove existing tags. Set the value to 0 to empty/remove the according tag. All other tags will be added to the new file
# Do not alter this in any way but setting values of 0 and 1.
tag_arr[1]="1"    #TITLE
tag_arr[2]="0"    #ARTIST
tag_arr[3]="1"    #ALBUM
tag_arr[4]="1"    #DISCNUMBER
tag_arr[5]="1"    #DATE
tag_arr[6]="1"    #TRACKNUMBER
tag_arr[7]="1"    #TRACKTOTAL
tag_arr[8]="1"    #GENRE
tag_arr[9]="1"    #DESCRIPTIONS
tag_arr[10]="1"    #COMMENT
tag_arr[11]="1"    #COMPOSER
tag_arr[12]="1"    #PERFORMER
tag_arr[13]="1"    #COPYRIGHT
tag_arr[14]="1"    #LICENCE
tag_arr[15]="1"    #ENCODEDBY
#### The replay gain tags will be auto-overwritten if the replay gain option is enabled. Use the following tags only to delete the tags
tag_arr[16]="1"    #REPLAYGAIN REFERENCE LOUDNESS
tag_arr[17]="1"    #REPLAYGAIN TRACK GAIN
tag_arr[18]="1"    #REPLAYGAIN_TRACK_PEAK
tag_arr[19]="1"    #REPLAYGAIN_ALBUM_GAIN
tag_arr[20]="1"    #REPLAYGAIN_ALBUM_PEAK



#################################################################################
#                             DEFINE USER FUNCTIONS                             #
#                               do not edit below                               #
#################################################################################



# Build the second array for the tag list array so that a value in tag_arr can be matched to an actual tag
tag_val[1]="TITLE"
tag_val[2]="ARTIST"
tag_val[3]="ALBUM"
tag_val[4]="DISCNUMBER"
tag_val[5]="DATE"
tag_val[6]="TRACKNUMBER"
tag_val[7]="TRACKTOTAL"
tag_val[8]="GENRE"
tag_val[9]="DESCRIPTION"
tag_val[10]="COMMENT"
tag_val[11]="COMPOSER"
tag_val[12]="PERFORMER"
tag_val[13]="COPYRIGHT"
tag_val[14]="LICENCE"
tag_val[15]="ENCODEDBY"
#### Replay gain Tags
tag_val[16]="REPLAYGAIN REFERENCE LOUDNESS"
tag_val[17]="REPLAYGAIN_TRACK_GAIN"
tag_val[18]="REPLAYGAIN_TRACK_PEAK"
tag_val[19]="REPLAYGAIN_ALBUM_GAIN"
tag_val[20]="REPLAYGAIN_ALBUM_PEAK"


# determine maximal number of parallel jobs and add 1
maxnum=`grep -c '^processor' /proc/cpuinfo`
maxnum=$(($maxnum+1))

# enable ctrl-c abort
control_c()
{
    for f in `jobs -p`; do
        kill $f 2> /dev/null
    done
    wait
    exit $?
}
trap control_c SIGINT

function check_exit_codes
{
    local ps=${PIPESTATUS[*]}
    local args=( `echo $@` )
    local i=0
    for s in $ps
    do
        if [ $s -ne 0 ]
        then
            echo "WARNING: Return code of ${args[$i]} indicates failure"
            break
        fi
        let i=$i+1
    done
}


function optimize_flacs
{
    # getting the parameters
    flacfile="$1"
    source="$2"
    destination="$3"
    compression="$4"
    replaygain="$5"
    seekpoint="$6"
    removepic="$7"
    tag_arr="$8"
    tag_val="$9"


    # build the options list for conversion
    co_opt="-$compression"
    
    if [ "$replaygain" = "1" ]
    then
        rg_opt="--replay-gain"
    fi
    
    if [ "$seekpoint" = "0" ]
    then
        sp_opt="--no-seektable"
    else
        s="s"
        sp_opt="-S $seekpoint$s"
    fi

    options="$co_opt $rg_opt $sp_opt"

    nice flac $options -o "$destination$flacfile" "$source$flacfile"

    # run metaflac to remove pics and unwanted tags
    if [ "$removepic" = "1" ]
    then
        rp_opt="--remove --block-type=PICTURE --dont-use-padding"
    fi

    for (( i = 1 ; i < ${#tag_arr[@]} ; i++ ))
    do
        check="${tag_arr[$i]}"
        if [ "$check" = "0" ]
        then
            f="${tag_val[$i]}"
            tag_opt="$tag_opt --remove-field=$f"
        fi
    done

    options="1--- $rp_opt $tag_opt"

    nice metaflac $rp_opt "$destination$flacfile"

}



#################################################################################
#                                 SCRIPT CONTROL                                #
#                               do not edit below                               #
#################################################################################



echo "Starting the flacconvert script..."


# if the flac folder does not exist, skip completely as nothing can be converted
if [ -d "$source" ]
then

    # go to the source directory
    cd "$source"


    # create folder structure
    nice find -type d | grep -v '^\.$' | while read folder
    do
        # change destination path
        mkdir -p "$destination$folder"
    done


    # copy desired non-flac files
    for ext in ${file_arr[@]}
    do
        # sleep while max number of jobs are running
        until ((`jobs | wc -l` < maxnum)); do
            sleep 1
        done
        echo "... copying $ext files..."
        nice find . -iname "*.$ext" | while read extfile
        do
            cp -a -u "$extfile" "$destination$extfile"
        done
    done


    # find all flac files and pass them on to the actual convert script
    nice find . -iname '*.flac' | while read flacfile
    do
        # sleep while max number of jobs are running
        until ((`jobs | wc -l` < maxnum)); do
            sleep 1
        done
    
        # run optimize_flacs function
        optimize_flacs "$flacfile" "$source" "$destination" "$compression" "$replaygain" "$seekpoint" "$removepic" "$tag_arr" "$tag_val"
    done


    echo "... optimization of flac files finished."
fi

echo "Done!"
