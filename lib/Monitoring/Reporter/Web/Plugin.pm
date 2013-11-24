package Monitoring::Reporter::Web::Plugin;
# ABSTRACT: baseclass for any web plugin

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
# has ...
has 'config' => (
    'is'            => 'ro',
    'isa'           => 'Config::Yak',
    'lazy'          => 1,
    'builder'       => '_init_config',
);

has 'logger' => (
    'is'            => 'rw',
    'isa'           => 'Log::Tree',
    'required'      => 1,
);

has 'tt' => (
    'is'            => 'rw',
    'isa'           => 'Template',
    'required'      => 1,
);

has 'fields' => (
    'is'            => 'ro',
    'isa'           => 'ArrayRef',
    'lazy'          => 1,
    'builder'       => '_init_fields',
);

has 'alias' => (
    'is'            => 'ro',
    'isa'           => 'Str',
    'lazy'          => 1,
    'builder'       => '_init_alias',
);

has 'mr' => (
    'is'            => 'rw',
    'isa'           => 'Monitoring::Reporter',
    'required'      => 1,
);
# with ...
# initializers ...
sub _init_alias { return ''; }

# your code here ...

no Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Monitoring::Reporter::Web::API::Plugin - baseclass for any web plugin

=cut

