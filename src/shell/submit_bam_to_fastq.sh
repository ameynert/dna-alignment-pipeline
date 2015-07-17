#!/bin/bash
#$ -S /bin/bash
#$ -cwd

PARAMS=$1

DIR=$(cat $PARAMS | head -n $SGE_TASK_ID | tail -n 1 | awk '{ print $1 }')
FILE=$(cat $PARAMS | head -n $SGE_TASK_ID | tail -n 1 | awk '{ print $2 }')
SAMPLE=$(cat $PARAMS | head -n $SGE_TASK_ID | tail -n 1 | awk '{ print $3 }')

cd $TMPDIR
cp $DIR/$FILE ./
java -Xmx2g -jar $ngs_picard SortSam I=$FILE O=$SAMPLE.unsorted.bam SORT_ORDER=queryname VALIDATION_STRINGENCY=SILENT &> $ngs_logs_dir/$SAMPLE.querysort.log
rm $FILE

java -Xmx2g -jar $ngs_picard SamToFastq I=$SAMPLE.unsorted.bam OUTPUT_PER_RG=TRUE OUTPUT_DIR=. MAX_RECORDS_IN_RAM=4000000 VALIDATION_STRINGENCY=SILENT INCLUDE_NON_PF_READS=TRUE &> $ngs_logs_dir/$SAMPLE.samtofastq.log
rm $SAMPLE.unsorted.bam

gzip *.fastq

mkdir -p $ngs_runs_in_dir/$SAMPLE
mv * $ngs_runs_in_dir/$SAMPLE/
