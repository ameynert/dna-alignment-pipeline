#!/bin/bash
#$ -S /bin/bash
#$ -cwd

for id in `cat $1`
do
  cp $ngs_gvcf_dir/$id.g.vcf* $TMPDIR/
  echo "--variant $id.g.vcf.gz" >> $TMPDIR/gvcfs.txt
done

cd $TMPDIR

$ngs_java_dir/java -Xmx16g -jar $ngs_gatk_dir/GenomeAnalysisTK.jar -T CombineGVCFs -l INFO -R $ngs_reference_seq.fasta -o $JOB_NAME.g.vcf.gz `cat gvcfs.txt` &> $ngs_logs_dir/$JOB_NAME.combinegvcfs.log

cp $JOB_NAME.g.vcf* $ngs_gvcf_dir/
