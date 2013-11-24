#!/usr/bin/perl
# ABSTRACT: Monitoring Reporter CGI Endpoint
# PODNAME: mreporter-web.pl
use strict;
use warnings;

use Plack::Loader;

my $app = Plack::Util::load_psgi('mreporter-web.psgi');
Plack::Loader::->auto->run($app);

=head1 NAME

mreporter-web - Monitoring::Reporter web endpoint (CGI)

=cut
