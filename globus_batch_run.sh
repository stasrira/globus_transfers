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
# get the first argument value into a variables

echo "The first argument provided =>" $1

cnf_fl=$1
#echo $cnf_fl

if [ "$cnf_fl" == "" ] ; then
	echo "The first argument provided was blank. This a required argument that provides a path to the config file. Aborting execution!"
	exit 1
fi

#check if provided config file exists
if test -f "$cnf_fl"; then
	# load config file
	echo "Attempting to load config file: $cnf_fl"
	if source $cnf_fl ;then
		echo "Config file ($cnf_fl) was successfully loaded."
	else
		echo "Error occured during loading the config file. Aborting execution!"
		exit 1
	fi
else
	echo "Provided config file ($cnf_fl) does not exist or cannot be accessed. Aborting execution!"
	exit 1
fi

#for testing only
#echo $globus_log_dir
#exit 0

#. $(dirname "$0")/globus_batch.config #old way of loading a config file

#======================CODE=====================================

# setup Loging related variables

#if Logging directory is not provided, set it to the "logs" sub-folder created in the directory where the script is located
if [ "$globus_log_dir" == "" ] ; then
	globus_log_dir=$(dirname "$0")/logs
fi

# check if globus_log_dir exists, if not, create a new dir
mkdir -p "$globus_log_dir"
# define a log file for the current run
GLB_LOG_FILE=$globus_log_dir/$(date +"%Y%m%d_%H%M%S")"_globus_transf_log.txt"
echo "Log file for the current run is: "$GLB_LOG_FILE

echo "$(date +"%Y-%m-%d %H:%M:%S")-->Starting the process"  | tee -a "$GLB_LOG_FILE"
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
		#echo "Exiting the process! - Cannot locate the specified request file: $transfer_request_file"
		echo "$(date +"%Y-%m-%d %H:%M:%S")-->Exiting the process! - Cannot locate the specified request file: "$transfer_request_file  | tee -a "$GLB_LOG_FILE"
		exit 1
	fi
fi

echo "$(date +"%Y-%m-%d %H:%M:%S")-->Start processing files: "$FILES  | tee -a "$GLB_LOG_FILE"

# check if there are any files to be processed
if [ "$FILES" == "" ]; then
	# if the specified file does not exist, exist the script
	echo "$(date +"%Y-%m-%d %H:%M:%S")-->Exiting the process! - No files available for processing"  | tee -a "$GLB_LOG_FILE"
	exit 1
fi

# initialize virtual environment for Globus CLI installation (refer to: https://docs.globus.org/cli/installation/virtualenv/)
# Stas' account: "$HOME/.globus-cli-virtualenv/bin/activate"
#source "$HOME/.globus-cli-virtualenv/bin/activate" # this is a user specific installation directory of the Globus CLI
echo "$(date +"%Y-%m-%d %H:%M:%S")-->Activate the virtual environment to run Globus; command: $globus_virtual_dir/bin/activate"  | tee -a "$GLB_LOG_FILE"
source "$globus_virtual_dir/bin/activate"

# cd $globus_wrk_dir
echo "$(date +"%Y-%m-%d %H:%M:%S")-->Activate local endpoint; command: globus endpoint activate $source_ep"  | tee -a "$GLB_LOG_FILE"
globus endpoint activate $source_ep #activate source (MSSM) endpoint

#loop through all files (based on a map) in the given folder (it will not go into the subfolders)
for batchfile in $FILES
do
	echo "" | tee -a "$GLB_LOG_FILE"
	echo "$(date +"%Y-%m-%d %H:%M:%S")-->Batch file selected for processing: $batchfile" | tee -a "$GLB_LOG_FILE"
	
	#define name and create a temporary copy of the batch file
	batchfile_tmp=$batchfile"_"$(date +"%Y%m%d_%H%M%S")".tmp"
	echo "$(date +"%Y-%m-%d %H:%M:%S")-->Create a temp copy of the batch file; command: cp $batchfile $batchfile_tmp"  | tee -a "$GLB_LOG_FILE"
	cp $batchfile $batchfile_tmp
	
	#to remove Windows line endings 
	sed -i 's/\r$//' "$batchfile_tmp"
	
	# replace destination prefix in the batch file, if it was specified in the file
	echo "$(date +"%Y-%m-%d %H:%M:%S")-->Search for a destination path prefix ($dest_pref_find_str) in the batch file an replace it with the following: $dest_pref_val."  | tee -a "$GLB_LOG_FILE"
	sed -i s+"$dest_pref_find_str"+"$dest_pref_val"+g $batchfile_tmp

	if [ "$transfer_name" == "" ]; then
		tr_name=$(basename $batchfile)
		#echo $tr_name
		tr_name="${tr_name//'.'/'_'}" # remove any "." from the name, since Globus rejects names with the dots.
		#echo $tr_name
	else
		tr_name=$transfer_name
	fi
	
	echo "$(date +"%Y-%m-%d %H:%M:%S")-->Transfer name assigned to the request: $tr_name"  | tee -a "$GLB_LOG_FILE"
	
	if [ "$PROD_RUN" == "1" ]; then
		# actual execution
		echo "$(date +"%Y-%m-%d %H:%M:%S")-->Proceeding with actual execution of the transfer request to the Globus site"  | tee -a "$GLB_LOG_FILE"
		globus transfer --label $tr_name --sync-level checksum -v $source_ep $dest_ep --batch < $batchfile_tmp 2>&1 | tee -a "$GLB_LOG_FILE"
	else
		# the following line is a dry-run for testing
		echo "$(date +"%Y-%m-%d %H:%M:%S")-->Proceeding with dry-run execution of the transfer request (no actual submission to the Globus site)"  | tee -a "$GLB_LOG_FILE"
		globus transfer --dry-run --label $tr_name --sync-level checksum -v $source_ep $dest_ep --batch < $batchfile_tmp 2>&1 | tee -a "$GLB_LOG_FILE"
	fi
	
	echo "" | tee -a "$GLB_LOG_FILE"
	
	# delete temp file
	echo "$(date +"%Y-%m-%d %H:%M:%S")-->Delete a temp copy of the batch file; command: rm $batchfile_tmp"  | tee -a "$GLB_LOG_FILE"
	rm $batchfile_tmp

	if [ "$PROD_RUN" == "1" ]; then
		# move processed batch file to "processed" folder
		# check if globus_transfer_processed_dir exists, if not, create a new dir
		mkdir -p "$globus_transfer_processed_dir"
		batchfile_processed=$globus_transfer_processed_dir/$(date +"%Y%m%d_%H%M%S")"_"$(basename $batchfile)
		echo "$(date +"%Y-%m-%d %H:%M:%S")-->Move/rename the processed file "$(basename $batchfile)"; command: mv $batchfile $batchfile_processed"  | tee -a "$GLB_LOG_FILE"
		mv $batchfile $batchfile_processed
	else
		echo "$(date +"%Y-%m-%d %H:%M:%S")-->Move/rename of the processed file "$(basename $batchfile)" won't be performed, since this is a dry-run."  | tee -a "$GLB_LOG_FILE"
	fi
done

echo "$(date +"%Y-%m-%d %H:%M:%S")-->Deactivate the virtual environment"  | tee -a "$GLB_LOG_FILE"
# deactivate virtual environment
deactivate

#check if local Globus endpoint is running

if ( /home/stas/globusconnectpersonal-2.3.8/globusconnectpersonal -status | grep -q "Globus Online:   connected" )
then
	echo "$(date +"%Y-%m-%d %H:%M:%S")-->Checking status of local Globus endpoint - it is already running, no action is needed"  | tee -a "$GLB_LOG_FILE"
else
	echo "$(date +"%Y-%m-%d %H:%M:%S")-->Checking status of local Globus endpoint - it is not running. Starting local Globus endpoint; command: $start_local_endpoint"  | tee -a "$GLB_LOG_FILE"
	eval "$start_local_endpoint"
fi

echo "$(date +"%Y-%m-%d %H:%M:%S")-->The process has finished"  | tee -a "$GLB_LOG_FILE"
