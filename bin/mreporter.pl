#!/usr/bin/perl
# ABSTRACT: Monitoring::Reporter CLI
# PODNAME: mreporter.pl
use strict;
use warnings;

use Monitoring::Reporter::Cmd;

# All the magic is done using MooseX::App::Cmd, App::Cmd and MooseX::Getopt
my $mreporter = Monitoring::Reporter::Cmd::->new();
$mreporter->run();

=head1 NAME

zrerpoter - Monitoring::Reporter CLI

=cut
