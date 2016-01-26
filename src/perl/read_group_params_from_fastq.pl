#!/usr/bin/perl -w

=head1 NAME

read_group_params_from_fastq.pl

=head1 AUTHOR

Alison Meynert (alison.meynert@igmm.ed.ac.uk)

=head1 DESCRIPTION

Takes input from 'echo $filename; zcat $filename | head -1' and converts to
read group parameter file format (for input to align_sample.pl).

=cut

use strict;

# Perl
use IO::File;
use Getopt::Long;

my $usage = qq{USAGE:
$0 [--help]
  --input  Input file
  --output Output file
};

my $help = 0;
my $input;
my $output;

GetOptions(
	   'help'     => \$help,
	   'input=s'  => \$input,
	   'output=s' => \$output
) or die $usage;

if ($help || !$input || !$output)
{
    print $usage;
    exit(0);
}

my $in_fh = new IO::File;
$in_fh->open($input, "r") or die "Could not open $input\n$!";

my $out_fh = new IO::File;
$out_fh->open("$output", "w") or die "Could not open $output\n$!";

my %files;
while (my $file = <$in_fh>)
{
    chomp $file;
    my $fqhead = <$in_fh>;
    chomp $fqhead;

    my ($sample, $bfile) = split(/\//, $file);

    $bfile =~ /(.+)([12])\..*fastq\.gz/;

    $files{$sample}{$1}{$2}{'header'} = $fqhead;
    $files{$sample}{$1}{$2}{'file'}   = $bfile;
}

foreach my $sample (keys %files)
{
    foreach my $run (sort keys %{ $files{$sample} })
    {
	my $fqhead = $files{$sample}{$run}{1}{'header'};
	$fqhead =~ s/^\@//;
	my @tokens = split(":", $fqhead, 5);
	my $rg_id = join("_", @tokens[0..3]);

	printf $out_fh "ID:$rg_id,PU:$rg_id,PL:ILLUMINA,LB:$sample,SM:$sample\t%s", $files{$sample}{$run}{1}{'file'};
	if (exists($files{$sample}{$run}{2}))
	{
	    printf $out_fh "\t%s", $files{$sample}{$run}{2}{'file'};
	}
	print $out_fh "\n";
    }
}

$in_fh->close();
$out_fh->close();
