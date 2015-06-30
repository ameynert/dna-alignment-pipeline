# define environment
source /etc/profile.d/modules.sh
module load apps/gcc/perl/5.14.1
module load apps/gcc/java/1.7.0_60

# source code and working directories
export hts_src_dir=/export/users/ameynert/exome_alignment/src
export hts_tmp_dir=/tmp # local directory on node

# project directories
export hts_project_dir=/mnt/lustre2/ameynert/alignment
export hts_runs_in_dir=$hts_project_dir/runs
export hts_bam_in_dir=$hts_project_dir/bam
export hts_bam_out_dir=$hts_project_dir/bam
export hts_coverage_dir=$hts_project_dir/coverage
export hts_stats_dir=$hts_project_dir/stats
export hts_logs_dir=$hts_project_dir/logs
export hts_gvcf_dir=$hts_project_dir/gvcf
export hts_vcf_dir=$hts_project_dir/vcf

# project options
export hts_verbose=1
export hts_debug=0
export hts_runs_in_own_dirs=1
export hts_java_memstack=4g
export hts_use_target_intervals=1
export hts_target_interval_padding=0
export hts_target_file=$hts_project_dir/targets/targets.bed
export hts_run_haplotype_caller=1

# external data
export hts_resources_dir=/mnt/lustre2/evolgen
export hts_reference_id=b37
export hts_bwa_version=bwa-0.7.10
export hts_reference_seq=$hts_resources_dir/reference/$hts_reference_id/$hts_bwa_version/human.fasta
export hts_gatk_bundle_dir=$hts_resources_dir/gatk_bundle/$hts_reference_id
export hts_dbsnp_file=$hts_gatk_bundle_dir/dbsnp_138.$hts_reference_id.vcf
export hts_known_indels_1=$hts_gatk_bundle_dir/1000G_phase1.indels.$hts_reference_id.vcf
export hts_known_indels_2=$hts_gatk_bundle_dir/Mills_and_1000G_gold_standard.indels.$hts_reference_id.vcf

# external software
export hts_external_dir=/opt/gridware/apps

module load apps/gcc/BWA/0.7.10
export hts_bwa_dir=$hts_external_dir/gcc/BWA/0.7.10/bin

module load apps/gcc/samtools/1.1
export hts_samtools_dir=$hts_external_dir/gcc/samtools/1.1/bin

module load apps/java/picard/1.126
export hts_picard_dir=$hts_external_dir/java/picard/1.126/bin

module load apps/java/GenomeAnalysisTK/3.3-0
export hts_gatk_dir=$hts_external_dir/java/GenomeAnalysisTK/3.3-0/bin
