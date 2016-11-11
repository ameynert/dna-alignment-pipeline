# define environment

# source code and working directories
export hts_src_dir=/exports/igmm/eddie/bioinfsvice/ameynert/lewis_myopia/dna-alignment-pipeline/src
export hts_work_dir=/exports/eddie/scratch/ameyner2/lewis_myopia/work

# project directories
export hts_project_dir=/exports/igmm/eddie/bioinfsvice/ameynert/lewis_myopia
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
export hts_target_file=$hts_project_dir/targets/AmpliSeq.Nextera.TruSeq.plus50bpflanks.merged.b37.bed
export hts_run_haplotype_caller=1

# external data
export hts_resources_dir=/exports/igmm/eddie/NextGenResources
export hts_reference_id=b37
export hts_reference_seq=$hts_resources_dir/reference/b37/bwa-0.7.12-r1039/human_g1k_v37.fasta
export hts_gatk_bundle_dir=$hts_resources_dir/gatk_bundle/2.8/$hts_reference_id
export hts_dbsnp_file=$hts_gatk_bundle_dir/dbsnp_138.$hts_reference_id.vcf
export hts_known_indels_1=$hts_gatk_bundle_dir/1000G_phase1.indels.$hts_reference_id.vcf
export hts_known_indels_2=$hts_gatk_bundle_dir/Mills_and_1000G_gold_standard.indels.$hts_reference_id.vcf

# external software
module load igmm/apps/FastQC/0.11.4
module load igmm/apps/bwa/0.7.12-r1039 # Note it's important that the version of BWA used to align matches the version used to index the reference genome
module load igmm/apps/samtools/1.2
module load igmm/apps/vcftools/0.1.13

export hts_picard=$hts_resources_dir/software/picard-tools-1.139/picard.jar
export hts_gatk=$hts_resources_dir/software/GenomeAnalysisTK-3.6/GenomeAnalysisTK.jar
