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
RAW_MASK_FILE="${1}"
shift
INPUT_SAMS=("${@}")
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
time cat "${INPUT_SAMS[@]}" \
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

