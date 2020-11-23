#! /bin/bash

# 	load modules
module purge
module load samtools/1.10

#	check that enough input was given
if [ $# -ne 5 ]
then
	printf "%s\n" "ERROR: Expected 5 argument to this bash script." 1>&2
	cleanup "failed"
	exit 1
fi

#	setup variables for the job
INPUT_SAM="${1}"
OUTPUT_BAM="${2}"
TMP_DIR="${3}"
TOTAL_THREADS="${4}"
MEMORY_IN_MB="${5}"
OUTPUT_DIRS=($(readlink -f `dirname "${OUTPUT_BAM}"`))
OUTPUT_DIRS=($(printf "%s\n" "${OUTPUT_DIRS[@]}" | sort | uniq | tr '\n' ' '))
EXTRA_THREADS=$((${TOTAL_THREADS:-2}-2))

# 	check for existence of input file(s)
#		We assume samtools is capable of recognizing whether the
#		file(s) it requires exists.

# 	check for existence of expected output file(s)
if [ -e "${OUTPUT_BAM}" ]
then
	printf "%s\n" "INFO: ${OUTPUT_BAM} already exists! We assume this means we can quit this process without running the intended command. Bye!" 1>&2
	exit 0
fi

#	create output directory(ies), if needed
mkdir -p "${OUTPUT_DIRS[@]}" &> /dev/null
unset OUTPUT_DIRS

#	create tmp directory
mkdir "${TMP_DIR}" &> /dev/null

#	run the program of interest
set -o pipefail
time samtools view \
	-bu \
	-h \
	"${INPUT_SAM}" \
	| samtools sort \
		-@ "${EXTRA_THREADS:-0}" \
		-m "${MEMORY_IN_MB}M" \
		-T "${TMP_DIR}" \
		-O "BAM" \
		-o "${OUTPUT_BAM}" \
		-

EXIT_CODE=$?
set +o pipefail

exit ${EXIT_CODE}

