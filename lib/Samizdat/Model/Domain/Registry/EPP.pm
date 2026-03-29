package Samizdat::Model::Domain::Registry::EPP;

use Mojo::Base -base, -signatures;

has 'client';   # Samizdat::Model::EPP instance
has 'config';   # registry config section
has 'id';       # registry id (e.g. 'se')

# Ensure EPP is connected and logged in for the right TLD
has '_connected_tld' => '';

sub _ensure_connected ($self, $domainname = undef) {
  my $tld = lc($domainname ? (split /\./, $domainname)[-1] : $self->id);
  my $log = $self->client->app ? $self->client->app->log : undef;

  # Reconnect if TLD changed (different tunnel/credentials)
  if ($self->client->connected && $self->_connected_tld ne $tld) {
    $log->debug("EPP switching TLD from " . $self->_connected_tld . " to $tld, reconnecting") if $log;
    $self->client->logout;
    $self->client->disconnect;
  }

  $self->client->tld($tld);
  unless ($self->client->connected) {
    my $tld_config = $self->client->_get_tld_config();
    my $host = $tld_config->{host} || $tld_config->{remote_host} || 'unknown';
    my $port = $tld_config->{ports} ? $tld_config->{ports}[0] : 700;
    $log->debug("EPP connecting to $host:$port for TLD $tld") if $log;
    $self->client->connect or do {
      $log->warn("EPP connect failed to $host:$port for TLD $tld") if $log;
      return 0;
    };
    $log->debug("EPP login for TLD $tld") if $log;
    $self->client->login or do {
      $log->warn("EPP login failed for TLD $tld") if $log;
      return 0;
    };
    $self->_connected_tld($tld);
  }
  return 1;
}

# What this registry supports
sub capabilities ($self) {
  return {
    domain_info     => 1,
    domain_create   => 1,
    domain_renew    => 1,
    domain_transfer => 1,
    authcode        => 1,
    nameservers     => 1,
    dnssec          => 1,
    contacts        => 1,
    hosts           => 1,
    poll             => 1,
    pricelist       => 0,
    transactions    => 0,
  };
}

# Domain operations

sub domain_info ($self, $domainname) {
  return undef unless $self->_ensure_connected($domainname);
  my $info = {};
  my $ok = $self->client->domain_info($domainname, $info);
  return undef unless $ok;
  return $info;
}

sub domain_create ($self, $data) {
  return { success => 0, error => 'EPP connection failed' } unless $self->_ensure_connected($data->{domainname});
  my $info = {};
  my $ok = $self->client->domain_create(
    $data->{domainname}, ($data->{period} // 12), $info
  );
  return { success => $ok ? 1 : 0, info => $info };
}

sub domain_renew ($self, $domainname, $curexpiry, $period) {
  return { success => 0, error => 'EPP connection failed' } unless $self->_ensure_connected($domainname);
  my $info = {};
  my $ok = $self->client->domain_renew($domainname, $curexpiry, $period // 12, $info);
  return { success => $ok ? 1 : 0, info => $info };
}

sub domain_transfer ($self, $domainname, $authcode, $data) {
  return { success => 0, error => 'EPP connection failed' } unless $self->_ensure_connected($domainname);
  my $info = {};
  my $ok = $self->client->domain_transfer($domainname, $authcode, $info);
  return { success => $ok ? 1 : 0, info => $info };
}

sub generate_authcode ($self, $domainname) {
  return { success => 0, error => 'EPP connection failed' } unless $self->_ensure_connected($domainname);
  my $info = {};
  my $ok = $self->client->generate_authcode($domainname, $info);
  return { success => $ok ? 1 : 0, info => $info };
}

sub set_nameservers ($self, $domainname, $nameservers) {
  return { success => 0, error => 'EPP connection failed' } unless $self->_ensure_connected($domainname);
  my $info = {};
  my $ok = $self->client->set_nameservers($domainname, $nameservers, $info);
  return { success => $ok ? 1 : 0, info => $info };
}

# Contact operations

sub contact_list ($self, $params) {
  # EPP doesn't support listing contacts
  return [];
}

sub contact_get ($self, $handle) {
  my $info = {};
  my $ok = $self->client->contact_info($handle, $info);
  return undef unless $ok;
  return _normalize_contact($info);
}

sub contact_create ($self, $handle, $data) {
  my $epp_data = _to_epp_contact($data);
  my $info = {};
  my $ok = $self->client->contact_create($handle, $epp_data, $info);
  return { success => $ok ? 1 : 0, info => $info, handle => $handle };
}

sub contact_update ($self, $handle, $data) {
  my $epp_data = _to_epp_contact($data);
  my $info = {};
  my $ok = $self->client->contact_update($handle, $epp_data, $info);
  return { success => $ok ? 1 : 0, info => $info };
}

sub contact_delete ($self, $handle) {
  my $info = {};
  my $ok = $self->client->contact_delete($handle, $info);
  return { success => $ok ? 1 : 0 };
}

# DNSSEC

sub add_ds_record ($self, $domainname, $keytag, $alg, $digesttype, $digest) {
  my $info = {};
  my $ok = $self->client->add_ds_record($domainname, $keytag, $alg, $digesttype, $digest, $info);
  return { success => $ok ? 1 : 0, info => $info };
}

sub remove_ds_record ($self, $domainname, $keytag, $alg, $digesttype, $digest) {
  my $info = {};
  my $ok = $self->client->remove_ds_record($domainname, $keytag, $alg, $digesttype, $digest, $info);
  return { success => $ok ? 1 : 0, info => $info };
}

# Host management

sub host_create ($self, $host, $glue) {
  my $info = {};
  my $ok = $self->client->host_create($host, $glue, $info);
  return { success => $ok ? 1 : 0, info => $info };
}

sub host_delete ($self, $host) {
  my $info = {};
  my $ok = $self->client->host_delete($host, $info);
  return { success => $ok ? 1 : 0 };
}

sub host_info ($self, $host) {
  my $info = {};
  my $ok = $self->client->host_info($host, $info);
  return $ok ? $info : undef;
}

# Poll queue

sub poll ($self) {
  my $info = {};
  my $ok = $self->client->poll_message($info);
  return $ok ? $info : undef;
}

sub poll_ack ($self, $message_id) {
  my $info = {};
  my $ok = $self->client->ack_message($message_id, $info);
  return { success => $ok ? 1 : 0 };
}

# Normalization

sub _normalize_contact ($c) {
  return undef unless $c;
  my @street = ref $c->{street} eq 'ARRAY' ? @{$c->{street}} : split(/[\n\r]+/, $c->{street} // '');
  return {
    handle       => $c->{id} // $c->{registrant},
    name         => $c->{name} // '',
    organization => $c->{org} // '',
    email        => $c->{email} // '',
    phone        => $c->{voice} // '',
    fax          => $c->{fax} // '',
    street       => \@street,
    city         => $c->{city} // '',
    postalCode   => $c->{pc} // '',
    country      => $c->{cc} // '',
    orgno        => $c->{orgno} // '',
    vatno        => $c->{vatno} // '',
    source       => 'epp',
  };
}

sub _to_epp_contact ($data) {
  my $street = ref $data->{street} eq 'ARRAY' ? join("\n", @{$data->{street}}) : $data->{street};
  return {
    name   => $data->{name},
    org    => $data->{organization},
    email  => $data->{email},
    voice  => $data->{phone},
    fax    => $data->{fax},
    street => $street,
    city   => $data->{city},
    pc     => $data->{postalCode},
    cc     => $data->{country},
    orgno  => $data->{orgno},
    vatno  => $data->{vatno},
  };
}

1;
