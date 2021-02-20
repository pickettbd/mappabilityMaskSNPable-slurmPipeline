# SNPable Mappability Mask Pipeline
This is a pipeline for running [SNPable](http://lh3lh3.users.sourceforge.net/snpable.shtml) on a SLURM-controlled Linux cluster.

## Directory Structure and Installation
These scripts assume a very specific directory structure and naming scheme.  
You can modify the scripts to avoid it, but using it should also be fairly straightforward.
First, create the directory structure:
```
mkdir some_project_dir
cd some_project_dir
mkdir -p data job_files/{success,failed}
git clone https://github.com/pickettbd/mappabilityMaskSNPable-slurmPipeline scripts-snpable
```
The scripts *must* be run from the main project directory (some_project_dir) (*not* from the scripts-snpable dir).

## Data Requirements
This project is written to work with a "reference" genome (a non-official *de novo* assembly version is okay).

## Software Dependencies
These scripts assume a [GNU](https://www.gnu.org) [bash](https://www.gnu.org/software/bash) shell and cluster job submission controlled by [SLURM](https://slurm.schedmd.com).
The following tools are assumed to be installed on your machine with the executables available in your $PATH.  
The project assumes they are availble via system modules (e.g., Tcl or Lua), but removing the `module purge` and `module load _____` commands would remove the dependency on system modules.
- [bwa](https://github.com/lh3/bwa) (v0.7.17 20200702): Burrow-Wheeler Aligner for short-read alignment
- [seqbility](https://github.com/lh3/misc/tree/master/seq/seqbility) [20091110](http://lh3lh3.users.sourceforge.net/download/seqbility-20091110.tar.bz2): Utilities to compute mappability masks

## Notes
This pipeline does not support file names or paths that have whitespace in them.
Please run steps 00 to see instructions on how to set things up regarding where the assembly and reads are supposed to be located.
The output mask will be in the `data/alns` directory.

## Licensing and Citation
Please see the `LICENSE` file for licensing information.
Please cite the author and this GitHub Repo if you rely on this repo for a project that ends up being published in any kind of peer-reviewed publication or presentation. Please include a link. 
