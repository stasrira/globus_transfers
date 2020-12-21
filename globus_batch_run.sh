# This script will submit Globus transfer requests using a batch file specified in the "batchfile" parameter.
# More details on this approach: https://docs.globus.org/cli/reference/transfer/
# Batch file format example: <source path> <destination path> -r
# "<source path>" - absolute path to the source directory to be transfered
# "<destination path>" - path on the destination endpoint where to the directory have to be saved
# "-r" - stands for recurcive; will copy all sub-folders recurcively and create needed structure on the destination
#======================SETTINGS=====================================
# verify the following settings before each transfer
transfer_name=Transfer_20201221_set1 #custom name of the transfer to make it easier to find it in the Activity section of the Globus site
batchfile=./globus_transfers/princenton_globus_batch_20201221_set1.txt #name of the batch file to be used for the current run

# Existing endpoint ids
# 24a98536-4202-11ea-9712-021304b0cca7 #Princeton lSI DTN endpoint
# Specify destination endpoint id
dest_ep=24a98536-4202-11ea-9712-021304b0cca7 #Princeton lSI DTN endpoint 

#local directory and endpoint
globus_wrk_dir=/ext_data/shared/.apps/globus_submissions #
source_ep=a2cc0b26-46aa-11ea-b967-0e16720bb42f


#======================CODE=====================================
#initialize virtual environment for Globus CLI installation (refer to: https://docs.globus.org/cli/installation/virtualenv/)
# Stas account: "$HOME/.globus-cli-virtualenv/bin/activate"
source "$HOME/.globus-cli-virtualenv/bin/activate" # this is a user specific installation directory of the Globus CLI

cd $globus_wrk_dir
globus endpoint activate $source_ep #activate source (MSSM) endpoint

#the following line is a dry-run for testing
#globus transfer --dry-run --label $transfer_name --sync-level checksum -v $source_ep $dest_ep --batch < $batchfile

#actual execution
globus transfer --label $transfer_name --sync-level checksum -v $source_ep $dest_ep --batch < $batchfile

#deactivate virtual environment
deactivate