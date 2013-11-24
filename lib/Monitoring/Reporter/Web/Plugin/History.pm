package Monitoring::Reporter::Web::Plugin::History;
# ABSTRACT: List all triggers

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
use Template;

# extends ...
extends 'Monitoring::Reporter::Web::Plugin';
# has ...
# with ...
# initializers ...
sub _init_fields { return [qw(limit offset refresh age num)]; }

sub _init_alias { return 'list_history'; }

# your code here ...
=method execute

List all active triggers.

=cut
sub execute {
    my $self = shift;
    my $request = shift;

    my $refresh  = $request->{'refresh'} || 360;
    my $age      = $request->{'age'}     || 30;
    my $num      = $request->{'num'}     || 100;
    my $triggers = $self->mr()->history($age,$num);

    my $body;
    $self->tt()->process(
        'list_history.tpl',
        {
            'triggers' => $triggers,
            'refresh'  => $refresh,
            'title'    => 'Monitoring Trigger History',
            'age'      => $age,
            'num'      => $num,
        },
        \$body,
    ) or $self->logger()->log( message => 'TT error: '.$self->tt()->error, level => 'warning', );

    return [ 200, [
      'Content-Type', 'text/html',
      'Cache-Control', 'max-age='.($refresh-1).', private',
    ], [$body] ];
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Monitoring::Reporter::Web::API::Plugin::History - List all triggers

=cut
