#!/bin/bash
#$ -cwd
#$ -w w
#$ -j y
#$ -S /bin/bash
#$ -l h_vmem=16g
#$ -l h_rt=24:00:00
#$ -N genotype

ulimit -n 2000
unset MODULEPATH

. /etc/profile.d/modules.sh

ENV=$1
NAME=$2
GVCFS=$3

source $ENV

cd $hts_work_dir
mkdir -p $NAME
cd $NAME

rm $NAME.gvcfs.txt
for file in `cat $GVCFS`
do
  cp $hts_gvcf_dir/$file* ./
  bfile=`basename $file`
  echo "--variant $bfile" >> $NAME.gvcfs.txt
done

echo "java -Xmx8g -jar $hts_gatk -T GenotypeGVCFs -l INFO -R $hts_reference_seq --dbsnp $hts_dbsnp_file -L $hts_target_file -o $NAME.raw.vcf.gz `cat $NAME.gvcfs.txt` &> $hts_logs_dir/$NAME.genotypegvcfs.log"

java -Xmx8g -jar $hts_gatk -T GenotypeGVCFs -l INFO -R $hts_reference_seq --dbsnp $hts_dbsnp_file -L $hts_target_file -o $NAME.raw.vcf.gz `cat $NAME.gvcfs.txt` &> $hts_logs_dir/$NAME.genotypegvcfs.log

cp $NAME.raw.vcf* $hts_vcf_dir/

cd ..
rm -r $NAME
