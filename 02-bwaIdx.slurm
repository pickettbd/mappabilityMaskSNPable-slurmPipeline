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
module load bwa/0.7.17_2019.07.09

#	setup variables for the job
ASSEMBLY_PFX="${1}"
ASSEMBLY_FA="${2}"
OUTPUT_DIR=`dirname "${ASSEMBLY_PFX}"`

# 	check for existence of input file(s)
#		We assume bwa is capable of recognizing whether the
#		file(s) it requires exists.

# 	check for existence of expected output file(s)
#		We assume you've already done this. caveat emptor.

#	create output directory(ies), if needed
mkdir -p "${OUTPUT_DIR}" &> /dev/null

#	run the program of interest
time bwa index \
	-p "${ASSEMBLY_PFX}" \
	"${ASSEMBLY_FA}"

#	cleanup and exit
EXIT_CODE=$?
if [ ${EXIT_CODE} -eq 0 ]
then
	chmod 444 "${ASSEMBLY_PFX}"* &> /dev/null
fi

cleanup
exit ${EXIT_CODE}

#Usage:   bwa index [options] <in.fasta>
#
#Options: -a STR    BWT construction algorithm: bwtsw, is or rb2 [auto]
#         -p STR    prefix of the index [same as fasta name]
#         -b INT    block size for the bwtsw algorithm (effective with -a bwtsw) [10000000]
#         -6        index files named as <in.fasta>.64.* instead of <in.fasta>.* 
#
#Warning: `-a bwtsw' does not work for short genomes, while `-a is' and
#         `-a div' do not work not for long genomes.

