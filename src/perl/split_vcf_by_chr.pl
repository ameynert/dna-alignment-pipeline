#!/usr/bin/perl -w

=head1 NAME

split_vcf_by_chr.pl

=head1 AUTHOR

Alison Meynert (alison.meynert@igmm.ed.ac.uk)

=head1 DESCRIPTION

Splits a VCF file into one file per chr (or contig).

=cut

#!/bin/perl -w

use IO::File;
use strict;

my @headers;
my %fhs;

while (my $line = <>)
{
    if ($line =~ /^\#/)
    {
	push(@headers, $line);
    }
    else
    {
	my ($chr, $rest) = split(/\t/, $line);

	my $out_fh;
	if (!exists($fhs{$chr}))
	{
	    $out_fh = new IO::File;
	    $out_fh->open("$chr.vcf", "w") or die "Could not open $chr.vcf\n$!";

	    for (my $i = 0; $i < scalar(@headers); $i++)
	    {
		print $out_fh "$headers[$i]";
	    }

	    $fhs{$chr} = $out_fh;
	}
	$out_fh = $fhs{$chr};

	print $out_fh "$line";
    }
}
