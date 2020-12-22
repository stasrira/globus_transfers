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

#define name and create a temporary copy of the batch file
batchfile_tmp=$batchfile".tmp"
echo "--> create a temp copy of the batch file"
echo cp $batchfile $batchfile_tmp
cp $batchfile $batchfile_tmp

# replace destination prefix in the batch file, if it can be found
echo "--> search for a destination path prefix ($dest_pref_find_str) in the batch file an replace it with the following: $dest_pref_val"
echo sed -i s+"$dest_pref_find_str"+"$dest_pref_val"+g $batchfile_tmp
sed -i s+"$dest_pref_find_str"+"$dest_pref_val"+g $batchfile_tmp

echo "--> submit Globus transfer request"
# the following line is a dry-run for testing
#globus transfer --dry-run --label $transfer_name --sync-level checksum -v $source_ep $dest_ep --batch < $batchfile_tmp

# actual execution
globus transfer --label $transfer_name --sync-level checksum -v $source_ep $dest_ep --batch < $batchfile_tmp

#delete temp file
echo "--> delete a temp copy of the batch file"
echo rm $batchfile_tmp
rm $batchfile_tmp

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



