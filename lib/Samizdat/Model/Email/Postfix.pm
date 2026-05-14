package Samizdat::Model::Email::Postfix;

use Mojo::Base -base, -signatures;
use Mojo::Pg;
use Mojo::mysql;
use Mojo::JSON qw(decode_json);
use IPC::Run3 ();
use Carp qw(croak);

has 'config';   # manager.email config section

# Connection pool to the postfixadmin database. Built lazily from the DSN of
# the active env; scheme picks between Mojo::Pg and Mojo::mysql.
has db => sub ($self) {
  my $dsn = $self->_dsn;
  if ($dsn =~ m{^mysql://}i) {
    my $m = Mojo::mysql->new($dsn);
    $m->max_connections(5);
    return $m;
  }
  if ($dsn =~ m{^postgres(?:ql)?://}i) {
    my $pg = Mojo::Pg->new($dsn);
    $pg->max_connections(5);
    return $pg;
  }
  croak "Unsupported postfixadmin DSN scheme: $dsn";
};

sub _dsn ($self) {
  my $cfg = $self->config or croak 'manager.email config missing';
  my $env = $cfg->{default_env} || 'production';
  my $envcfg = $cfg->{env}{$env}
    or croak "manager.email.env.$env not configured";
  my $dsn = $envcfg->{dsn}
    or croak "manager.email.env.$env.dsn not set";
  return $dsn;
}

sub _postfix ($self) { $self->config->{postfix} || {} }

sub _bin ($self, $name) {
  my $dir = $self->_postfix->{bindir};
  return $dir ? "$dir/$name" : $name;
}

# Run a command and return { ok, stdout, stderr, exit, error }
sub _run ($self, @cmd) {
  my ($out, $err);
  my $ok = eval { IPC::Run3::run3(\@cmd, \undef, \$out, \$err); 1 };
  my $exit = $?;
  return {
    ok     => ($ok && $exit == 0),
    stdout => $out // '',
    stderr => $err // '',
    exit   => $exit >> 8,
    error  => $@ || '',
  };
}

# Postfix queue (postqueue -j prints one JSON record per message)
sub queue_list ($self) {
  my $r = $self->_run($self->_bin('postqueue'), '-j');
  return [] unless $r->{ok};
  my @items;
  for my $line (split /\n/, $r->{stdout}) {
    next unless length $line;
    my $msg = eval { decode_json($line) };
    push @items, $msg if $msg;
  }
  return \@items;
}

# Flush the deferred queue
sub queue_flush ($self) { $self->_run($self->_bin('postqueue'), '-f') }

# Mail-queue management (id may be 'ALL')
sub queue_delete  ($self, $id) { $self->_run($self->_bin('postsuper'), '-d', $id) }
sub queue_hold    ($self, $id) { $self->_run($self->_bin('postsuper'), '-h', $id) }
sub queue_release ($self, $id) { $self->_run($self->_bin('postsuper'), '-H', $id) }

# Read postfix config. With no key returns the full main.cf dump (as text);
# with a key returns just the value, or undef on failure.
sub postconf ($self, $key = undef) {
  my @args = defined $key ? ($key) : ();
  my $r = $self->_run($self->_bin('postconf'), @args);
  return undef unless $r->{ok};
  return $r->{stdout} unless defined $key;
  my ($val) = $r->{stdout} =~ /^\Q$key\E\s*=\s*(.*)$/m;
  return $val;
}

# Rebuild a postfix lookup table (transport, sasl, etc.)
sub postmap ($self, $path) { $self->_run($self->_bin('postmap'), $path) }

# postfix reload (may need sudo/doas — set manager.email.postfix.reload_via)
sub reload ($self) {
  my $via = $self->_postfix->{reload_via};
  my @cmd = ($self->_bin('postfix'), 'reload');
  unshift @cmd, $via if $via;
  $self->_run(@cmd);
}

1;

=head1 NAME

Samizdat::Model::Email::Postfix - Postfixadmin DB connection + local postfix CLI ops

=head1 SYNOPSIS

  # Used via the `postfix` helper registered in Samizdat::Plugin::Email
  my $queue = $c->postfix->queue_list;
  $c->postfix->queue_delete($id);
  $c->postfix->reload;

  # The underlying postfixadmin connection (Mojo::Pg or Mojo::mysql)
  my $db = $c->postfix->db->db;

=head1 CONFIGURATION

Under C<manager.email> in F<samizdat.yml>:

  default_env: test
  env:
    production:
      dsn: mysql://postfixadmin:s3cr3t@mail.example.com/postfixadmin
    test:
      dsn: postgresql://samizdat@%2Fvar%2Frun%2Fpostgresql/samizdat
  postfix:
    bindir: /usr/sbin      # location of postqueue/postsuper/postconf/postmap
    reload_via: sudo       # prepended to `postfix reload` (omit to run direct)

The DSN scheme selects the driver (C<mysql://> => L<Mojo::mysql>, otherwise
L<Mojo::Pg>). All postfixadmin tables live in the C<postfix> schema on
PostgreSQL; on MySQL they live in the configured database.

=cut
