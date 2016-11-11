#!/bin/bash
#$ -S /bin/bash
#$ -cwd

. /etc/profile.d/modules.sh
MODULEPATH=$MODULEPATH:/exports/igmm/software/etc/el7/modules

VCFS=$1

resources=/exports/igmm/eddie/NextGenResources
logs=/exports/igmm/eddie/bioinfsvice/ameynert/lewis_myopia/logs
vcfs=/exports/igmm/eddie/bioinfsvice/ameynert/lewis_myopia/vcf
reference=$resources/reference/b37/human_g1k_v37.fasta

java -Xmx32g -cp $resources/software/GenomeAnalysisTK-3.6/GenomeAnalysisTK.jar org.broadinstitute.gatk.tools.CatVariants -R $reference `cat $VCFS` -out $vcfs/$JOB_NAME.vcf.gz &> $logs/$JOB_NAME.CatVariants.log
