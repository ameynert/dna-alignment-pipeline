#!/bin/bash
#$ -S /bin/bash
#$ -cwd

cd $hts_work_dir

# split VCF into SNPs and indels
$hts_vcftools --gzvcf $hts_vcf_dir/$JOB_NAME.raw.vcf.gz --out $JOB_NAME.raw.snps --remove-indels --recode --recode-INFO-all
$hts_vcftools --gzvcf $hts_vcf_dir/$JOB_NAME.raw.vcf.gz --out $JOB_NAME.raw.indels --keep-only-indels --recode --recode-INFO-all

# rename, bgzip and tabix results
for type in "snps" "indels"
do
  mv $JOB_NAME.raw.$type.recode.vcf $JOB_NAME.raw.$type.vcf
  bgzip $JOB_NAME.raw.$type.vcf
  tabix -p vcf $JOB_NAME.raw.$type.vcf.gz
done

# run SNP and indel recalibration
java -Xmx${hts_java_memstack} -jar $hts_gatk -T VariantRecalibrator -R $hts_reference_seq -input $JOB_NAME.raw.snps.vcf.gz -recalFile $JOB_NAME.snps.recal -tranchesFile $JOB_NAME.snps.tranches -rscriptFile $JOB_NAME.snps.R -resource:hapmap,known=false,training=true,truth=true,prior=15.0 $hts_hapmap_file -resource:omni,known=false,training=true,truth=true,prior=12.0 $hts_omni_file -resource:1000G,known=false,training=true,truth=false,prior=10.0 $hts_1000G_snps_file -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $hts_dbsnp_file -an DP -an MQ -an MQRankSum -an ReadPosRankSum -an FS -an SOR -an InbreedingCoeff -an QD -mode SNP --TStranche 99.5 --TStranche 90.0 --TStranche 99.0 --TStranche 99.9 --TStranche 100.0 &> $hts_logs_dir/$JOB_NAME.Snps.VariantRecalibrator.log

java -Xmx${hts_java_memstack} -jar $hts_gatk -T VariantRecalibrator -R $hts_reference_seq -input $JOB_NAME.raw.indels.vcf.gz -recalFile $JOB_NAME.indels.recal -tranchesFile $JOB_NAME.indels.tranches -rscriptFile $JOB_NAME.indels.R --maxGaussians 4 -resource:mills,known=false,training=true,truth=true,prior=12.0 $hts_known_indels_2 -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $hts_dbsnp_file -an DP -an QD -an FS -an SOR -an ReadPosRankSum -an MQRankSum -an InbreedingCoeff -mode INDEL &> $hts_logs_dir/$JOB_NAME.Indels.VariantRecalibrator.log

# apply recalibration
java -Xmx${hts_java_memstack} -jar $hts_gatk -T ApplyRecalibration -R $hts_reference_seq --input $JOB_NAME.raw.snps.vcf.gz -recalFile $JOB_NAME.snps.recal -tranchesFile $JOB_NAME.snps.tranches -o $JOB_NAME.snps.recal.vcf.gz --ts_filter_level 99.5 -mode SNP &> $hts_logs_dir/$JOB_NAME.Snps.ApplyRecalibration.log

java -Xmx${hts_java_memstack} -jar $hts_gatk -T ApplyRecalibration -R $hts_reference_seq --input $JOB_NAME.raw.indels.vcf.gz -recalFile $JOB_NAME.indels.recal -tranchesFile $JOB_NAME.indels.tranches -o $JOB_NAME.indels.recal.vcf.gz --ts_filter_level 99 -mode INDEL &> $hts_logs_dir/$JOB_NAME.Indels.ApplyRecalibration.log

# clean up items not to be copied back
rm $JOB_NAME.raw*

# copy back results
mv $JOB_NAME.*.recal.vcf.gz* $hts_vcf_dir/
mv $JOB_NAME.* $hts_stats_dir/
