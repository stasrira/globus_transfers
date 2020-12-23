#!/bin/bash

# set -euo pipefail

# This script will submit Globus transfer requests using a batch file specified in the "batchfile" parameter of the setting file.
# More details on this approach: https://docs.globus.org/cli/reference/transfer/

# Batch file format example (all values are separated with a single space): 
# <source path> <destination path> -r
#
# "<source path>" - absolute path to the source directory to be transfered
# "<destination path>" - path on the destination endpoint where to the directory have to be saved
# "-r" - stands for recurcive; will copy all sub-folders recurcively and create needed structure on the destination

#======================SETTINGS=====================================
# load settings file
. $(dirname "$0")/globus_batch.config

#======================CODE=====================================
# initialize virtual environment for Globus CLI installation (refer to: https://docs.globus.org/cli/installation/virtualenv/)
# Stas' account: "$HOME/.globus-cli-virtualenv/bin/activate"
#source "$HOME/.globus-cli-virtualenv/bin/activate" # this is a user specific installation directory of the Globus CLI
echo "--> activate the virtual environment to run Globus"
echo "$globus_virtual_dir/bin/activate"
source "$globus_virtual_dir/bin/activate"

cd $globus_wrk_dir
echo "--> activate local endpoint"
globus endpoint activate $source_ep #activate source (MSSM) endpoint

# check if the specific name to be processed was provided, if not get all files from the request folder
if [ "$transfer_request_file" == "" ]; then 
	# get list of files in the transfer directory, based on the $SRCH_MAP
	FILES=$(find $globus_transfer_dir -maxdepth 1 -name "$SRCH_MAP")
else
	# check if "$transfer_request_file" exists
	if test -f "$transfer_request_file"; then
		# limit list of files to be processed to the only file provided through the settings
		FILES=$transfer_request_file
	else
		# if the specified file does not exist, exist the script
		echo "Exiting the process! - Cannot locate the specified request file: $transfer_request_file"
		exit 1
	fi
fi

#loop through all files (based on a map) in the given folder (it will not go into the subfolders)
for batchfile in $FILES
do
	echo $batchfile
	
	echo "Batch file selected for processing: $batchfile"
	
	#define name and create a temporary copy of the batch file
	batchfile_tmp=$batchfile"_"$(date +"%Y%m%d_%H%M%S")".tmp"
	echo "--> create a temp copy of the batch file"
	echo cp $batchfile $batchfile_tmp
	cp $batchfile $batchfile_tmp
	
	#to remove Windows line endings 
	sed -i 's/\r$//' "$batchfile_tmp"
	
	# replace destination prefix in the batch file, if it was specified in the file
	echo "--> search for a destination path prefix ($dest_pref_find_str) in the batch file an replace it with the following: $dest_pref_val"
	echo sed -i s+"$dest_pref_find_str"+"$dest_pref_val"+g $batchfile_tmp
	sed -i s+"$dest_pref_find_str"+"$dest_pref_val"+g $batchfile_tmp

	if [ "$transfer_name" == "" ]; then
		tr_name=$(basename $batchfile)
	else
		tr_name=$transfer_name
	fi
	
	echo "--> Transfer name assigned to the request: $tr_name"
	
	echo "--> submit Globus transfer request"
	if [ "$PROD_RUN" == "1" ]; then
		# actual execution
		echo "--> actual execution of the transfer request"
		#globus transfer --label $tr_name --sync-level checksum -v $source_ep $dest_ep --batch < $batchfile_tmp
	else
		# the following line is a dry-run for testing
		echo "--> dry-run execution of the transfer request"
		globus transfer --dry-run --label $tr_name --sync-level checksum -v $source_ep $dest_ep --batch < $batchfile_tmp
	fi
	
	# delete temp file
	echo "--> delete a temp copy of the batch file"
	echo rm $batchfile_tmp
	rm $batchfile_tmp

	# move processed batch file to "processed" folder
	# check if globus_transfer_processed_dir exists, if not, create a new dir
	mkdir -p "$globus_transfer_processed_dir"
	batchfile_processed=$globus_transfer_processed_dir/$(date +"%Y%m%d_%H%M%S")"_"$(basename $batchfile)
	echo "batchfile_processed => "$batchfile_processed
	mv $batchfile $batchfile_processed

done

echo "--> deactivate the virtual environment"
# deactivate virtual environment
deactivate

#check if local Globus endpoint is running

if ( /home/stas/globusconnectpersonal-2.3.8/globusconnectpersonal -status | grep -q "Globus Online:   connected" )
then
	echo "--> Local Globus endpoint is already running, no action is needed."
else
	echo "--> Local Globus endpoint is not running. Starting local Globus endpoint"
	echo $start_local_endpoint
	eval "$start_local_endpoint"
fi

#/home/stas/globusconnectpersonal-2.3.8/globusconnectpersonal -start -restrict-paths rw/ext_data/shared/ECHO,rw/data/stas,rw/home/stas &



