#!/bin/bash
#$ -cwd
#$ -w w
#$ -j y
#$ -S /bin/bash
#$ -l h_vmem=2g
#$ -l h_rt=1:00:00
#$ -N fastqc

ulimit -n 2000
unset MODULEPATH

. /etc/profile.d/modules.sh

ENV=$1
PARAMS=$2

source $ENV

DIR=$(cat $PARAMS | head -n $SGE_TASK_ID | tail -n 1 | awk '{ print $1 }')
FASTQ1=$(cat $PARAMS | head -n $SGE_TASK_ID | tail -n 1 | awk '{ print $2 }')
FASTQ2=$(cat $PARAMS | head -n $SGE_TASK_ID | tail -n 1 | awk '{ print $3 }')

cd $hts_runs_in_dir/$DIR

fastqc --no-extract $FASTQ1 $FASTQ2
