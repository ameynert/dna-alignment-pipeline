#!/usr/bin/perl -w

use IO::File;
use strict;

my $in_dir = shift;
my $sample_prefix = shift;

opendir(DIR, $in_dir) or die "Could not open $in_dir\n$!";
my @sub_dirs = grep(/$sample_prefix/, readdir(DIR));
closedir(DIR);

my %table;
my @categories;
my $first = 1;
foreach my $sub_dir (@sub_dirs)
{
    opendir(DIR, "$in_dir/$sub_dir") or die "Could not open $in_dir/$sub_dir\n$!";
    my @fastqc_dirs = grep(/\_fastqc$/, readdir(DIR));
    closedir(DIR);

    foreach my $fastqc_dir (@fastqc_dirs)
    {
	my $in_file = "$in_dir/$sub_dir/$fastqc_dir/summary.txt";
	my $in_fh = new IO::File;
	$in_fh->open($in_file, "r") or die "Could not open $in_file\n$!";
	while (my $line = <$in_fh>)
	{
	    chomp $line;
	    my ($res, $category, $fastq) = split(/\t/, $line);
	    push(@{ $table{$sub_dir}{$fastq} }, $res);
	    
	    if ($first)
	    {
		push(@categories, $category);
	    }
	}
	$in_fh->close();

	$first = 0;
    }
}

printf "Sample\tFastq\t%s\n", join("\t", @categories);

foreach my $sample (sort keys %table)
{
    foreach my $fastq (sort keys %{ $table{$sample} })
    {
	printf "$sample\t$fastq\t%s\n", join("\t", @{ $table{$sample}{$fastq} });
    }
}
