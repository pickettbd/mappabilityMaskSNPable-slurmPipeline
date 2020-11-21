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
KMER_SIZE=35
LINES_PER_SPLIT_FASTA_FILE=20000000
DATA_DIR="data"
ASM_DIR="${DATA_DIR}/assembly"
ASM_PATH="${ASM_DIR}/asm.fa"
#ASM_BASE="`basename ${ASM_PATH%%.fa*}`"

# define key variables
INPUT_FILES=("${ASM_PATH}")

# ###################################### #
# sanity check on input and output files #
# ###################################### #

EXIT_EARLY=0

# check for existence of needed input files
for INPUT_FILE in "${INPUT_FILES[@]}"
do
	if [ ! -e "${INPUT_FILE}" ]
	then
		printf "%s\n" "ERROR: Required input file does not exist: ${INPUT_FILE}" 1>&2
		EXIT_EARLY=1
	fi
done

# check for existence of expected output files
EXISTING_OUTPUT_FILES=`find "${ASM_DIR}" -mindepth 1 -maxdepth 1 -type f -name 'split-*.fa' | wc -l`
if [ ${EXISTING_OUTPUT_FILES} -gt 0 ]
then
	printf "%s\n\t%s\n" "ERROR: Expected output file(s) already exist(s). If you wish to proceed anyway, please remove it/them:" "rm -f ${ASM_DIR}/split-*.fa" 1>&2
	EXIT_EARLY=1
fi

# exit without submitting the job, if needed
if [ $EXIT_EARLY -ne 0 ]
then
	exit ${EXIT_EARLY}
fi

# #################### #
# actually run the job #
# #################### #

# load the modules
module purge
module load snpable/20091110
module load perl/5.30.0
module load perlmodules/5.30.0/File-Rename/1.10

set -o pipefail
time splitfa  \
	"${ASM_PATH}" \
	"${KMER_SIZE}" \
	| split \
		-a 8 \
		-l ${LINES_PER_SPLIT_FASTA_FILE} \
		--numeric-suffixes=1 \
		--additional-suffix=".fa" \
		'-' \
		"${ASM_DIR}/split-"

EXIT_CODE=$?
set +o pipefail

if [ $EXIT_CODE -eq 0 ]
then
	rename -e 's/(split-)0+/$1/' "${ASM_DIR}/split-"*
	EXIT_CODE=$?
fi

exit ${EXIT_CODE}

