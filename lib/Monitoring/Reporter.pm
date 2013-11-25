package Monitoring::Reporter;
# ABSTRACT: Monitoring dashboard

use Moose;
use namespace::autoclean;

use DBI;
use Cache::MemoryCache;
use Try::Tiny;

has 'backends' => (
    'is'      => 'rw',
    'isa'     => 'HashRef',
    'lazy'    => 1,
    'builder' => '_init_backends',
);

has 'cache' => (
    'is'      => 'rw',
    'isa'     => 'Cache::Cache',
    'lazy'    => 1,
    'builder' => '_init_cache',
);

has 'priorities' => (
    'is'      => 'rw',
    'isa'     => 'ArrayRef',
    'default' => sub { [] },
);

has 'warn_unsupported' => (
    'is'      => 'rw',
    'isa'     => 'Bool',
    'default' => 0,
);

has 'warn_unattended' => (
    'is'      => 'rw',
    'isa'     => 'Bool',
    'default' => 0,
);

has 'backend_init_failures' => (
    'is'      => 'rw',
    'isa'     => 'ArrayRef',
    'default' => sub { [] },
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

sub _init_backends {
  my $self = shift;

  my $backends_config = $self->config()->get( 'Monitoring::Reporter::Backend', { Default => {}, }, );
  my $backends = {};

  BACKEND: foreach my $backend ( sort keys %{$backends_config} ) {
    my $arg_ref = {
      'cache'     => $self->cache(),
      'config'    => $self->config(),
      'logger'    => $self->logger(),
      'name'      => $backend,
    };

    my $klass = 'Monitoring::Reporter::Backend::'.$backends_config->{$backend}->{'type'}; 
    ## no critic (ProhibitStringyEval)
    my $eval_status = eval "require $klass;";
    ## use critic
    if(!$eval_status) {
      $self->logger()->log( message => 'Failed to log backend '.$klass.': '.$@, level => 'warning', );
      next BACKEND;
    }
    try {
      my $BE = $klass->new($arg_ref);
      $backends->{$backend} = $BE;
      $self->logger()->log( message => 'Initialized backend '.$klass, level => 'debug', );
    } catch {
      $self->logger()->log( message => 'Failed to initialize backend '.$klass.' w/ error: '.$_, level => 'warning', );
      push(@{$self->backend_init_failures()}, {
        'severity'  => 'disaster',
        'priority'  => 5,
        'acknowledged' => 0,
        'host'      => $backend,
        'description' => 'Backend init failed!',
        'lastvalue' => '',
        'comments'  => 'Please check the mreporter logs for any backend failures!',
      });
    };
  }

  if(scalar(keys %{$backends}) < 1) {
    $self->logger()->log( message => 'No Backends initialized! Check your config and your logs!', level => 'error', );
  }

  return $backends;
}

=method triggers

Retrieve all matching triggers.

=cut
sub triggers {
  my $self = shift;

  my $row_ref = $self->_do_backend_action('triggers');

  # if there are any permanent backend initialization failures, apped them to the
  # head of the trigger list
  if($self->backend_init_failures() && scalar($self->backend_init_failures()) > 0) {
    unshift(@{$row_ref}, @{$self->backend_init_failures()});
  }

  # Post processing
  # Sort triggers by:
  # 1.) priority
  # 2.) lastchange (newer alarms are on top)
  # 3.) hostname
  $row_ref = [sort { 
    (defined($b->{'priority'}) ? $b->{'priority'} : 0) <=> (defined($a->{'priority'}) ? $a->{'priority'} : 0)
      ||
    (defined($b->{'lastchange'}) ? $b->{'lastchange'} : 0) <=> (defined($a->{'lastchange'}) ? $a->{'lastchange'} : 0)
      ||
    ($a->{'host'} cmp $b->{'host'}) } @{$row_ref}];
  # - Sort acked triggers to the end
  my @unacked = ();
  my @acked   = ();
  ROW: foreach my $row (@{$row_ref}) {
    if(!$row || ref($row) ne 'HASH') {
      $self->logger()->log( message => 'Skipping invalid row: '.$row, level => 'warning', );
      next ROW;
    }
    # this should be the last post-processing action
    if($row->{'acknowledged'}) {
     push(@acked,$row);
    } else {
     push(@unacked,$row);
    }
  }
  # sort acked triggers to the end
  my @rows = (@unacked,@acked);

  # Check for any unsupported items and prepend a warning as a pseudo trigger
  # if there are some
  if($self->warn_unsupported()) {
    my $unsupported = $self->unsupported_items();
    if($unsupported && ref($unsupported) eq 'ARRAY' && scalar @{$unsupported} > 0) {
      my $row = {
         'severity'     => 'high',
         'host'         => 'Monitoring',
         'description'  => 'Unsupported Items!',
         'lastchange'   => time(),
         'comments'     => 'There are '.(scalar @{$unsupported}).' unsupported items.',
      };
      unshift @rows, $row;
    }
  }

  # Check for any unattended alarms and prepend a warning as a pseudo trigger
  # if there are some
  if($self->warn_unattended()) {
    my $unattended = $self->unattended_alarms();
    if($unattended && ref($unattended) eq 'ARRAY' && scalar @{$unattended} > 0) {
      my $row = {
         'severity'     => 'high',
         'host'         => 'Monitoring',
         'description'  => 'Unattended Alarms!',
         'lastchange'   => time(),
         'comments'     => 'There are '.$unattended->[0].' unattended alarms.',
      };
      unshift @rows, $row;
    }
  }
    # Check for any disabled actions and prepend a warning as a pseudo trigger
    # if there are some
    my $disacts = $self->disabled_actions();
   if($disacts && ref($disacts) eq 'ARRAY' && scalar @{$disacts} > 0) {
      my $row = {
         'severity'     => 'high',
         'host'         => 'Monitoring',
         'description'  => 'Notifications disabled!',
         'lastchange'   => time(),
         'comments'     => 'There are '.(scalar @{$disacts}).' notifications disabled. Please make sure you enable them again in time.',
      };
      unshift @rows, $row;
   }

    return \@rows;
}

=method disabled_actions

Retrieve all disabled actions.

=cut
sub disabled_actions {
  my $self = shift;

  return $self->_do_backend_action('disabled_actions');
}

=method enable_actions

Enables all actions.

=cut
sub enable_actions {
  my $self = shift;

  return $self->_do_backend_action('enable_actions');
}

=method unsupported_items

Retrieve all unsupported items.

=cut
sub unsupported_items {
  my $self = shift;

  return $self->_do_backend_action('unsupported_items');
}

=method unattended_alarms

Retrieve all unsupported items.

=cut
sub unattended_alarms {
  my $self = shift;
  my $time = shift || 3600;

  return $self->_do_backend_action('unattended_alarms', { 'time' => 3600, }, );
}

=method history

Retrieve all triggers.

=cut
sub history {
  my $self = shift;
  my $max_age = shift // 30;
  my $max_num = shift // 100;

  my $arg_ref = {
    'max_age'   => $max_age,
    'max_num'   => $max_num,
  };
  return $self->_do_backend_action('history', $arg_ref);
}

=method selftest

Perform a quick self assessment.

=cut
sub selftest {
  my $self = shift;

  if(scalar(keys %{$self->backends()}) < 1) {
    return (0, 'No Backends configured!');
  }
  my $be_stati = $self->_do_backend_action('selftest');
  # TODO check backend stati
  #return (1, 'OK');
  return (0, 'Not implemented');
}

=method _do_backend_action

Execute the given action with the passed argument ref on all available backends.

=cut
sub _do_backend_action {
  my ($self, $action, $arg_ref) = @_;

  my @rows = ();

  BACKEND: foreach my $backend (sort keys %{$self->backends()}) {
    if($self->_backend_filter_match($backend, $arg_ref)) {
      $self->logger()->log( message => 'Executing action '.$action.' on backend '.$backend, level => 'debug', );
    } else {
      $self->logger()->log( message => 'Skipping Backend '.$backend.' for action '.$action.': No filter match.', level => 'notice', );
      next BACKEND;
    }
    my $row_ref; 
    try {
      $row_ref = $self->backends()->{$backend}->$action($arg_ref);
    } catch {
      $self->logger()->log( message => 'Failed to execute action '.$action.' on backend '.$backend.': '.$_, level => 'error', ); 
    };
    if($row_ref && ref($row_ref) eq 'ARRAY') {
      push(@rows,@{$row_ref});
    } else {
      $self->logger()->log( message => 'Ignoring non-ARRAY result from backend '.$backend.' for action '.$action, level => 'warning', );
      push(@rows, {
        'severity'  => 'disaster',
        'priority'  => 5,
        'acknowledged' => 0,
        'host'      => $backend,
        'description' => 'Backend call failed!',
        'lastvalue' => '',
        'comments'  => 'Please check the mreporter logs for any backend failures!',
      });
    }
  }

  return \@rows;
}

sub _backend_filter_match {
  my $self = shift;
  my $backend = shift;
  my $arg_ref = shift;

  # No backend given? Default to "MATCH"
  if(!$backend) {
    return 1;
  }

  # No arg_ref given or no hash? Default to "MATCH"
  if(!$arg_ref || ref($arg_ref) ne 'HASH') {
    return 1;
  }

  # No backend filter specified in arg_ref? Default to "MATCH"
  if(! exists $arg_ref->{'_backend_filter'}) {
    return 1;
  }

  my $filter = $arg_ref->{'_backend_filter'};
  if(ref($filter) eq 'Regexp') {
    # Regexp: Try to match against backend
    if($backend =~ m/$filter/) {
      return 1;
    } else {
      return;
    }
  } elsif(ref($filter) eq 'ARRAY') {
    # Array: Try to match backend against list
    foreach my $f (sort @{$filter}) {
      if($backend eq $f) {
        return 1;
      }
    }
    return;
  } elsif(!ref($filter)) {
    # Scalar/String: Try to match
    if($backend eq $filter) {
      return 1;
    } else {
      return;
    }
  } else {
    # Unknown filter condition: Default to "NO MATCH"
    # unkown filter type
    return;
  }
}

__PACKAGE__->meta->make_immutable;

1; # End of Monitoring::Reporter

__END__

=head1 NAME
_
Monitoring::Reporter - Monitoring dashboard

=cut

