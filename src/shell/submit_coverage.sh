#!/bin/bash
#$ -S /bin/bash
#$ -cwd

PARAMS=$1
NAME=$(cat $PARAMS | head -n $SGE_TASK_ID | tail -n 1 )

$ngs_java_dir/java -Xmx16g -jar $ngs_gatk_dir/GenomeAnalysisTK.jar -T DepthOfCoverage -l INFO -R $ngs_reference_seq.fasta -I $ngs_bam_in_dir/$NAME.recal.bam -L $ngs_target_file -o $TMPDIR/$NAME.depths --omitDepthOutputAtEachBase --interval_merging OVERLAPPING_ONLY &> $ngs_logs_dir/$NAME.coverage.log

mv $TMPDIR/$NAME.depths* $ngs_cov_dir/
