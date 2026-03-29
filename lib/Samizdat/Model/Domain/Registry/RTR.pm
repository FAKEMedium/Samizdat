package Samizdat::Model::Domain::Registry::RTR;

use Mojo::Base -base, -signatures;

has 'client';   # Samizdat::Model::RealtimeRegister instance
has 'config';   # registry config section
has 'id';       # registry id (e.g. 'rtr')

# What this registry supports
sub capabilities ($self) {
  return {
    domain_info     => 1,
    domain_create   => 1,
    domain_renew    => 1,
    domain_transfer => 1,
    authcode        => 0,
    nameservers     => 1,
    dnssec          => 0,
    contacts        => 1,
    hosts           => 0,
    poll             => 0,
    pricelist       => 1,
    transactions    => 1,
  };
}

# Domain operations

sub domain_info ($self, $domainname) {
  my $result = $self->client->getDomain($domainname);
  return $result->{error} ? undef : $result;
}

sub domain_create ($self, $data) {
  my $result = $self->client->createDomain($data);
  return { success => $result && !$result->{error} ? 1 : 0, info => $result };
}

sub domain_renew ($self, $domainname, $curexpiry, $period) {
  my $result = $self->client->renewDomain($domainname, $period // 1);
  return { success => $result && !$result->{error} ? 1 : 0, info => $result };
}

sub domain_transfer ($self, $domainname, $authcode, $data) {
  my $transfer_data = {
    domainName => $domainname,
    authcode   => $authcode,
    registrant => $data->{registrant},
    period     => $data->{period} // 1,
  };
  $transfer_data->{admin} = $data->{admin} if $data->{admin};
  $transfer_data->{tech}  = $data->{tech}  if $data->{tech};
  my $result = $self->client->transferDomain($transfer_data);
  return { success => $result && !$result->{error} ? 1 : 0, info => $result };
}

sub generate_authcode ($self, $domainname) {
  return { success => 0, error => 'Not supported by this registry' };
}

sub set_nameservers ($self, $domainname, $nameservers) {
  my $result = $self->client->updateDomain($domainname, { ns => $nameservers });
  return { success => $result && !$result->{error} ? 1 : 0, info => $result };
}

# Domain listing (RTR-specific, useful for admin)
sub domain_list ($self, $params) {
  return $self->client->getDomains($params);
}

# Contact operations

sub contact_list ($self, $params) {
  my $result = $self->client->getContacts($params);
  my @normalized;
  for my $c (@{$result->{entities} || $result || []}) {
    push @normalized, _normalize_contact($c);
  }
  return \@normalized;
}

sub contact_get ($self, $handle) {
  my $result = $self->client->getContact($handle);
  return undef if $result->{error};
  return _normalize_contact($result);
}

sub contact_create ($self, $handle, $data) {
  my $rr_data = _to_rtr_contact($data, $handle);
  my $result = $self->client->createContact($rr_data);
  if ($result && !$result->{error}) {
    return { success => 1, info => $result, handle => $handle };
  }
  return { success => 0, error => $result->{error} // 'Failed to create contact' };
}

sub contact_update ($self, $handle, $data) {
  my $rr_data = _to_rtr_contact($data, $handle);
  my $result = $self->client->updateContact($handle, $rr_data);
  return { success => $result && !$result->{error} ? 1 : 0, info => $result };
}

sub contact_delete ($self, $handle) {
  my $result = $self->client->deleteContact($handle);
  return { success => 1 };
}

# Financial (RTR-specific)

sub pricelist ($self, $params) {
  return $self->client->getPricelist($params);
}

sub transactions ($self, $params) {
  return $self->client->getTransactions($params);
}

sub transaction ($self, $id) {
  return $self->client->getTransaction($id);
}

sub sum_transactions ($self, $entities, $currency) {
  return $self->client->sumTransactions($entities, $currency);
}

sub currencies ($self) {
  return $self->client->currencies;
}

sub default_currency ($self) {
  return $self->client->default_currency;
}

# Normalization

sub _normalize_contact ($c) {
  return undef unless $c;
  return {
    handle       => $c->{handle},
    name         => $c->{name},
    organization => $c->{organization} // '',
    email        => $c->{email},
    phone        => $c->{phone} // $c->{voice} // '',
    fax          => $c->{fax} // '',
    street       => $c->{addressLine} // [],
    city         => $c->{city} // '',
    postalCode   => $c->{postalCode} // '',
    country      => $c->{country} // '',
    orgno        => '',
    vatno        => '',
    source       => 'realtimeregister',
  };
}

sub _to_rtr_contact ($data, $handle = undef) {
  return {
    ($handle ? (handle => $handle) : ()),
    name         => $data->{name},
    organization => $data->{organization},
    email        => $data->{email},
    voice        => $data->{phone},
    fax          => $data->{fax},
    addressLine  => $data->{street},
    city         => $data->{city},
    postalCode   => $data->{postalCode},
    country      => $data->{country},
  };
}

1;
