package Monitoring::Reporter::Web::Plugin::Selftest;
# ABSTRACT: Monitoring Server Selftest

use 5.010_000;
use mro 'c3';
use feature ':5.10';

use Moose;
use namespace::autoclean;

# use IO::Handle;
# use autodie;
# use MooseX::Params::Validate;
# use Carp;
# use English qw( -no_match_vars );
# use Try::Tiny;

# extends ...
extends 'Monitoring::Reporter::Web::Plugin';
# has ...
# with ...
# initializers ...
sub _init_fields { return [qw()]; }

sub _init_alias { return 'healthcheck'; }

# your code here ...
=method execute

Perform an Monitoring Server Selftest/Healthcheck

=cut
sub execute {
   my $self = shift;
   my $request = shift;

   my ($ok, $msg_ref) = $self->mr()->selftest();
   my $body = join("\n", @{$msg_ref});
   my $status = 100;

   if($ok) {
     $body = join("\n", @{$msg_ref});
     $status = 200;
   } else {
      $status = 503;
   }

    return [ $status, [
      'Content-Type', 'text/plain',
      'Cache-Control', 'no-store, private', # no caching for the selftest
    ], [$body] ];
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Monitoring::Reporter::Web::API::Plugin::Selftest - Perform an Monitoring Server Selftest

=cut
