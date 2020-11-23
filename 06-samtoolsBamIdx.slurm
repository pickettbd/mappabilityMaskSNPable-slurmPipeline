#! /bin/bash

# LOAD MODULES, INSERT CODE, AND RUN YOUR PROGRAMS HERE

#	Some handy variables
#${SLURM_MEM_PER_CPU}
#${SLURM_MEM_PER_NODE}
#${SLURM_JOB_NAME}
#${SLURM_NTASKS}
#${SLURM_JOB_NUM_NODES}
#${SLURM_JOB_ID}
#${SLURM_ARRAY_JOB_ID}
#${SLURM_ARRAY_TASK_ID}
#${SLURM_ARRAY_TASK_COUNT}
#${SLURM_ARRAY_TASK_MIN}
#${SLURM_ARRAY_TASK_MAX}

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

if [ -z "${SLURM_ARRAY_TASK_ID}" ]
then
	printf "%s\n" "ERROR: SLURM_ARRAY_TASK_ID not defined." 1>&2
	control_c
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

	rm -rf /tmp/${SLURM_ARRAY_JOB_ID}-${SLURM_ARRAY_TASK_ID} &> /dev/null

	# move successful/failed job files to the correct place
	local SUCCESS_FAIL_STATUS_SUBDIR
	SUCCESS_FAIL_STATUS_SUBDIR="${1:=success}"

	mv ${SLURM_SUBMIT_DIR}/job_files/${SLURM_JOB_NAME}__${SLURM_ARRAY_JOB_ID}-${SLURM_ARRAY_TASK_ID}.{err,out} ${SLURM_SUBMIT_DIR}/job_files/${SUCCESS_FAIL_STATUS_SUBDIR} &> /dev/null
}

control_c()
{
	kill -SIGINT `jobs -p`
	cleanup "failed"
	exit 1
}

trap control_c SIGHUP SIGINT SIGTERM SIGQUIT

moveTempFilesBackToNetworkStorage()
{
	if [ -n $WORK_DIR ] && [ -e $WORK_DIR ] && [ -d $WORK_DIR ]
	then
		time rsync -utpv "${TMP_OUTPUT_BAI}" "${OUTPUT_BAI}" 1>&2
		if [ $? -eq 0 ]
		then
			touch "${OUTPUT_BAI}.ok"
		fi
	fi
}

outOfTime()
{
	printf "%s\n" "This job ran out of time! SLURM sent signal USR1 and now we're trying to quite gracefully. (fingers crossed!)" 1>&2
	kill -SIGINT `jobs -p`

	printf "%s\n" "Now using 'cleanup' function with status 'success'. Be advised: this process ran out of time- you will need to run this again with more time (and/or more RAM)." 1>&2
	cleanup "success"

	exit 10 # SIGUSR1 == 10
}

trap outOfTime USR1


# 	load modules
module purge
module load samtools/1.10

#	setup variables for the job
#SPLIT_NUM=`printf "%02u" "${SLURM_ARRAY_TASK_ID}"`
SPLIT_NUM="${SLURM_ARRAY_TASK_ID}"

INPUT_BAM_PFX="${1}"

INPUT_BAM_SFX=".bam"
INPUT_BAM="${INPUT_BAM_PFX}${SPLIT_NUM}${INPUT_BAM_SFX}"

OUTPUT_BAI_SFX=".bai"
OUTPUT_BAI="${INPUT_BAM}${OUTPUT_BAI_SFX}"
OUTPUT_BAI_DIR=$(readlink -f `dirname "${OUTPUT_BAI}"`)

# 	check for existence of input file(s)
#		We assume samtools is capable of recognizing whether the index it
#		requires exists. We assume the same for the input fa file.

# 	check for existence of expected output file(s)
if [ -e "${OUTPUT_BAI}" ]
then
	printf "%s\n" "INFO: ${OUTPUT_BAI} already exists! We assume this means we can quit this process without running the intended command. Bye!" 1>&2
	cleanup
	exit 0
fi

#	create output directory, if needed
mkdir -p "${OUTPUT_BAI_DIR}" &> /dev/null

#		create /tmp output directory and copy existing files
WORK_DIR="/tmp/${SLURM_ARRAY_JOB_ID}-${SPLIT_NUM}"
mkdir -p "${WORK_DIR}" &> /dev/null
#			files
TMP_INPUT_BAM="${WORK_DIR}/`basename ${INPUT_BAM}`"
TMP_OUTPUT_BAI="${WORK_DIR}/`basename ${OUTPUT_BAI}`"
time rsync -uLtpv "${INPUT_BAM}" "${WORK_DIR}"/ 1>&2

# write tmp info for later cleanup, if needed
#	get the lock
dotlockfile -l "${SLURM_SUBMIT_DIR}/.cleanup.tsv.lock"
printf "%s\t%s\n" "${SLURM_JOB_NODELIST}" "${SLURM_ARRAY_JOB_ID}-${SLURM_ARRAY_TASK_ID}" >> "${SLURM_SUBMIT_DIR}/cleanup.tsv"
dotlockfile -u "${SLURM_SUBMIT_DIR}/.cleanup.tsv.lock"

#	run the program of interest
echo samtools index -b -@ ${SLURM_NTASKS:-1} "${TMP_INPUT_BAM}" "${TMP_OUTPUT_BAI}" 1>&2
time samtools index \
	-b \
	-@ "${SLURM_NTASKS:-1}" \
	"${TMP_INPUT_BAM}" \
	"${TMP_OUTPUT_BAI}" &

wait `jobs -p`
EXIT_CODE=$?

moveTempFilesBackToNetworkStorage

#	cleanup and exit
if [ ${EXIT_CODE} -eq 0 ]
then
	chmod 444 "${OUTPUT_BAI}" &> /dev/null
	cleanup "success"
else
	rm -f "${OUTPUT_BAI}" &> /dev/null
	cleanup "failed"
fi

exit ${EXIT_CODE}

#Usage: samtools index [-bc] [-m INT] <in.bam> [out.index]
#Options:
#  -b       Generate BAI-format index for BAM files [default]
#  -c       Generate CSI-format index for BAM files
#  -m INT   Set minimum interval size for CSI indices to 2^INT [14]
#  -@ INT   Sets the number of threads [none]
