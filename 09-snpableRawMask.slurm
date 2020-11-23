#! /bin/bash

# LOAD MODULES, INSERT CODE, AND RUN YOUR PROGRAMS HERE

#	Some handy variables
#${SLURM_MEM_PER_CPU}
#${SLURM_MEM_PER_NODE}
#${SLURM_JOB_NAME}
#${SLURM_NTASKS}
#${SLURM_JOB_NUM_NODES}
#${SLURM_JOB_ID}

if [ -n "$SLURM_JOB_ID" ] # basically, if this is managed by slurm vs being run locally
then
	if [ -n "$SLURM_JOB_NUM_NODES" ] && [ $SLURM_JOB_NUM_NODES -ne 1 ]
	then
		printf "%s\n" "This job is meant to be run with a single node" 1>&2
		exit 1
	elif [ -n "$SLURM_MEM_PER_CPU" ]
	then
		MEM_TASK_IN_MB=${SLURM_MEM_PER_CPU}
		MEM_JOB_IN_MB=$((${MEM_TASK_IN_MB}*${SLURM_NTASKS}))
		MEM_JOB_IN_GB=$((${MEM_JOB_IN_MB}/1024))
	elif [ -n "$SLURM_MEM_PER_NODE" ]
	then
		MEM_JOB_IN_MB=$((${SLURM_MEM_PER_NODE}*${SLURM_JOB_NUM_NODES}))
		MEM_JOB_IN_GB=$((${MEM_JOB_IN_MB}/1024))
		MEM_TASK_IN_MB=$(bc <<< "${MEM_JOB_IN_MB}/${SLURM_NTASKS}")
	else
		printf "%s\n" '$SLURM_MEM_PER_NODE and $SLURM_MEM_PER_CPU not specificed.' 1>&2
		exit 1
	fi
fi

#	move into the correct place
if [ -n "${SLURM_SUBMIT_DIR}" ]
then
	cd "$SLURM_SUBMIT_DIR"
else
	SLURM_SUBMIT_DIR=.
fi

#	manage job cleanup
cleanup()
{
	# cleanup tmp dir
	if [ -n $SLURM_JOB_ID ] && [ -e /tmp/${SLURM_JOB_ID} ]
	then
		rm -rf /tmp/${SLURM_JOB_ID} &> /dev/null
	elif [ -e /tmp/${$} ]
	then
		rm -rf /tmp/${$} &> /dev/null
	fi
}

control_c()
{
	cleanup
	exit 1
}

trap control_c SIGHUP SIGINT SIGTERM SIGQUIT

# 	load modules
module purge
module load samtools/1.10
module load snpable/20091110

#	setup variables for the job
EXTRA_THREADS=$((${SLURM_NTASKS:-2}-2))
INPUT_BAM="${1}"
RAW_MASK_FILE="${2}"
OUTPUT_DIR=$(readlink -f `dirname "${RAW_MASK_FILE}"`)

# 	check for existence of input file(s)
#		We assume samtools/snpable are capable of recognizing whether the
#		files they require exist.

# 	check for existence of expected output file(s)
if [ -e "${RAW_MASK_FILE}" ]
then
	printf "%s\n" "INFO: ${RAW_MASK_FILE} already exists! We assume this means we can quit this process without running the intended command. Bye!" 1>&2
	cleanup
	exit 0
fi

#	create output directory, if needed
mkdir -p "${OUTPUT_DIR}" &> /dev/null

#	run the program of interest
time samtools view \
	-h \
	-@ "${EXTRA_THREADS:-0}" \
	-O "SAM" \
	"${INPUT_BAM}" \
	| gen_raw_mask.pl \
	> "${RAW_MASK_FILE}"

EXIT_CODE=$?

#	cleanup and exit
if [ ${EXIT_CODE} -eq 0 ]
then
	chmod 444 "${RAW_MASK_FILE}" &> /dev/null
else
	rm -f "${RAW_MASK_FILE}" &> /dev/null
fi

cleanup

exit ${EXIT_CODE}

# Usage: gen_raw_mask.pl <bwa.sam>

#Usage: samtools view [options] <in.bam>|<in.sam>|<in.cram> [region ...]
#
#Options:
#  -b       output BAM
#  -C       output CRAM (requires -T)
#  -1       use fast BAM compression (implies -b)
#  -u       uncompressed BAM output (implies -b)
#  -h       include header in SAM output
#  -H       print SAM header only (no alignments)
#  -c       print only the count of matching records
#  -o FILE  output file name [stdout]
#  -U FILE  output reads not selected by filters to FILE [null]
#  -t FILE  FILE listing reference names and lengths (see long help) [null]
#  -X       include customized index file
#  -L FILE  only include reads overlapping this BED FILE [null]
#  -r STR   only include reads in read group STR [null]
#  -R FILE  only include reads with read group listed in FILE [null]
#  -d STR:STR
#           only include reads with tag STR and associated value STR [null]
#  -D STR:FILE
#           only include reads with tag STR and associated values listed in
#           FILE [null]
#  -q INT   only include reads with mapping quality >= INT [0]
#  -l STR   only include reads in library STR [null]
#  -m INT   only include reads with number of CIGAR operations consuming
#           query sequence >= INT [0]
#  -f INT   only include reads with all  of the FLAGs in INT present [0]
#  -F INT   only include reads with none of the FLAGS in INT present [0]
#  -G INT   only EXCLUDE reads with all  of the FLAGs in INT present [0]
#  -s FLOAT subsample reads (given INT.FRAC option value, 0.FRAC is the
#           fraction of templates/read pairs to keep; INT part sets seed)
#  -M       use the multi-region iterator (increases the speed, removes
#           duplicates and outputs the reads as they are ordered in the file)
#  -x STR   read tag to strip (repeatable) [null]
#  -B       collapse the backward CIGAR operation
#  -?       print long help, including note about region specification
#  -S       ignored (input format is auto-detected)
#  --no-PG  do not add a PG line
#      --input-fmt-option OPT[=VAL]
#               Specify a single input file format option in the form
#               of OPTION or OPTION=VALUE
#  -O, --output-fmt FORMAT[,OPT[=VAL]]...
#               Specify output format (SAM, BAM, CRAM)
#      --output-fmt-option OPT[=VAL]
#               Specify a single output file format option in the form
#               of OPTION or OPTION=VALUE
#  -T, --reference FILE
#               Reference sequence FASTA FILE [null]
#  -@, --threads INT
#               Number of additional threads to use [0]
#      --write-index
#               Automatically index the output files [off]
#      --verbosity INT
#               Set level of verbosity

