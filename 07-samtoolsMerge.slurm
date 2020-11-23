#! /bin/bash

# Set the max number of threads to use for programs using OpenMP. Should be <= ppn. Does nothing if the program doesn't use OpenMP.
export OMP_NUM_THREADS=$SLURM_CPUS_ON_NODE

# LOAD MODULES, INSERT CODE, AND RUN YOUR PROGRAMS HERE

#	Some handy variables
#${SLURM_MEM_PER_CPU}
#${SLURM_MEM_PER_NODE}
#${SLURM_JOB_NAME}
#${SLURM_NTASKS}
#${SLURM_JOB_NUM_NODES}

#	move into the correct place
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

#	setup variables for the job
OUTPUT_BAM_FILE="${1}"
OUTPUT_DIR=`dirname "${OUTPUT_BAM_FILE}"`
shift
INPUT_BAM_FILES=("${@}")

# 	check for existence of input file(s)
#		We assume samtools is capable of recognizing whether the
#		file(s) it requires exists.

# 	check for existence of expected output file(s)
#		We assume you've already done this. caveat emptor.

#	create output directory(ies), if needed
mkdir -p "${OUTPUT_DIR}" &> /dev/null

#	run the program of interest
time samtools merge \
	-@ "${SLURM_NTASKS}" \
	-c -p \
	-O "BAM" \
	"${OUTPUT_BAM_FILE}" \
	"${INPUT_BAM_FILES[@]}"
	# --write-index \ # creates .csi index (instead of .bai)

#	cleanup and exit
EXIT_CODE=$?
if [ ${EXIT_CODE} -eq 0 ]
then
	touch "${OUTPUT_BAM_FILE}.ok" &> /dev/null
	chmod 444 "${OUTPUT_BAM_FILE}"* &> /dev/null
fi

cleanup
exit ${EXIT_CODE}


#Usage: samtools merge [-nurlf] [-h inh.sam] [-b <bamlist.fofn>] <out.bam> <in1.bam> [<in2.bam> ... <inN.bam>]
#
#Options:
#  -n         Input files are sorted by read name
#  -t TAG     Input files are sorted by TAG value
#  -r         Attach RG tag (inferred from file names)
#  -u         Uncompressed BAM output
#  -f         Overwrite the output BAM if exist
#  -1         Compress level 1
#  -l INT     Compression level, from 0 to 9 [-1]
#  -R STR     Merge file in the specified region STR [all]
#  -h FILE    Copy the header in FILE to <out.bam> [in1.bam]
#  -c         Combine @RG headers with colliding IDs [alter IDs to be distinct]
#  -p         Combine @PG headers with colliding IDs [alter IDs to be distinct]
#  -s VALUE   Override random seed
#  -b FILE    List of input BAM filenames, one per line [null]
#  -X         Use customized index files
#  --no-PG    do not add a PG line
#      --input-fmt-option OPT[=VAL]
#               Specify a single input file format option in the form
#               of OPTION or OPTION=VALUE
#  -O, --output-fmt FORMAT[,OPT[=VAL]]...
#               Specify output format (SAM, BAM, CRAM)
#      --output-fmt-option OPT[=VAL]
#               Specify a single output file format option in the form
#               of OPTION or OPTION=VALUE
#      --reference FILE
#               Reference sequence FASTA FILE [null]
#  -@, --threads INT
#               Number of additional threads to use [0]
#      --write-index
#               Automatically index the output files [off]
#      --verbosity INT
#               Set level of verbosity
