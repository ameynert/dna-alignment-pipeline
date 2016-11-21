#!/usr/bin/perl -w

=head1 NAME

format_vep_extra_columns.pl

=head1 AUTHOR

Alison Meynert (alison.meynert@igmm.ed.ac.uk)

=head1 DESCRIPTION

Expands the 'Extra' column in VEP output to its component key/value pairs as new columns

=cut

use strict;

# Perl
use IO::File;
use IO::Zlib;
use Sys::Hostname;
use Getopt::Long;

my $usage = qq{USAGE:
$0 [--help]
  --input               Input VEP file
  --output              Output VEP file
  --skip-non-genic      Skips lines where the only consequence is one of "intergenic_variant, downstream_gene_variant, upstream_gene_variant, intron_variant"
  --protein-coding-only Only outputs lines where the feature biotype is "protein_coding"
};

my $help = 0;
my $input;
my $output;
my $skip_non_genic = 0;
my $protein_coding_only = 0;

GetOptions(
    'help'     => \$help,
    'input=s'  => \$input,
    'output=s' => \$output,
    'skip-non-genic' => \$skip_non_genic,
    'protein-coding-only' => \$protein_coding_only
    ) or die $usage;

if ($help || !$input || !$output)
{
    print $usage;
    exit(0);
}

my $in_fh;
my $out_fh;
if ($input =~ /gz$/)
{
    $in_fh = new IO::Zlib;
    $in_fh->open($input, "rb") or die "Could not open $input\n$!";
}
else
{
    $in_fh = new IO::File;
    $in_fh->open($input, "r") or die "Could not open $input\n$!";
}

if ($output =~ /gz$/)
{
    $out_fh = new IO::Zlib;
    $out_fh->open($output, "wb") or die "Could not open $output\n$!";
}
else
{
    $out_fh = new IO::File;
    $out_fh->open($output, "w") or die "Could not open $output\n$!";
}

my $standard_cols;
my @column_keys;

while (my $line = <$in_fh>)
{
    chomp $line;

    # just print headers
    if ($line =~ /^\#/)
    {

	if ($line =~ /\#\# (.+) : /)
	{
	    push(@column_keys, $1);
	    print $out_fh "$line\n";
	}
	elsif ($line =~ /\#Uploaded/)
	{
	    my @tokens = split(/\t/, $line);
	    my $last_idx = scalar(@tokens) - 2;
	    $standard_cols = scalar(@tokens) - 1;
	    printf $out_fh "%s\t%s\n", join("\t", @tokens[0..$last_idx]), join("\t", @column_keys);
	}
	else
	{
	    print $out_fh "$line\n";
	}

	next;
    }

    my @tokens = split(/\t/, $line);
    my $last_idx = scalar(@tokens) - 2;
    if (scalar(@tokens) == $standard_cols)
    {
	$last_idx = scalar(@tokens) - 1;
    }

    next if ($tokens[6] eq "intergenic_variant" || $tokens[6] eq "downstream_gene_variant" || $tokens[6] eq "upstream_gene_variant");
    next if ($tokens[6] eq "intron_variant");

    my $output_line = join("\t", @tokens[0..$last_idx]);

    my %info;

    if (scalar(@tokens) > $standard_cols)
    {
	my @pairs = split(/;/, $tokens[-1]);
	foreach my $pair (@pairs)
	{
	    my ($key, $value) = split(/=/, $pair);

	    if (length($value) == 0)
	    {
		$value = ".";
	    }

	    $info{$key} = $value;
	}
    }

    my $is_protein_coding = 0;
    for (my $i = 0; $i < scalar(@column_keys); $i++)
    {
	if (exists($info{$column_keys[$i]}))
	{
	    if ($column_keys[$i] eq "TCGA")
	    {
		my @pairs = split(/,/, $info{$column_keys[$i]});
		my %counts;
		foreach my $pair (@pairs)
		{
		    my ($class, $count) = split(/:/, $pair);
		    $counts{$class} += $count;
		}
		my $o = "";
		foreach my $class (sort keys %counts)
		{
		    $o .= sprintf("$class:%d,", $counts{$class});
		}
		chop $o;
		$output_line .= "\t$o";
	    }
	    elsif ($column_keys[$i] eq "BIOTYPE")
	    {
		if ($info{$column_keys[$i]} eq "protein_coding")
		{
		    $is_protein_coding = 1;
		}
		$output_line .= "\t" . $info{$column_keys[$i]};
	    }
	    else
	    {
		$output_line .= "\t" . $info{$column_keys[$i]};
	    }
	}
	else
	{
	    $output_line .= "\t.";
	}
    }

    if (!$protein_coding_only || ($protein_coding_only && $is_protein_coding))
    {
	print $out_fh "$output_line\n";
    }
}

$in_fh->close();
$out_fh->close();
