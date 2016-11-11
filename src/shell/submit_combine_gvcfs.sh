#!/bin/bash
#$ -cwd
#$ -w w
#$ -j y
#$ -S /bin/bash
#$ -l h_vmem=32g
#$ -l h_rt=24:00:00
#$ -N combinegvcfs

ulimit -n 2000
unset MODULEPATH

. /etc/profile.d/modules.sh

ENV=$1
NAME=$2

source $ENV

cd $hts_work_dir
mkdir -p $NAME
cd $NAME

rm $NAME.gvcfs.txt
for id in `cat $1`
do
  cp $hts_gvcf_dir/$id.g.vcf* ./
  echo "--variant $id.g.vcf.gz" >> $NAME.gvcfs.txt
done

cd $TMPDIR

java -Xmx16g -jar $hts_gatk -T CombineGVCFs -l INFO -R $hts_reference_seq -o $NAME.g.vcf.gz `cat $NAME.gvcfs.txt` &> $hts_logs_dir/$NAME.combinegvcfs.log

cp $NAME.g.vcf* $hts_gvcf_dir/

cd ..
rm -r $NAME
