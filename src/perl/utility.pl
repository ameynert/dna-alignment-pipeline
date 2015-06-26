#!/usr/bin/perl -w

=head1 NAME

utility.pl

=head1 AUTHOR

Alison Meynert (alison.meynert@igmm.ed.ac.uk)

=head1 DESCRIPTION

Repeatedly used utility functions for the pipeline.

=cut

use strict;
use Sys::Hostname;

# debug and verbose variables
our $debug = 0;
if (defined $ENV{'ngs_debug'}) { $debug = $ENV{'ngs_debug'}; }

our $verbose = 0;
if (defined $ENV{'verbose'}) { $debug = $ENV{'verbose'}; }                                                                                                                                                       
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

1;
