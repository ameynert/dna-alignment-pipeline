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
use Sys::Hostname;
use Getopt::Long;

my $usage = qq{USAGE:
$0 [--help]
  --input    Input VEP file
  --output   Output VEP file
};

my $help = 0;
my $input;
my $output;

GetOptions(
    'help'     => \$help,
    'input=s'  => \$input,
    'output=s' => \$output,
    ) or die $usage;

if ($help || !$input || !$output)
{
    print $usage;
    exit(0);
}

my $in_fh = new IO::File;
$in_fh->open($input, "r") or die "Could not open $input\n$!";

my $out_fh = new IO::File;
$out_fh->open($output, "w") or die "Could not open $output\n$!";

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
    printf $out_fh "%s", join("\t", @tokens[0..$last_idx]);

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
		printf $out_fh "\t$o";
	    }
	    else
	    {
		printf $out_fh "\t%s", $info{$column_keys[$i]};
	    }
	}
	else
	{
	    print $out_fh "\t.";
	}
    }
    print $out_fh "\n";
}

$in_fh->close();
$out_fh->close();
