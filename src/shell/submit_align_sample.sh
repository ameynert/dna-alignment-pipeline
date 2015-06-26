#!/bin/bash
#$ -S /bin/bash
#$ -cwd

PARAMS=$1

NAME=$(cat $PARAMS | head -n $SGE_TASK_ID | tail -n 1 | awk '{ print $1 }')
READS=$(cat $PARAMS | head -n $SGE_TASK_ID | tail -n 1 | awk '{ print $2 }')

perl $ngs_src_dir/perl/align_sample.pl --name $NAME --reads $READS
