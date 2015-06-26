#!/bin/bash
#$ -S /bin/bash
#$ -cwd

source /etc/profile.d/modules.sh
module load apps/java/FastQC/0.10.0

PARAMS=$1
DIR=$(cat $PARAMS | head -n $SGE_TASK_ID | tail -n 1 | awk '{ print $1 }')
FASTQ1=$(cat $PARAMS | head -n $SGE_TASK_ID | tail -n 1 | awk '{ print $2 }')
FASTQ2=$(cat $PARAMS | head -n $SGE_TASK_ID | tail -n 1 | awk '{ print $3 }')

cd $ngs_runs_in_dir/$DIR

fastqc --no-extract $FASTQ1 $FASTQ2
