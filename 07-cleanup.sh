#! /bin/bash

# Ensure we're running from the correct location
CWD_check()
{
	#local SCRIPTS_DIR
	local MAIN_DIR
	local RUN_DIR

	SCRIPTS_DIR=$(readlink -f `dirname "${BASH_SOURCE[0]}"`)
	MAIN_DIR=$(readlink -f `dirname "${SCRIPTS_DIR}/"`)
	RUN_DIR=$(readlink -f .)

	if [ "${RUN_DIR}" != "${MAIN_DIR}" ] || ! [[ "${SCRIPTS_DIR}" =~ ^"${MAIN_DIR}"/scripts.* ]]
	then
		printf "\n\t%s\n\t%s\n\n" "Script must be run from ${MAIN_DIR}" "You are currently at:   ${RUN_DIR}" 1>&2
		exit 1
	fi
}
CWD_check

# #### #
# MAIN #
# #### #

# define key variables
DATA_DIR="data"
ASM_DIR="${DATA_DIR}/assembly"
ALN_DIR="${DATA_DIR}/alns"
MASK="${ALN_DIR}/mask_35_50.fa"

# ###################################### #
# sanity check on input and output files #
# ###################################### #

# check for existence of needed input files
#	Not needed

# check for existence of expected output files
if [ ! -e "${MASK}" ] && [ ! -e "${MASK}.gz" ]
then
	printf "%s\n" "ERROR: Expected output file did not already exist. We won't cleanup until this exists." 1>&2
	exit 1
fi

# #################### #
# actually run the job #
# #################### #

# load the modules
module purge

# run the main command
rm -f "${ASM_DIR}"/split-*.fa* "${ALN_DIR}"/split-*

exit $?

