#!/bin/bash
#$ -S /bin/bash
#$ -cwd

for file in `cat $1`
do
  cp $hts_gvcf_dir/$file* $TMPDIR/
  bfile=`basename $file`
  echo "--variant $bfile" >> $TMPDIR/gvcfs.txt
done

cd $TMPDIR

VARIANTS=`cat gvcfs.txt`

java -Xmx$hts_java_memstack -jar $hts_gatk -T GenotypeGVCFs -l INFO -R $hts_reference_seq --dbsnp $hts_dbsnp_file -L $hts_target_file -o $JOB_NAME.raw.vcf.gz $VARIANTS &> $hts_logs_dir/$JOB_NAME.genotypegvcfs.log

cp $JOB_NAME.raw.vcf* $hts_vcf_dir/
