package Monitoring::Reporter::Backend::NagiosLivestatus;
# ABSTRACT: Monitoring dashboard Nagios Backend

use Moose;
use namespace::autoclean;

use Monitoring::Livestatus;
use Cache::MemoryCache;

has 'lsc' => (
    'is'      => 'rw',
    'isa'     => 'Monitoring::Livestatus::Class',
    'lazy'    => 1,
    'builder' => '_init_lsc',
);

has 'cache' => (
    'is'      => 'rw',
    'isa'     => 'Cache::Cache',
    'lazy'    => 1,
    'builder' => '_init_cache',
);

extends 'Monitoring::Reporter::Backend';

with qw(Config::Yak::RequiredConfig Log::Tree::RequiredLogger);

sub _init_lsc {
  my $self = shift;

  my $lsc_peer = $self->config()->get( 'Monitoring::Reporter::Backend::'.$self->name().'::Peer', { Default => '/var/lib/nagios3/rw/livestatus.sock', }, );

  my $LSC = Monitoring::Livestatus::->new(
    'peer'  => $lsc_peer,
  );

  return $LSC;
}

sub _init_cache {
    my $self = shift;

    my $Cache = Cache::MemoryCache::->new({
      'namespace'          => 'MonitoringReporter',
      'default_expires_in' => 600,
    });

    return $Cache;
}

=method fetch

Fetch a result directly from DB.

=cut
sub fetch {
    my $self = shift;
    my $query = shift;
    my @args = @_;

    my $sth = $self->dbh()->prepare($query)
        or die("Could not prepare query $query: ".$self->dbh()->errstr);

    $sth->execute(@args)
        or die("Could not execute query $query: ".$self->dbh()->errstr);

    my @result = ();

    while(my $ref = $sth->fetchrow_hashref()) {
        push(@result,$ref);
    }
    $sth->finish();

    return \@result;
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

  # TODO get services
  my $arr_refs = $self->lsc()->selectall_arrayref("GET hosts");
  $arr_refs = $self->lsc()->selectall_arrayref("GET services");
  # TODO get hosts

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

