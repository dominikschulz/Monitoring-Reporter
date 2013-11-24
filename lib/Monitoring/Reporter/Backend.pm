package Monitoring::Reporter::Backend;
# ABSTRACT: Monitoring dashboard backend

use Moose;
use namespace::autoclean;

use Cache::MemoryCache;

has 'cache' => (
    'is'      => 'rw',
    'isa'     => 'Cache::Cache',
    'lazy'    => 1,
    'builder' => '_init_cache',
);

with qw(Config::Yak::RequiredConfig Log::Tree::RequiredLogger);

sub _init_cache {
    my $self = shift;

    my $Cache = Cache::MemoryCache::->new({
      'namespace'          => 'MonitoringReporter',
      'default_expires_in' => 600,
    });

    return $Cache;
}

=method fetch_n_store

Fetch a result from cache or DB.

=cut
sub fetch_n_store {
    my $self = shift;
    my $query = shift;
    my $timeout = shift;
    my @args = @_;

    my $key = $query.join(',',@args);

    my $result = $self->cache()->get($key);

    if( ! defined($result) ) {
        $result = $self->fetch($query,@args);
        $self->cache()->set($key,$result,$timeout);
    }

    return $result;
}

=method fetch

Fetch a result directly from DB.

=cut
sub fetch {
  my $self = shift;
  my $query = shift;
  my @args = @_;

  die('Not implemented!');
}

=method triggers

Retrieve all matching triggers.

=cut
sub triggers {
  my $self = shift;

  die('Not implemented');
}

=method disabled_actions

Retrieve all disabled actions.

=cut
sub disabled_actions {
  my $self = shift;

  die('Not implemented');
}

=method enable_actions

Enables all actions.

=cut
sub enable_actions {
  my $self = shift;
 
  die('Not implemented');
}

=method unsupported_items

Retrieve all unsupported items.

=cut
sub unsupported_items {
  my $self = shift;

  die('Not implemented');
}

=method unattended_alarms

Retrieve all unsupported items.

=cut
sub unattended_alarms {
  my $self = shift;
  my $time = shift || 3600;
 
  die('Not implemented');
}

=method history

Retrieve all triggers.

=cut
sub history {
  my $self = shift;
  my $max_age = shift // 30;
  my $max_num = shift // 100;

  die('Not implemented');
}
__PACKAGE__->meta->make_immutable;

1; # End of Monitoring::Reporter::Backend

__END__

=head1 NAME

Monitoring::Reporter::Backend - Monitoring dashboard backend

=cut

