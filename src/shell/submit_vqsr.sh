#!/bin/bash
#$ -cwd
#$ -w w
#$ -j y
#$ -S /bin/bash
#$ -l h_vmem=32g
#$ -l h_rt=6:00:00
#$ -N vqsr

ulimit -n 2000
unset MODULEPATH

. /etc/profile.d/modules.sh

ENV=$1
NAME=$2

source $ENV

cd $hts_work_dir
mkdir -p $NAME
cd $NAME

# split VCF into SNPs and indels
vcftools --gzvcf $hts_vcf_dir/$NAME.raw.vcf.gz --out $NAME.raw.snps --remove-indels --recode --recode-INFO-all
vcftools --gzvcf $hts_vcf_dir/$NAME.raw.vcf.gz --out $NAME.raw.indels --keep-only-indels --recode --recode-INFO-all

# rename, bgzip and tabix results
for type in "snps" "indels"
do
  mv $NAME.raw.$type.recode.vcf $NAME.raw.$type.vcf
  bgzip $NAME.raw.$type.vcf
  tabix -p vcf $NAME.raw.$type.vcf.gz
done

# run SNP and indel recalibration
java -Xmx${hts_java_memstack} -jar $hts_gatk -T VariantRecalibrator -R $hts_reference_seq -input $NAME.raw.snps.vcf.gz -recalFile $NAME.snps.recal -tranchesFile $NAME.snps.tranches -rscriptFile $NAME.snps.R -resource:hapmap,known=false,training=true,truth=true,prior=15.0 $hts_hapmap_file -resource:omni,known=false,training=true,truth=true,prior=12.0 $hts_omni_file -resource:1000G,known=false,training=true,truth=false,prior=10.0 $hts_1000G_snps_file -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $hts_dbsnp_file -an DP -an MQ -an MQRankSum -an ReadPosRankSum -an FS -an SOR -an InbreedingCoeff -an QD -mode SNP --TStranche 99.5 --TStranche 90.0 --TStranche 99.0 --TStranche 99.9 --TStranche 100.0 &> $hts_logs_dir/$NAME.Snps.VariantRecalibrator.log

java -Xmx${hts_java_memstack} -jar $hts_gatk -T VariantRecalibrator -R $hts_reference_seq -input $NAME.raw.indels.vcf.gz -recalFile $NAME.indels.recal -tranchesFile $NAME.indels.tranches -rscriptFile $NAME.indels.R --maxGaussians 4 -resource:mills,known=false,training=true,truth=true,prior=12.0 $hts_known_indels_2 -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $hts_dbsnp_file -an DP -an QD -an FS -an SOR -an ReadPosRankSum -an MQRankSum -an InbreedingCoeff -mode INDEL &> $hts_logs_dir/$NAME.Indels.VariantRecalibrator.log

# apply recalibration
java -Xmx${hts_java_memstack} -jar $hts_gatk -T ApplyRecalibration -R $hts_reference_seq --input $NAME.raw.snps.vcf.gz -recalFile $NAME.snps.recal -tranchesFile $NAME.snps.tranches -o $NAME.snps.recal.vcf.gz --ts_filter_level 99.5 -mode SNP &> $hts_logs_dir/$NAME.Snps.ApplyRecalibration.log

java -Xmx${hts_java_memstack} -jar $hts_gatk -T ApplyRecalibration -R $hts_reference_seq --input $NAME.raw.indels.vcf.gz -recalFile $NAME.indels.recal -tranchesFile $NAME.indels.tranches -o $NAME.indels.recal.vcf.gz --ts_filter_level 99 -mode INDEL &> $hts_logs_dir/$NAME.Indels.ApplyRecalibration.log

# clean up items not to be copied back
rm $NAME.raw*

# copy back results
mv $NAME.*.recal.vcf.gz* $hts_vcf_dir/
mv $NAME.* $hts_stats_dir/
