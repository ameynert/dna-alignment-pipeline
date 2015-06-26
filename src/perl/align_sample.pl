#!/usr/bin/perl -w

=head1 NAME

align_sample.pl

=head1 AUTHOR

Alison Meynert (alison.meynert@igmm.mrc.ac.uk)

=head1 DESCRIPTION

For a set of DNA high-throughput sequencing runs, aligns the reads using bwa mem.
Merges the alignments and marks duplicates with Picard. Does local re-alignment 
around indels and score re-calibration with GATK. Output is a single indexed BAM 
file.

=cut

use strict;

# Perl
use IO::Zlib;
use IO::File;
use Sys::Hostname;
use File::Basename;
use File::Temp qw/ tempfile tempdir /;
use Getopt::Long;

my $usage = qq{USAGE:
$0 [--help]
  --name  Sample name
  --reads Tab-delimited list of read group info and files, one read group and associated files per line
          Read group in form ID:id,LB:lib,PL:platform, etc. followed by one (single-end) or two (paired-end) files
	  e.g. ID:HWI-D00200_123_H8036ADXX_2,PU:HWI-D00200_123_H8036ADXX_2,PL:ILLUMINA,LB:Library,SM:Sample pair_1.sanfastq.gz pair_2.sanfastq.gz
};

# make sure ngsEnv.sh definitions are in place
die "\$ngs_src_dir not defined" if (!$ENV{'ngs_src_dir'});
my $ngs_src_dir = $ENV{'ngs_src_dir'};
require("$ngs_src_dir/perl/utility.pl");

my $help = 0;
my $name;
my $reads;

GetOptions(
	   'help'    => \$help,
	   'name=s'  => \$name,
	   'reads=s' => \$reads,
) or die $usage;

if ($help || !$name || !$reads)
{
    print $usage;
    exit(0);
}

# Java memory
my $memStack="4g";

# data areas
my $path2Work = File::Temp->newdir(); 
if ($ENV{'ngs_work_dir'})
{
    $path2Work = $ENV{'ngs_work_dir'};
}

die "\$ngs_logs_dir not defined" if (!$ENV{'ngs_logs_dir'});
my $path2Logs = $ENV{'ngs_logs_dir'};

die "\$ngs_reference_seq not defined" if (!$ENV{'ngs_reference_seq'});
my $path2SeqIndex= $ENV{'ngs_reference_seq'};

die "\$ngs_runs_in_dir not defined" if (!$ENV{'ngs_runs_in_dir'});
my $path2Runs= $ENV{'ngs_runs_in_dir'};

my $runsInOwnDir = 0;
if (defined $ENV{'ngs_runs_in_own_dirs'}){
    $runsInOwnDir = $ENV{'ngs_runs_in_own_dirs'};
}

die "\$ngs_stats_dir not defined" if (!$ENV{'ngs_stats_dir'});
my $path2Stats = $ENV{'ngs_stats_dir'};

die "\$ngs_bam_out_dir not defined" if (!$ENV{'ngs_bam_out_dir'});
my $path2Bam = $ENV{'ngs_bam_out_dir'};

die "\$ngs_gvcf_dir not defined" if (!$ENV{'ngs_gvcf_dir'});
my $path2Gvcf = $ENV{'ngs_gvcf_dir'};

die "\$ngs_target_file not defined" if (!$ENV{'ngs_target_file'});
my $path2Targets= $ENV{'ngs_target_file'};

die "\$ngs_dbsnp_file not defined" if (!$ENV{'ngs_dbsnp_file'});
my $path2Dbsnp= $ENV{'ngs_dbsnp_file'};

die "\$ngs_known_indels_1 not defined" if (!$ENV{'ngs_known_indels_1'});
my $path2KnownIndels= $ENV{'ngs_known_indels_1'};

for (my $i = 2; $i <= 10; $i++)
{
    if ($ENV{"ngs_known_indels_$i"})
    {
	$path2KnownIndels .= sprintf(" -known %s", $ENV{"ngs_known_indels_$i"});
    }
}

# paths to progs
die "\$ngs_java_dir not defined\n" if (!$ENV{'ngs_java_dir'});
my $path2Java = $ENV{'ngs_java_dir'};

die "\$ngs_samtools_dir not defined\n" if (!$ENV{'ngs_samtools_dir'});
my $path2Samtools = $ENV{'ngs_samtools_dir'};

die "\$ngs_picard_dir not defined" if (!$ENV{'ngs_picard_dir'});
my $path2Picard= $ENV{'ngs_picard_dir'};

die "\$ngs_bwa_dir not defined\n" if (!$ENV{'ngs_bwa_dir'});
my $path2Bwa = $ENV{'ngs_bwa_dir'};

die "\$ngs_gatk_dir not defined" if (!$ENV{'ngs_gatk_dir'});
my $path2Gatk= $ENV{'ngs_gatk_dir'};

# move to the working directory
chdir($path2Work);

sub read_path
{
    my ($filename) = @_;

    my $path = "$path2Runs/$filename";
    if ($runsInOwnDir)
    {
	$path = "$path2Runs/$name/$filename";
    }
    return $path;
}

# get the set of runs for this sample
my $in_fh = new IO::File;
$in_fh->open($reads, "r") or die "Could not open $reads\n$!";

my @paired_run_one;
my @paired_run_two;
my @single_run;

my @single_end_read_groups;
my @paired_end_read_groups;

while (my $line = <$in_fh>)
{
    chomp $line;
    my @tokens = split(/\t/, $line);
    if (scalar(@tokens) == 2)
    {
	my $path = read_path($tokens[1]);
	execute("cp $path ./");
        push(@single_run, "$tokens[1]");

	my @read_group_tokens = split(/,/, $tokens[0]);
	my $read_group_line = "\@RG\t" . join("\t", @read_group_tokens);
	push(@single_end_read_groups, $read_group_line);
    }
    elsif (scalar(@tokens) == 3)
    {
	my $path1 = read_path($tokens[1]);
	my $path2 = read_path($tokens[2]);
	execute("cp $path1 ./");
	execute("cp $path2 ./");
        push(@paired_run_one, "$tokens[1]");
        push(@paired_run_two, "$tokens[2]");

	my @read_group_tokens = split(/,/, $tokens[0]);
	my $read_group_line = "\@RG\t" . join("\t", @read_group_tokens);
	push(@paired_end_read_groups, $read_group_line);
    }
    else
    {
        print STDERR "Incorrectly formatted read information: $line\n";
	foreach my $token (@tokens)
	{
	    print STDERR "$token\n";
	}
        exit(1);
    }
}

$in_fh->close();

# align all the single end runs
my @per_run_bam_files;
for (my $i = 0; $i < scalar(@single_run); $i++)
{
    my $single_run_fastq = $single_run[$i];
    my $read_group = $single_end_read_groups[$i];

    # output file prefix
    my $output_prefix = "$name.$single_run_fastq";

    # align with BWA
    execute("$path2Bwa/bwa mem -M -R \"$read_group\" $path2SeqIndex.fasta $single_run_fastq  | gzip > $output_prefix.sam.gz");

    # clean up the FASTQ file
    execute("rm $single_run_fastq");

    # convert SAM to BAM
    execute("$path2Samtools/samtools view -hbS -o $output_prefix.unsorted.bam $output_prefix.sam.gz");
    execute("rm $output_prefix.sam.gz");

    # sort BAM file
    execute("$path2Samtools/samtools sort $output_prefix.unsorted.bam $output_prefix");
    execute("rm $output_prefix.unsorted.bam");
    execute("$path2Samtools/samtools index $output_prefix.bam");

    # store the name of the BAM file for merging
    push(@per_run_bam_files, "$output_prefix.bam");
}

# align all the paired end runs
for (my $i = 0; $i < scalar(@paired_run_one); $i++)
{
    my $paired_run_fastq_one = $paired_run_one[$i];
    my $paired_run_fastq_two = $paired_run_two[$i];
    my $read_group = $paired_end_read_groups[$i];

    # output file prefix
    my $output_prefix = "$name.$paired_run_fastq_one";

    # align with BWA
    execute("$path2Bwa/bwa mem -M -R \"$read_group\" $path2SeqIndex.fasta $paired_run_fastq_one $paired_run_fastq_two  | gzip > $output_prefix.sam.gz");

    # clean up the FASTQ files
    execute("rm $paired_run_fastq_one $paired_run_fastq_two");

    # convert SAM to BAM
    execute("$path2Samtools/samtools view -hbS -o $output_prefix.unsorted.bam $output_prefix.sam.gz");
    execute("rm $output_prefix.sam.gz");

    # sort BAM file
    execute("$path2Samtools/samtools sort $output_prefix.unsorted.bam $output_prefix");
    execute("rm $output_prefix.unsorted.bam");
    execute("$path2Samtools/samtools index $output_prefix.bam");

    # store the name of the BAM file for merging
    push(@per_run_bam_files, "$output_prefix.bam");
}

if (scalar(@per_run_bam_files) == 1)
{
    # only one run, rename it
    my $run = $per_run_bam_files[0];
    execute("mv $run $name.raw.bam");
    execute("mv $run.bai $name.raw.bam.bai");
}
else
{
    # merge the BAM files for the run
    my $all_runs = join(" ", @per_run_bam_files);
    my $all_rg = "";
    foreach my $run (@per_run_bam_files)
    {
	$all_rg .= " $run.header.rg";
	execute("$path2Samtools/samtools view -H $run | grep ^\@RG > $run.header.rg");
	execute("$path2Samtools/samtools view -H $run | grep -v ^\@RG > $name.header");
    }

    # this assumes that all headers are the same except for the read group definitions - should be ok
    execute("cat $all_rg | sort | uniq > $name.rg.uniq");
    execute("cat $name.header $name.rg.uniq > $name.header.sam");
    execute("$path2Samtools/samtools merge -c -p $name.raw.bam $all_runs");
    execute("$path2Samtools/samtools reheader $name.header.sam $name.raw.bam > $name.reheadered.bam");
    execute("mv $name.reheadered.bam $name.raw.bam");
    execute("rm $name.header $name.rg.uniq $name.header.sam");

    # remove the per-run files
    foreach my $run (@per_run_bam_files)
    {
	execute("rm $run*");
    }
}

# mark duplicates with Picard
execute("$path2Java/java -Xmx$memStack -jar $path2Picard/picard.jar MarkDuplicates INPUT=$name.raw.bam OUTPUT=$name.dedup.bam METRICS_FILE=$name.rmdup.metrics.txt ASSUME_SORTED=TRUE CREATE_INDEX=TRUE VALIDATION_STRINGENCY=SILENT &> $path2Logs/$name.markduplicates.log");
execute("cp $name.rmdup.metrics.txt $path2Stats/");
execute("rm $name.raw.bam* $name.rmdup.metrics.txt");

# detect suspicious intervals
execute("$path2Java/java -Xmx$memStack -jar $path2Gatk/GenomeAnalysisTK.jar -l INFO -T RealignerTargetCreator -R $path2SeqIndex.fasta -L $path2Targets -known $path2KnownIndels -o $name.intervals -I $name.dedup.bam &> $path2Logs/$name.realignertargetcreator.log");

# re-align around indels (mate pair fixing is done on the fly)
execute("$path2Java/java -Xmx$memStack -jar $path2Gatk/GenomeAnalysisTK.jar -l INFO -T IndelRealigner -R $path2SeqIndex.fasta -known $path2KnownIndels -targetIntervals $name.intervals -I $name.dedup.bam -o $name.realigned.bam &> $path2Logs/$name.indelrealigner.log");
execute("cp $name.intervals $path2Stats/");
execute("rm $name.dedup.bam* $name.intervals");

# count covariates for base quality re-calibration
execute("$path2Java/java -Xmx$memStack -jar $path2Gatk/GenomeAnalysisTK.jar -l INFO -T BaseRecalibrator -R $path2SeqIndex.fasta -L $path2Targets -knownSites $path2Dbsnp -I $name.realigned.bam -o $name.recal.grp &> $path2Logs/$name.baserecalibrator.log");
        
# apply re-calibration
execute("$path2Java/java -Xmx$memStack -jar $path2Gatk/GenomeAnalysisTK.jar -l INFO -T PrintReads -R $path2SeqIndex.fasta -BQSR $name.recal.grp -I $name.realigned.bam -o $name.recal.bam &> $path2Logs/$name.printreads.log");
execute("cp $name.recal.grp $path2Stats/");
execute("cp $name.recal.ba* $path2Bam/");
execute("rm $name.realigned* $name.recal.grp");

# collect alignment metrics with Picard
execute("$path2Java/java -Xmx$memStack -jar $path2Picard/picard.jar CollectAlignmentSummaryMetrics INPUT=$name.recal.bam OUTPUT=$name.alignment.metrics.txt ASSUME_SORTED=TRUE VALIDATION_STRINGENCY=SILENT &> $path2Logs/$name.alignmentmetrics.log");
execute("cp $name.alignment.metrics.txt $path2Stats/");
execute("rm $name.alignment.metrics.txt");

# genotype sample
execute("$path2Java/java -Xmx$memStack -jar $path2Gatk/GenomeAnalysisTK.jar -l INFO -T HaplotypeCaller -R $path2SeqIndex.fasta -I $name.recal.bam -stand_call_conf 50.0 -stand_emit_conf 10.0 --emitRefConfidence GVCF --variant_index_type LINEAR --variant_index_parameter 128000 -o $name.g.vcf.gz -L $path2Targets -ip $targetPadding &> $path2Logs/$name.haplotypecaller.log");
execute("cp $name.g.vcf* $path2Gvcf/");

# clean up
execute("rm -r $name*");
