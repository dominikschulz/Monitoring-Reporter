package Monitoring::Reporter::Backend::NagiosLivestatus;
# ABSTRACT: Monitoring dashboard Nagios Backend

use Moose;
use namespace::autoclean;

use Monitoring::Livestatus;

has 'lsc' => (
    'is'      => 'rw',
    'isa'     => 'Monitoring::Livestatus',
    'lazy'    => 1,
    'builder' => '_init_lsc',
);

has 'cache_timeout' => (
    'is'      => 'rw',
    'isa'     => 'Int',
    'default' => 60,
);

has '_mapping' => (
  'is'  => 'ro',
  'isa' => 'HashRef',
  'lazy'  => 1,
  'builder' => '_init_mapping',
);

has '_severity_mapping' => (
  'is'  => 'ro',
  'isa' => 'HashRef',
  'lazy' => 1,
  'builder' => '_init_severity_mapping',
);

has '_priority_mapping' => (
  'is'  => 'ro',
  'isa' => 'HashRef',
  'lazy' => 1,
  'builder' => '_init_priority_mapping',
);

extends 'Monitoring::Reporter::Backend';

with qw(Config::Yak::RequiredConfig Log::Tree::RequiredLogger);

sub _init_lsc {
  my $self = shift;

  my $lsc_peer = $self->config()->get( 'Monitoring::Reporter::Backend::'.$self->name().'::Peer', { Default => '/var/lib/nagios3/rw/livestatus.sock', }, );

  if($lsc_peer && ref($lsc_peer) eq 'ARRAY') {
    my @peers = ();
    foreach my $peer (sort @{$lsc_peer}) {
      my $name = $peer;
      $name =~ s/[:\/]/_/g;
      push(@peers,{
        'name'  => $name,
        'peer'  => $peer,
      });
    }
    $lsc_peer = \@peers;
  }

  $self->logger()->log( message => 'Using LSC Peer: '.$lsc_peer, level => 'debug', );

  my $LSC = Monitoring::Livestatus::->new(
    'peer'        => $lsc_peer,
    'keepalive'   => 1,
    'warnings'    => 0,
    'verbose'     => 0,
    'use_threads' => 0,
  );

  return $LSC;
}

sub _init_mapping {
  my $self = shift;

=begin mapping

priority  - last_state
host      - host_display_name
description - plugin_output
hostid    - 0
triggerid - 0
itemid    - 0
lastvalue - plugin_output
lastclock - last_state_change
lastchange - last_time_ok
value     - plugin_output
comments  - ''
units     - ''
valuemapid - ''
triggerdepid - 0
=cut
  my $Mapping = {
    'priority'      => 'state',
    'host'          => 'host_display_name',
    'description'   => 'plugin_output',
    'hostid'        => undef,
    'triggerid'     => undef,
    'itemid'        => undef,
    'lastvalue'     => 'plugin_output',
    'lastclock'     => 'last_state_change',
    'lastchange'    => 'last_time_ok',
    'value'         => 'plugin_output',
    'comments'      => 'host_notes',
    'units'         => undef,
    'valuemapid'    => undef,
    'triggerpid'    => undef,
  };

  return $Mapping;
}

sub _init_priority_mapping {
  my $self = shift;

  my $PrioMapping = {
    '0'   => '0', # OK -> n.c.
    '1'   => '3', # WARNING -> Average
    '2'   => '4', # CRITICAL -> High
  };
  return $PrioMapping;
}

sub _init_severity_mapping {
  my $self = shift;

  my $SevMapping = {
    '0'   => 'information',
    '1'   => 'average',
    '2'   => 'high',
  };

  return $SevMapping;
}

=method fetch

Fetch a result directly from DB.

=cut
sub fetch {
  my $self = shift;
  my $query = shift;
  my @args = @_;

  my $refs = $self->lsc()->selectall_arrayref($query, { Slice => {}, });

  return $refs;
}

=method do

Execute an Stmt in the DB.

=cut
sub do {
  my $self = shift;
  my $query = shift;
  my @args = @_;

  return $self->lsc()->do($query, @args);
}

=method triggers

Retrieve all matching triggers.

=cut
sub triggers {
  my $self = shift;

  my @rows = ();

  $self->logger()->log( message => 'Nagios-Triggers', level => 'debug', );

  my $arr_refs = $self->fetch_n_store('GET services',$self->cache_timeout());

  foreach my $e (@{$arr_refs}) {
    my $row = {};
    foreach my $to (keys %{$self->_mapping()}) {
      my $from = $self->_mapping()->{$to};
      if(defined($from)) {
        if($to eq 'priority') {
          $row->{$to} = $self->_priority_mapping()->{$e->{$from}};
          $row->{'severity'} = $self->_severity_mapping()->{$e->{$from}};
        } else {
          $row->{$to} = $e->{$from};
        }
      } else {
        $row->{$to} = 0;
      }
    }
    push(@rows, $row);
  }

  return \@rows;
}

=method disabled_actions

Retrieve all disabled actions.

=cut
sub disabled_actions {
  my $self = shift;

  return []; # TODO not supported?
}

=method enable_actions

Enables all actions.

=cut
sub enable_actions {
  my $self = shift;

  return []; # TODO not supported?
}

=method unsupported_items

Retrieve all unsupported items.

=cut
sub unsupported_items {
    my $self = shift;

    return []; # TODO not supported?
}

=method unattended_alarms

Retrieve all unsupported items.

=cut
sub unattended_alarms {
    my $self = shift;
    
    return []; # TODO not supported
}

=method history

Retrieve all triggers.

=cut
sub history {
    my $self = shift;

    return []; # TODO not supported?
}
__PACKAGE__->meta->make_immutable;

1; # End of Monitoring::Reporter

__END__

=head1 NAME

Monitoring::Reporter - Monitoring dashboard

=cut

