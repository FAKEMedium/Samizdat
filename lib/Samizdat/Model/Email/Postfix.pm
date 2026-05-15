package Samizdat::Model::Email::Postfix;

use Mojo::Base -base, -signatures;
use Mojo::Pg;
use Mojo::mysql;
use Mojo::JSON qw(decode_json);
use IPC::Run3 ();
use Carp qw(croak);

has 'config';        # manager.email config section
has 'fallback_dsn';  # main samizdat DSN; used when manager.email has no env block

# Connection pool to the postfixadmin database. Built lazily from the DSN of
# the active env (or the fallback DSN); scheme picks Mojo::Pg vs Mojo::mysql.
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
  my $cfg = $self->config || {};
  my $env = $cfg->{default_env} || 'production';
  if (my $envcfg = $cfg->{env} && $cfg->{env}{$env}) {
    return $envcfg->{dsn} if $envcfg->{dsn};
  }
  # No dedicated DSN: fall back to the main samizdat DSN and assume the
  # postfixadmin tables live in the `postfix` schema there.
  return $self->fallback_dsn
    if $self->fallback_dsn;
  croak "no DSN for postfixadmin: set manager.email.env.$env.dsn or provide fallback_dsn";
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

# Show a queued message (headers + body) via `postcat -q $id`
sub queue_view ($self, $id) {
  my $r = $self->_run($self->_bin('postcat'), '-q', $id);
  return $r->{ok} ? $r->{stdout} : undef;
}

# Match a queue_list entry against a filter spec. Filter is a hashref of
# { sender => $re, recipient => $re, queue => $re } where each value is
# either a compiled qr// or a string treated as a regex source. A missing
# key means "match anything for that field".
sub _queue_match ($self, $item, $filter) {
  for my $field (qw(sender recipient queue)) {
    my $pat = $filter->{$field};
    next unless defined $pat && length $pat;
    my $re = ref $pat eq 'Regexp' ? $pat : qr/$pat/;
    if ($field eq 'recipient') {
      # postqueue -j emits recipients as a list of objects
      my $rcpts = $item->{recipients} || [];
      my $hit = 0;
      for my $r (@$rcpts) {
        my $addr = ref $r ? ($r->{address} // '') : $r;
        if ($addr =~ $re) { $hit = 1; last }
      }
      return 0 unless $hit;
    } else {
      my $val = $item->{$field} // '';
      return 0 unless $val =~ $re;
    }
  }
  return 1;
}

# Purge queued messages matching a filter. Safety:
#   - Without any filter regex you must pass `confirm => 'all'` (otherwise
#     refuses with { ok => 0, error => 'refusing unfiltered purge' }).
#   - `dry_run => 1` lists matches without deleting.
# Filter keys: sender, recipient, queue (all optional regex/string).
# Returns { ok, matched, deleted, ids => [...], errors => [...] }.
sub queue_purge ($self, $opts = {}) {
  my $filter = $opts->{filter} || {};
  my $has_filter = grep { defined $filter->{$_} && length $filter->{$_} } qw(sender recipient queue);
  if (!$has_filter && (($opts->{confirm} // '') ne 'all')) {
    return { ok => 0, error => 'refusing unfiltered purge (pass confirm => "all" or a filter)' };
  }

  my $items = $self->queue_list;
  my @matched = grep { $self->_queue_match($_, $filter) } @$items;
  my @ids = map { $_->{queue_id} // $_->{id} } @matched;

  if ($opts->{dry_run}) {
    return { ok => 1, matched => scalar @matched, deleted => 0, ids => \@ids, dry_run => 1 };
  }

  my (@deleted, @errors);
  for my $id (@ids) {
    my $r = $self->queue_delete($id);
    if ($r->{ok}) { push @deleted, $id }
    else          { push @errors, { id => $id, stderr => $r->{stderr} } }
  }
  return {
    ok      => (scalar @errors == 0),
    matched => scalar @matched,
    deleted => scalar @deleted,
    ids     => \@deleted,
    errors  => \@errors,
  };
}

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

If the C<env> block is omitted, the model falls back to the main samizdat
DSN (passed in via C<fallback_dsn>) and uses the C<postfix> schema there.

=cut
