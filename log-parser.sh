#!/bin/bash

###################################################################################
#
#  This script parses logs from a Cisco ASA with a txt or .gz source file
#  and outputs to a CSV file listing the device IP, source IP, protocol name,
#  destination IP and destination port.
#
#  Usage:
#  
#  Usage: log-parser.sh
#	-a append output to an existing file (default setting creates a new output file)
#	-f <filename> accepts multiple .txt or .gz files (required)
#	-o <output-filename> csv is the default output (required)
#
#  User editable areas defined below to adjust filters for an access-list,
#  IP addresses and destination ports
#
#  Created by cwest@optum.com
#  last modifed - 200714
#
###################################################################################



################################# USER EDITABLE AREA ##############################



# Define an access-list with interesting traffic (case sensitive)

acl=INSIDE_access_in


# Define the interface to isolate
int=OUTSIDE


# Define IP addresses to exclude (comma separated values)

ip='10.36.198.100,10.100.100.5,10.100.100.7,10.141.85.58,10.141.85.59,10.141.85.62,10.191.0.13,203.0.113.250'


# Define destination ports to exclude (comma separated values)

port='80,443'



############################ END OF USER EDITABLE AREA ############################



############## DO NOT EDIT BELOW UNLESS YOU KNOW WHAT YOU'RE DOING ################

# Define functions

# Usage information
usage(){
    echo -e "Usage: log-parser.sh"
    echo -e "       -a append output to an existing file (default setting creates a new output file)"
    echo -e "       -f <filename> accepts multiple .txt or .gz (required)"
    echo -e "       -o <output-filename> csv is the default output (required)\n"
}

# Remove duplicates and clean up
cleanup(){
    if [ -f "$tmp" ]; then
        echo -n "Cleaning up ... "
        cat $tmp | awk '!a[$0]++' >> $out && rm $tmp
        echo -e "COMPLETE"        
    fi
}

# Setting the options
while getopts ":f:o:a" opt; do
    case ${opt} in
        f )
            file+=("$OPTARG")
            while [ "$OPTIND" -le "$#" ] && [ "${!OPTIND:0:1}" != "-" ]; do 
                file+=("${!OPTIND}")
                OPTIND="$(expr $OPTIND \+ 1)"
            done ;;
        o )
            out=$OPTARG ;;
        a )
            append=1 ;;
        \? )
            echo "Invalid option: $OPTARG" 1>&2
            usage
            exit 0 ;;
        : )
            echo "Invalid option: -$OPTARG requires an argument" 1>&2
            usage
            exit 0 ;;
    esac
done

# Error checking
if [ -z "$file" ] || [ -z "$out" ]; then
    echo -e "Check your input and/or output files ... FAIL"
    usage
    exit 0
elif [ "$OPTIND" -eq "1" ] || [ "$OPTIND" -le "$#" ]; then
    usage
    exit 0
fi

#  Set variables and manipulate the data for the script
tmp=$out.tmp
exclude_ip=$(echo "$ip" | sed 's/,/\\|/g')
exclude_port=$(echo \($port | sed 's/,/\) h\\\|\(/g')\)\ h
excludes="$exclude_ip"\\\|"$exclude_port"
counter=0

# Main script with loop for multiple files
for file in "${file[@]}"; do
    counter=$[counter + 1]
    if [ -f "$file" ] && [[ $file == *.gz ]]; then
        engine=gzcat
    elif [ -f "$file" ]; then
        engine=cat
    else
        echo -e "There is a problem with the source file ... FAIL"
        cleanup
        exit 0
    fi
    if [ "$counter" = 1 ] && [ "$append" != 1 ]; then       
        echo -n "Creating new output file ... "
        echo -e "Device,Src IP,Protocol,Dst IP,Dst Port" > $tmp
        if [ -f "$out" ]; then
            rm $out
        fi
        touch $out
        echo -e "DONE"
    fi
    echo -n "Processing log file $counter ... "
    $engine $file | grep $acl | grep $int | grep 'hit-cnt 1' |  grep -v "$excludes" |  awk '{ print $4,$9,$10,$12 }' |  sed -E -e 's/INSIDE\/|OUTSIDE\/|OUTSIDE1\/|\)//g' | sed -E -e 's/ |\(/,/g' | awk -F, '{ print $1,$3,$2,$5,$6 }' | sed -E -e 's/ /,/g' | awk '!a[$0]++' >> $tmp
    echo -e "SUCCESS!"
done

# Tidy up
cleanup