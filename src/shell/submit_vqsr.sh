#!/bin/bash
#$ -S /bin/bash
#$ -cwd

idfile=$1

# copy GATK bundle over
cp $ngs_gatk_bundle_dir/*.gz $TMPDIR/
cp $ngs_gatk_bundle_dir/*.tbi $TMPDIR/

# copy raw variant file over
cp $ngs_vcf_dir/$JOB_NAME.raw* $TMPDIR/

# create --indv file for vcftools
awk '{ print "--indv " $1 }' $idfile > $TMPDIR/indv.txt

cd $TMPDIR

# run SNP and indel recalibration
$ngs_java_dir/java -Xmx4g -jar $ngs_gatk_dir/GenomeAnalysisTK.jar -T VariantRecalibrator -R $ngs_reference_seq.fasta -input $JOB_NAME.raw.vcf.gz -recalFile $JOB_NAME.snps.recal -tranchesFile $JOB_NAME.snps.tranches -rscriptFile $JOB_NAME.snps.R -resource:hapmap,known=false,training=true,truth=true,prior=15.0 hapmap_3.3.b37.vcf.gz -resource:omni,known=false,training=true,truth=true,prior=12.0 1000G_omni2.5.b37.vcf.gz -resource:1000G,known=false,training=true,truth=false,prior=10.0 1000G_phase1.snps.high_confidence.b37.vcf.gz -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 dbsnp_138.b37.vcf.gz -an QD -an MQ -an MQRankSum -an ReadPosRankSum -an FS -an SOR -an InbreedingCoeff -mode SNP --TStranche 99.5 --TStranche 90.0 --TStranche 99.0 --TStranche 99.9 --TStranche 100.0 &> $ngs_logs_dir/$JOB_NAME.snps.variantrecalibrator.log

$ngs_java_dir/java -Xmx4g -jar $ngs_gatk_dir/GenomeAnalysisTK.jar -T VariantRecalibrator -R $ngs_reference_seq.fasta -input $JOB_NAME.raw.vcf.gz -recalFile $JOB_NAME.indels.recal -tranchesFile $JOB_NAME.indels.tranches -rscriptFile $JOB_NAME.indels.R --maxGaussians 4 -resource:mills,known=false,training=true,truth=true,prior=12.0 Mills_and_1000G_gold_standard.indels.b37.vcf.gz -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 dbsnp_138.b37.vcf.gz -an QD -an FS -an SOR -an ReadPosRankSum -an MQRankSum -an InbreedingCoeff -mode INDEL &> $ngs_logs_dir/$JOB_NAME.indels.variantrecalibrator.log

# apply recalibration
$ngs_java_dir/java -Xmx4g -jar $ngs_gatk_dir/GenomeAnalysisTK.jar -T ApplyRecalibration -R $ngs_reference_seq.fasta --input $JOB_NAME.raw.vcf.gz -recalFile $JOB_NAME.snps.recal -tranchesFile $JOB_NAME.snps.tranches -o $JOB_NAME.snps.recal.vcf.gz --ts_filter_level 99.5 -mode SNP &> $ngs_logs_dir/$JOB_NAME.snps.applyrecalibration.log

$ngs_java_dir/java -Xmx4g -jar $ngs_gatk_dir/GenomeAnalysisTK.jar -T ApplyRecalibration -R $ngs_reference_seq.fasta --input $JOB_NAME.raw.vcf.gz -recalFile $JOB_NAME.indels.recal -tranchesFile $JOB_NAME.indels.tranches -o $JOB_NAME.indels.recal.vcf.gz --ts_filter_level 99 -mode INDEL &> $ngs_logs_dir/$JOB_NAME.indels.applyrecalibration.log

# split VCF into SNPs and indels, filter based on re-calibration and ids
vcftools --gzvcf $JOB_NAME.snps.recal.vcf.gz --out $JOB_NAME.snps.filtered --remove-filtered-all --remove-indels `cat indv.txt` --non-ref-ac 1 --recode --recode-INFO-all
vcftools --gzvcf $JOB_NAME.indels.recal.vcf.gz --out $JOB_NAME.indels.filtered --remove-filtered-all --keep-only-indels `cat indv.txt` --non-ref-ac 1 --recode --recode-INFO-all

# rename, bgzip and tabix results
for type in "snps" "indels"
do
  mv $JOB_NAME.$type.filtered.recode.vcf $JOB_NAME.$type.filtered.vcf
  bgzip $JOB_NAME.$type.filtered.vcf
  tabix -p vcf $JOB_NAME.$type.filtered.vcf.gz
done

# clean up items not to be copied back
rm $JOB_NAME.raw*
rm $JOB_NAME.snps.recal.vcf.gz*
rm $JOB_NAME.indels.recal.vcf.gz*

# copy back results
cp $JOB_NAME*.log $ngs_logs_dir/
rm $JOB_NAME*.log
cp $JOB_NAME* $ngs_vcf_dir/
