#!/bin/bash
#$ -cwd
#$ -w w
#$ -j y
#$ -S /bin/bash
#$ -l h_vmem=4g
#$ -l h_rt=24:00:00
#$ -N bam2fastq

ulimit -n 2000
unset MODULEPATH

. /etc/profile.d/modules.sh

ENV=$1
PARAMS=$2

source $ENV

DIR=$(cat $PARAMS | head -n $SGE_TASK_ID | tail -n 1 | awk '{ print $1 }')
FILE=$(cat $PARAMS | head -n $SGE_TASK_ID | tail -n 1 | awk '{ print $2 }')
SAMPLE=$(cat $PARAMS | head -n $SGE_TASK_ID | tail -n 1 | awk '{ print $3 }')

cd $hts_work_dir
mkdir -p $SAMPLE
cd $SAMPLE

cp $DIR/$FILE ./
java -Xmx2g -jar $hts_picard SortSam I=$FILE O=$SAMPLE.unsorted.bam SORT_ORDER=queryname VALIDATION_STRINGENCY=SILENT &> $hts_logs_dir/$SAMPLE.querysort.log
rm $FILE

java -Xmx2g -jar $hts_picard SamToFastq I=$SAMPLE.unsorted.bam OUTPUT_PER_RG=TRUE OUTPUT_DIR=. MAX_RECORDS_IN_RAM=4000000 VALIDATION_STRINGENCY=SILENT INCLUDE_NON_PF_READS=TRUE &> $hts_logs_dir/$SAMPLE.samtofastq.log
rm $SAMPLE.unsorted.bam

gzip *.fastq

mkdir -p $hts_runs_in_dir/$SAMPLE
mv * $hts_runs_in_dir/$SAMPLE/

cd ..
rm -r $SAMPLE
