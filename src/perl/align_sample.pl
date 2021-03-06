#!/usr/bin/perl -w

=head1 NAME

align_sample.pl

=head1 AUTHOR

Alison Meynert (alison.meynert@igmm.mrc.ac.uk)

=head1 DESCRIPTION

For a set of DNA high-throughput sequencing runs, aligns the reads using bwa mem.
Merges the alignments and marks duplicates with Picard. Does local re-alignment 
around indels and score re-calibration with GATK. Generates the GVCF genotyping
information for the sample. Output is a single indexed BAM file and a GVCF file,
plus associated statistics.

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
          Read group in form ID:id,LB:lib,PL:platform, etc. followed by one (single-end) or two (paired-end) file names
};

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

# use specified working directory if available, otherwise create temp directory
my $path2Work;
if ($ENV{'hts_work_dir'})
{
    $path2Work = $ENV{'hts_work_dir'};
    execute("mkdir -p $path2Work/$name");
    $path2Work .= "/$name";
}
else
{
    $path2Work = File::Temp->newdir(); 
}

############### project directories ##################
die "\$hts_logs_dir not defined" if (!$ENV{'hts_logs_dir'});
my $path2Logs = $ENV{'hts_logs_dir'};

die "\$hts_runs_in_dir not defined" if (!$ENV{'hts_runs_in_dir'});
my $path2Runs = $ENV{'hts_runs_in_dir'};

die "\$hts_stats_dir not defined" if (!$ENV{'hts_stats_dir'});
my $path2Stats = $ENV{'hts_stats_dir'};

die "\$hts_bam_out_dir not defined" if (!$ENV{'hts_bam_out_dir'});
my $path2Bam = $ENV{'hts_bam_out_dir'};

############### project options ##################
my $runsInOwnDir;
if (defined $ENV{'hts_runs_in_own_dirs'}) { $runsInOwnDir = $ENV{'hts_runs_in_own_dirs'}; }

my $memStack = "2g";
if (defined $ENV{'hts_java_memstack'}) { $memStack = $ENV{'hts_java_memstack'}; }

my $runHaplotypeCaller = 0;
if (defined $ENV{'hts_run_haplotype_caller'}) { $runHaplotypeCaller = $ENV{'hts_run_haplotype_caller'}; }
my $path2Gvcf;
if ($runHaplotypeCaller)
{
    die "\$hts_gvcf_dir not defined" if (!$ENV{'hts_gvcf_dir'});
    $path2Gvcf = $ENV{'hts_gvcf_dir'};
}

my $useTargets = 0;
if (defined $ENV{'hts_use_target_intervals'}) { $useTargets = $ENV{'hts_use_target_intervals'}; }

my $targetOptions = "";
my $path2Coverage;
if ($useTargets)
{
    die "\$hts_target_file not defined" if (!$ENV{'hts_target_file'});
    my $path2Targets = $ENV{'hts_target_file'};

    my $targetPadding = 0;
    if (defined $ENV{'hts_target_interval_padding'}) { $targetPadding = $ENV{'hts_target_interval_padding'}; }

    if ($targetPadding)
    {
	$targetOptions = "-L $path2Targets -ip $targetPadding";
    }
    else
    {
	$targetOptions = "-L $path2Targets";
    }

    die "\$hts_coverage_dir not defined" if (!$ENV{'hts_coverage_dir'});
    $path2Coverage = $ENV{'hts_coverage_dir'};
}

############### external data ##################
die "\$hts_reference_seq not defined" if (!$ENV{'hts_reference_seq'});
my $path2RefSeq = $ENV{'hts_reference_seq'};

die "\$hts_dbsnp_file not defined" if (!$ENV{'hts_dbsnp_file'});
my $path2Dbsnp = $ENV{'hts_dbsnp_file'};

die "\$hts_known_indels_1 not defined" if (!$ENV{'hts_known_indels_1'});
my $path2KnownIndels = $ENV{'hts_known_indels_1'};

for (my $i = 2; $i <= 10; $i++)
{
    if ($ENV{"hts_known_indels_$i"})
    {
	$path2KnownIndels .= sprintf(" -known %s", $ENV{"hts_known_indels_$i"});
    }
}

############### external software ##################
die "\$hts_picard not defined" if (!$ENV{'hts_picard'});
my $path2Picard = $ENV{'hts_picard'};

die "\$hts_gatk not defined" if (!$ENV{'hts_gatk'});
my $path2Gatk = $ENV{'hts_gatk'};

# correctly generates the read path for input FASTQ files depending on samples
# being in a shared directory or in one directory per sample
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

# debug and verbose variables
my $debug = 0;
if (defined($ENV{'hts_debug'})) { $debug = $ENV{'hts_debug'}; }

my $verbose = 0;
if (defined($ENV{'hts_verbose'})) { $verbose = $ENV{'hts_verbose'}; }

# command execution with optional debugging
sub execute
{
    my $command = shift;

    if ($debug || $verbose)
    {
        my $date = `date`;
        print "$date\n";
        print "$command\n\n";
    }
    if (!$debug)
    {
        `$command`;
    }
}

# move to the working directory
chdir($path2Work);

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
    execute("bwa mem -M -R \"$read_group\" $path2RefSeq $single_run_fastq | samtools view -Su /dev/stdin | samtools sort /dev/stdin $output_prefix");

    # clean up the FASTQ file
    execute("rm $single_run_fastq");

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
    execute("bwa mem -M -R \"$read_group\" $path2RefSeq $paired_run_fastq_one $paired_run_fastq_two | samtools view -Su /dev/stdin | samtools sort /dev/stdin $output_prefix");

    # clean up the FASTQ files
    execute("rm $paired_run_fastq_one $paired_run_fastq_two");

    # store the name of the BAM file for merging
    push(@per_run_bam_files, "$output_prefix.bam");
}

if (scalar(@per_run_bam_files) == 1)
{
    # only one run, rename it
    my $run = $per_run_bam_files[0];
    execute("mv $run $name.raw.bam");
}
else
{
    # merge the BAM files for the run
    my $all_runs = join(" ", @per_run_bam_files);
    my $all_rg = "";
    foreach my $run (@per_run_bam_files)
    {
	$all_rg .= " $run.header.rg";
	execute("samtools view -H $run | grep ^\@RG > $run.header.rg");
	execute("samtools view -H $run | grep -v ^\@RG > $name.header");
    }

    # this assumes that all headers are the same except for the read group definitions - should be ok
    execute("cat $all_rg | sort | uniq > $name.rg.uniq");
    execute("cat $name.header $name.rg.uniq > $name.header.sam");
    execute("samtools merge -c -p $name.raw.bam $all_runs");
    execute("samtools reheader $name.header.sam $name.raw.bam > $name.reheadered.bam");
    execute("mv $name.reheadered.bam $name.raw.bam");
    execute("rm $name.header $name.rg.uniq $name.header.sam");

    # remove the per-run files
    foreach my $run (@per_run_bam_files)
    {
	execute("rm $run*");
    }
}

# mark duplicates with Picard
execute("java -Xmx$memStack -jar $path2Picard MarkDuplicates INPUT=$name.raw.bam OUTPUT=$name.dedup.bam METRICS_FILE=$name.rmdup.metrics.txt ASSUME_SORTED=TRUE CREATE_INDEX=TRUE VALIDATION_STRINGENCY=SILENT &> $path2Logs/$name.markduplicates.log");
execute("cp $name.rmdup.metrics.txt $path2Stats/");
execute("rm $name.raw.bam* $name.rmdup.metrics.txt");

# detect suspicious intervals
execute("java -Xmx$memStack -jar $path2Gatk -l INFO -T RealignerTargetCreator -R $path2RefSeq $targetOptions -known $path2KnownIndels -o $name.intervals -I $name.dedup.bam &> $path2Logs/$name.realignertargetcreator.log");

# re-align around indels (mate pair fixing is done on the fly)
execute("java -Xmx$memStack -jar $path2Gatk -l INFO -T IndelRealigner -R $path2RefSeq -known $path2KnownIndels -targetIntervals $name.intervals -I $name.dedup.bam -o $name.realigned.bam &> $path2Logs/$name.indelrealigner.log");
execute("cp $name.intervals $path2Stats/");
execute("rm $name.dedup.bam* $name.intervals");

# count covariates for base quality re-calibration
execute("java -Xmx$memStack -jar $path2Gatk -l INFO -T BaseRecalibrator -R $path2RefSeq $targetOptions -knownSites $path2Dbsnp -I $name.realigned.bam -o $name.recal.grp &> $path2Logs/$name.baserecalibrator.log");
        
# apply re-calibration
execute("java -Xmx$memStack -jar $path2Gatk -l INFO -T PrintReads -R $path2RefSeq -BQSR $name.recal.grp -I $name.realigned.bam -o $name.recal.bam &> $path2Logs/$name.printreads.log");
execute("cp $name.recal.grp $path2Stats/");
execute("cp $name.recal.ba* $path2Bam/");
execute("rm $name.realigned* $name.recal.grp");

# collect alignment metrics with Picard
execute("java -Xmx$memStack -jar $path2Picard CollectAlignmentSummaryMetrics INPUT=$name.recal.bam OUTPUT=$name.alignment.metrics.txt ASSUME_SORTED=TRUE VALIDATION_STRINGENCY=SILENT &> $path2Logs/$name.alignmentmetrics.log");
execute("cp $name.alignment.metrics.txt $path2Stats/");
execute("rm $name.alignment.metrics.txt");

# if target file is specified, run coverage on target intervals
if ($useTargets)
{
    execute("java -Xmx$memStack -jar $path2Gatk -T DepthOfCoverage -l INFO -R $path2RefSeq -I $name.recal.bam $targetOptions -o $name.depths --omitDepthOutputAtEachBase --interval_merging OVERLAPPING_ONLY &> $path2Logs/$name.coverage.log");
    execute("cp $name.depths* $path2Coverage/");
}

# genotype sample
if ($runHaplotypeCaller)
{
    execute("java -Xmx$memStack -jar $path2Gatk -l INFO -T HaplotypeCaller -R $path2RefSeq -I $name.recal.bam -stand_call_conf 50.0 -stand_emit_conf 10.0 --emitRefConfidence GVCF --variant_index_type LINEAR --variant_index_parameter 128000 -o $name.g.vcf.gz $targetOptions &> $path2Logs/$name.haplotypecaller.log");
    execute("cp $name.g.vcf* $path2Gvcf/");
}

# clean up
execute("rm -r $name*");
