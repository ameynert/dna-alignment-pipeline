#!/usr/bin/perl -w

=head1 NAME

split_coordinates.pl

=head1 AUTHOR

Alison Meynert (alison.meynert@igmm.ed.ac.uk)

=head1 DESCRIPTION

Splits coordinates into N approximately equal size files.

=cut

use strict;

# Perl
use IO::File;
use Getopt::Long;

my $usage = qq{USAGE:
$0 [--help]
  --input  Input file (0-based, end-exclusive BED track format)
  --output Output file prefix, to be appended with ".1.bed", ".2.bed", etc.
  --count  Number of files to output
};

my $help = 0;
my $input;
my $output;
my $count;

GetOptions(
	   'help'     => \$help,
	   'input=s'  => \$input,
	   'output=s' => \$output,
	   'count=i'  => \$count
) or die $usage;

if ($help || !$input || !$output || !$count)
{
    print $usage;
    exit(0);
}

my $in_fh = new IO::File;
$in_fh->open($input, "r") or die "Could not open $input\n$!";

my $total = 0;
while (my $line = <$in_fh>)
{
    next if ($line =~ /^track/);
    next if ($line =~ /^browser/);

    chomp $line;
    my @tokens = split(/\t/, $line);
    $total += ($tokens[2] - $tokens[1]);
}

$in_fh->close();

my $total_per_file = $total / $count;
my $current = 0;
my $overall = 0;
my $index = 1;

my $out_fh = new IO::File;
$out_fh->open("$output.$index.bed", "w") or die "Could not open $output.$index.bed\n$!";

$in_fh->open($input, "r") or die "Could not open $input\n$!";

while (my $line = <$in_fh>)
{
    next if ($line =~ /^track/);
    next if ($line =~ /^browser/);

    print $out_fh "$line";

    chomp $line;
    my @tokens = split(/\t/, $line);
    $current += ($tokens[2] - $tokens[1]);
    $overall += ($tokens[2] - $tokens[1]);

    if ($current >= $total_per_file && $overall < $total)
    {
	# open new output file
	$out_fh->close();
	$index++;
	$current = 0;
	$out_fh->open("$output.$index.bed", "w") or die "Could not open $output.$index.bed\n$!";
    }
}

$out_fh->close();
$in_fh->close();
