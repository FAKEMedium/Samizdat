package Samizdat::Model::Domain;

use Mojo::Base -base, -signatures;
use Mojo::Util qw(trim);

has 'config';
has 'pg';
has 'mysql';
has 'registries';   # hashref of id => Registry adapter instance

# Legacy accessors for backward compatibility during transition
has 'epp';
has 'realtimeregister';

sub database ($self) {
  return ('mysql' eq ($self->config->{dbtype} // 'postgresql')) ? $self->mysql->db : $self->pg->db;
}

# Get a specific registry adapter by id
sub registry ($self, $id) {
  return $self->registries->{$id} if $self->registries && $self->registries->{$id};
  return undef;
}

# Find the right registry for a domain name (by TLD matching from config)
sub registry_for ($self, $domainname) {
  return undef unless $self->registries;
  my $tld = (split /\./, $domainname)[-1];
  for my $id (keys %{$self->registries}) {
    my $reg = $self->registries->{$id};
    my $tlds = $reg->config->{tlds} // [];
    return $reg if grep { lc($_) eq lc($tld) } @$tlds;
  }
  # Fall back to registry with broadest TLD coverage (fewest explicit TLDs = most general)
  my ($fallback) = sort { scalar(@{$a->config->{tlds} // []}) <=> scalar(@{$b->config->{tlds} // []}) }
                   values %{$self->registries};
  return $fallback;
}

# List all configured registry ids
sub registry_ids ($self) {
  return [] unless $self->registries;
  return [sort keys %{$self->registries}];
}

# Database domain operations

sub get ($self, $params = {}) {
  my $db = $self->database;
  my $where = $params->{where} // {};
  my $limit = $params->{limit} // {};
  my $dbtype = $self->config->{dbtype} // 'postgresql';

  my $due;
  if ($dbtype eq 'mysql') {
    $due = sprintf("IF((DATEDIFF(NOW(), curexpiry) > %d) AND (dontrenew = 0), 1, 0) AS due", 60);
  } else {
    $due = sprintf("CASE WHEN ((NOW()::date - curexpiry) > %d) AND (dontrenew = false) THEN 1 ELSE 0 END AS due", 60);
  }

  my @args = ('domain', "*, $due", $where);
  push @args, $limit if keys %$limit;
  return $db->select(@args)->hashes;
}

sub neighbours ($self, $domainid, $customerids = undef) {
  my $db = $self->database;
  my $filter = '';
  my @bind;
  if ($customerids && @$customerids) {
    my $placeholders = join ',', map { '?' } @$customerids;
    $filter = " AND customerid IN ($placeholders)";
    @bind = @$customerids;
  }
  my $result = {
    minid  => $db->query("SELECT MIN(domainid) AS minid FROM domain WHERE 1=1$filter", @bind)->hash->{minid},
    maxid  => $db->query("SELECT MAX(domainid) AS maxid FROM domain WHERE 1=1$filter", @bind)->hash->{maxid},
    previd => $db->query("SELECT MAX(domainid) AS previd FROM domain WHERE domainid < ?$filter", $domainid, @bind)->hash->{previd},
    nextid => $db->query("SELECT MIN(domainid) AS nextid FROM domain WHERE domainid > ?$filter", $domainid, @bind)->hash->{nextid},
  };
  $result->{previd} //= $result->{maxid};
  $result->{nextid} //= $result->{minid};
  return $result;
}

# Contact management - dispatches through registry adapters

sub contacts ($self, $params = {}) {
  my @contacts;
  for my $reg (values %{$self->registries // {}}) {
    push @contacts, @{$reg->contact_list($params) // []};
  }
  return \@contacts;
}

sub contact_get ($self, $handle) {
  return undef unless $handle;
  for my $reg (values %{$self->registries // {}}) {
    my $contact = $reg->contact_get($handle);
    return $contact if $contact;
  }
  return undef;
}

sub contact_create ($self, $data) {
  my $registries_param = $data->{registries} // [];

  # Normalize to array of {registry, handle}
  my @reg_list;
  for my $reg (@$registries_param) {
    if (ref $reg eq 'HASH') {
      push @reg_list, $reg;
    } else {
      push @reg_list, { registry => $reg, handle => $data->{handle} };
    }
  }

  # Default: use first available registry
  if (!@reg_list) {
    my $handle = $data->{handle} or return { success => 0, error => 'Handle required' };
    my @ids = @{$self->registry_ids};
    @reg_list = map { { registry => $_, handle => $handle } } @ids;
  }

  my @results;
  my @errors;

  for my $reg_info (@reg_list) {
    my $registry_id = $reg_info->{registry};
    my $handle = $reg_info->{handle} or do {
      push @errors, uc($registry_id) . ": Handle required";
      next;
    };

    my $reg = $self->registry($registry_id);
    unless ($reg) {
      push @errors, uc($registry_id) . ": Registry not configured";
      next;
    }

    my $result = $reg->contact_create($handle, { %$data, handle => $handle });
    if ($result->{success}) {
      push @results, { registry => $registry_id, %$result };
    } else {
      push @errors, uc($registry_id) . ": " . ($result->{error} // 'Failed to create contact');
    }
  }

  my $success = @results > 0;
  return {
    success => $success ? 1 : 0,
    results => \@results,
    errors  => \@errors,
    toast   => $success
      ? sprintf('Contact created in %d registr%s', scalar @results, @results == 1 ? 'y' : 'ies')
      : join(', ', @errors),
  };
}

sub contact_update ($self, $handle, $data) {
  return { success => 0, error => 'Handle required' } unless $handle;

  for my $reg (values %{$self->registries // {}}) {
    next unless $reg->capabilities->{contacts};
    my $result = $reg->contact_update($handle, $data);
    return $result if $result->{success};
  }

  return { success => 0, error => 'No contact backend available' };
}

sub contact_delete ($self, $handle) {
  return { success => 0, error => 'Handle required' } unless $handle;

  for my $reg (values %{$self->registries // {}}) {
    next unless $reg->capabilities->{contacts};
    my $result = $reg->contact_delete($handle);
    return $result if $result->{success};
  }

  return { success => 0, error => 'No contact backend available' };
}

# Domain operations - dispatched through registry adapters

sub transfer ($self, $data) {
  my $domainname = $data->{domainname} or return { success => 0, error => 'Domain name required' };
  my $authcode = $data->{authcode} // '';

  my $reg = $self->registry_for($domainname);
  return { success => 0, error => 'No registry available for this domain' } unless $reg;

  return $reg->domain_transfer($domainname, $authcode, $data);
}

sub domain_info ($self, $domainname) {
  my $reg = $self->registry_for($domainname);
  return undef unless $reg;
  return $reg->domain_info($domainname);
}

sub domain_renew ($self, $domainname, $curexpiry, $period) {
  my $reg = $self->registry_for($domainname);
  return { success => 0, error => 'No registry available' } unless $reg;
  return $reg->domain_renew($domainname, $curexpiry, $period);
}

sub update_expiry ($self, $domainname, $expiry_date) {
  my $db = $self->database;
  $db->update('domain', { curexpiry => $expiry_date }, { domainname => $domainname });
}

sub generate_authcode ($self, $domainname) {
  my $reg = $self->registry_for($domainname);
  return { success => 0, error => 'No registry available' } unless $reg;
  return $reg->generate_authcode($domainname);
}

sub set_nameservers ($self, $domainname, $nameservers) {
  my $reg = $self->registry_for($domainname);
  return { success => 0, error => 'No registry available' } unless $reg;
  return $reg->set_nameservers($domainname, $nameservers);
}

1;
