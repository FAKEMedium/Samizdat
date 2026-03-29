package Samizdat::Command::syncexpiries;

use Mojo::Base 'Mojolicious::Command', -signatures;
use Mojo::Util qw(getopt);

binmode(STDOUT, ':encoding(UTF-8)');
binmode(STDERR, ':encoding(UTF-8)');

has description => 'Sync domain expiry dates from registries';
has usage => sub ($self) { $self->extract_usage };

sub run ($self, @args) {
  getopt \@args,
    'dry-run'    => \my $dry_run,
    'registry=s' => \my $registry_id,
    'verbose'    => \my $verbose,
    'h|help'     => \my $help;

  if ($help) {
    print $self->usage;
    return;
  }

  my $domain_model = $self->app->domain;
  my $registries = $domain_model->registries // {};

  unless (keys %$registries) {
    say STDERR "No registries configured";
    exit 1;
  }

  # Filter to specific registry if requested
  my @reg_ids = $registry_id ? ($registry_id) : sort keys %$registries;

  my $db = $domain_model->database;
  my ($updated, $skipped, $errors, $unchanged) = (0, 0, 0, 0);

  for my $id (@reg_ids) {
    my $reg = $registries->{$id};
    unless ($reg) {
      say STDERR "Registry '$id' not configured";
      next;
    }

    say "=== Registry: $id ===";

    if ($id eq 'rtr' || (ref($reg) =~ /RTR/)) {
      sync_rtr($self, $reg, $db, $dry_run, $verbose, \$updated, \$skipped, \$errors, \$unchanged);
    } elsif (ref($reg) =~ /EPP/) {
      sync_epp($self, $reg, $domain_model, $db, $dry_run, $verbose, \$updated, \$skipped, \$errors, \$unchanged);
    } else {
      say "  Skipping unknown registry type: " . ref($reg);
    }
  }

  say "\n--- Summary ---";
  say "Updated:   $updated";
  say "Unchanged: $unchanged";
  say "Skipped:   $skipped";
  say "Errors:    $errors";
  say "(dry run - no changes made)" if $dry_run;
}

sub sync_rtr ($self, $reg, $db, $dry_run, $verbose, $updated, $skipped, $errors, $unchanged) {
  # Fetch all domains from RTR (paginated)
  my $offset = 0;
  my $limit = 100;
  my $total = 0;

  while (1) {
    my $result = $reg->client->getDomains({ limit => $limit, offset => $offset });
    my $entities = $result->{entities} || [];
    $total += scalar @$entities;
    last unless @$entities;

    for my $rtr_domain (@$entities) {
      my $name = $rtr_domain->{domainName} // next;
      my $rtr_expiry = $rtr_domain->{expiryDate} // next;
      $rtr_expiry =~ s/T.*//;  # Strip time part, keep YYYY-MM-DD

      # Look up in local DB
      my $local = $db->query('SELECT domainid, domainname, curexpiry, registryid FROM domain WHERE domainname = ?', lc $name)->hash;

      unless ($local) {
        say "  SKIP $name (not in local database)" if $verbose;
        $$skipped++;
        next;
      }

      my $local_expiry = $local->{curexpiry} // '';
      $local_expiry =~ s/ .*//;  # Normalize

      if ($local_expiry eq $rtr_expiry) {
        say "  OK   $name ($rtr_expiry)" if $verbose;
        $$unchanged++;
        next;
      }

      say "  UPD  $name: $local_expiry -> $rtr_expiry";
      unless ($dry_run) {
        eval {
          $db->query('UPDATE domain SET curexpiry = ?, updated = NOW(), updater = ? WHERE domainid = ?',
            $rtr_expiry, 'syncexpiries', $local->{domainid});
        };
        if ($@) {
          say STDERR "  ERROR updating $name: $@";
          $$errors++;
          next;
        }
      }
      $$updated++;
    }

    last if scalar @$entities < $limit;
    $offset += $limit;
  }
  say "  Fetched $total domains from RTR";
}

sub sync_epp ($self, $reg, $domain_model, $db, $dry_run, $verbose, $updated, $skipped, $errors, $unchanged) {
  # EPP doesn't have a list endpoint, so iterate local domains matching TLDs
  my $tlds = $reg->config->{tlds} || [];
  return unless @$tlds;

  my $tld_pattern = join '|', map { quotemeta $_ } @$tlds;
  my $domains = $db->query(
    "SELECT domainid, domainname, curexpiry, registryid FROM domain WHERE domainname REGEXP ? AND active = 1 AND registryid != 1",
    "\\.($tld_pattern)\$"
  )->hashes;

  # Group by registryid to avoid jumping between connections
  my %by_registry;
  for my $d (@$domains) {
    push @{$by_registry{$d->{registryid}} //= []}, $d;
  }

  say "  Checking " . scalar(@$domains) . " local .$tld_pattern domains against EPP (" . scalar(keys %by_registry) . " registry groups)";

  for my $rid (sort { $a <=> $b } keys %by_registry) {
    my $group = $by_registry{$rid};
    say "  --- registryid $rid (" . scalar(@$group) . " domains) ---" if $verbose;

    for my $local (@$group) {
      my $name = $local->{domainname};
      my $info;
      eval { $info = $reg->domain_info($name) };
      if ($@ || !$info) {
        my $err = $@ || 'no response';
        $err =~ s/\n.*//s;
        say "  SKIP $name (EPP error: $err)" if $verbose;
        $$skipped++;
        next;
      }

      my $epp_expiry = $info->{expiry} // next;
      $epp_expiry =~ s/T.*//;

      my $local_expiry = $local->{curexpiry} // '';
      $local_expiry =~ s/ .*//;

      if ($local_expiry eq $epp_expiry) {
        say "  OK   $name ($epp_expiry)" if $verbose;
        $$unchanged++;
        next;
      }

      say "  UPD  $name: $local_expiry -> $epp_expiry";
      unless ($dry_run) {
        eval {
          $db->query('UPDATE domain SET curexpiry = ?, updated = NOW(), updater = ? WHERE domainid = ?',
            $epp_expiry, 'syncexpiries', $local->{domainid});
        };
        if ($@) {
          say STDERR "  ERROR updating $name: $@";
          $$errors++;
          next;
        }
      }
      $$updated++;
    }
  }
}

1;

=head1 SYNOPSIS

  Usage: samizdat syncexpiries [OPTIONS]

  Options:
    --dry-run         Show what would be updated without making changes
    --registry ID     Only sync from a specific registry (e.g. 'rtr' or 'se')
    --verbose         Show unchanged domains too
    -h, --help        Show this help

  Examples:
    samizdat syncexpiries --dry-run
    samizdat syncexpiries --registry rtr
    samizdat syncexpiries --registry se --verbose
    samizdat syncexpiries

=cut
