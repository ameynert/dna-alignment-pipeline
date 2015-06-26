# define environment
source /etc/profile.d/modules.sh
module load apps/gcc/perl/5.14.1
module load apps/gcc/mysql/5.5.12
module load apps/gcc/python/2.7.1
module load compilers/gcc/4.7.3

# source code and working directories
export ngs_src_dir=/export/users/ameynert/exome_alignment/src
export ngs_external_dir=/export/users/ameynert/exome_alignment/external
export ngs_tmp_dir=/tmp

# project directories
export ngs_project_dir=/mnt/lustre2/ameynert/alignment
export ngs_runs_in_dir=$ngs_project_dir/runs
export ngs_bam_in_dir=$ngs_project_dir/bam
export ngs_bam_out_dir=$ngs_project_dir/bam
export ngs_cov_dir=$ngs_project_dir/coverage
export ngs_stats_dir=$ngs_project_dir/stats
export ngs_logs_dir=$ngs_project_dir/logs
export ngs_gvcf_dir=$ngs_project_dir/gvcf
export ngs_vcf_dir=$ngs_project_dir/vcf

# project options
export ngs_verbose=1
export ngs_debug=0
export ngs_runs_in_own_dirs=1

# external data
export ngs_resources_dir=/mnt/lustre2/evolgen
export ngs_reference_seq=$ngs_resources_dir/human_g1k_v37/human_g1k_v37
export ngs_gatk_bundle_dir=$ngs_resources_dir/gatk_bundle/2.8/b37
export ngs_gatk_reference=b37
export ngs_dbsnp_file=$ngs_gatk_bundle_dir/dbsnp_138.$ngs_gatk_reference.vcf
export ngs_target_interval_padding=0
export ngs_known_indels_1=$ngs_gatk_bundle_dir/1000G_phase1.indels.$ngs_gatk_reference.vcf
export ngs_known_indels_2=$ngs_gatk_bundle_dir/Mills_and_1000G_gold_standard.indels.$ngs_gatk_reference.vcf

# external software
export ngs_java_dir=/export/users/ameynert/java/jre1.7.0_25/bin # GATK 2.6+ requires Java 7
export ngs_samtools_dir=$ngs_external_dir/samtools-1.1
export ngs_bwa_dir=$ngs_external_dir/bwa-0.7.10
export ngs_picard_dir=$ngs_external_dir/picard-tools-1.126
export ngs_gatk_dir=$ngs_external_dir/GenomeAnalysisTK-3.3-0
