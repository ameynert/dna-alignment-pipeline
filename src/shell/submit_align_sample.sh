#!/bin/bash
#$ -cwd
#$ -w w
#$ -j y
#$ -S /bin/bash
#$ -l h_vmem=16g
#$ -l h_rt=48:00:00
#$ -N align

ulimit -n 2000
unset MODULEPATH

. /etc/profile.d/modules.sh

ENV=$1
PARAMS=$2

source $ENV

NAME=$(cat $PARAMS | head -n $SGE_TASK_ID | tail -n 1 | awk '{ print $1 }')
READS=$(cat $PARAMS | head -n $SGE_TASK_ID | tail -n 1 | awk '{ print $2 }')

perl $hts_src_dir/perl/align_sample.pl --name $NAME --reads $READS
