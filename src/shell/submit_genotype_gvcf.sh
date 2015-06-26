#!/bin/bash
#$ -S /bin/bash
#$ -cwd

for file in `cat $1`
do
  cp $ngs_gvcf_dir/$file* $TMPDIR/
  bfile=`basename $file`
  echo "--variant $bfile" >> $TMPDIR/gvcfs.txt
done

cd $TMPDIR

VARIANTS=`cat gvcfs.txt`

$ngs_java_dir/java -Xmx16g -jar $ngs_gatk_dir/GenomeAnalysisTK.jar -T GenotypeGVCFs -l INFO -R $ngs_reference_seq.fasta --dbsnp $ngs_dbsnp_file -L $ngs_target_file -o $JOB_NAME.raw.vcf.gz $VARIANTS &> $ngs_logs_dir/$JOB_NAME.genotypegvcfs.log

cp $JOB_NAME.raw.vcf* $ngs_vcf_dir/
