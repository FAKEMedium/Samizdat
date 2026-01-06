package Samizdat::Model::Domain;

use Mojo::Base -base, -signatures;
use Mojo::Util qw(trim);
use Data::Dumper;

has 'config';
has 'pg';
has 'mysql';
has 'epp';
has 'realtimeregister';

sub database ($self) {
  return ('mysql' eq ($self->config->{dbtype} // 'postgresql')) ? $self->mysql->db : $self->pg->db;
}

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

sub neighbours ($self, $domainid) {
  my $db = $self->database;
  my $result = {
    minid  => $db->query('SELECT MIN(domainid) AS minid FROM domain')->hash->{minid},
    maxid  => $db->query('SELECT MAX(domainid) AS maxid FROM domain')->hash->{maxid},
    previd => $db->query('SELECT MAX(domainid) AS previd FROM domain WHERE domainid < ?', $domainid)->hash->{previd},
    nextid => $db->query('SELECT MIN(domainid) AS nextid FROM domain WHERE domainid > ?', $domainid)->hash->{nextid},
  };
  $result->{previd} //= $result->{minid};
  $result->{nextid} //= $result->{maxid};
  return $result;
}

# Contact management - delegates to EPP or RealtimeRegister

sub contacts ($self, $params = {}) {
  my @contacts;

  # Get from RealtimeRegister if available
  if ($self->realtimeregister) {
    my $rr_contacts = $self->realtimeregister->getContacts($params) // [];
    for my $c (@$rr_contacts) {
      push @contacts, $self->_normalize_rr_contact($c);
    }
  }

  # Get from EPP if available (EPP doesn't have list, skip)
  # EPP contacts are typically retrieved by handle only

  return \@contacts;
}

sub contact_get ($self, $handle) {
  return undef unless $handle;

  # Try RealtimeRegister first
  if ($self->realtimeregister) {
    my $contact = $self->realtimeregister->getContact($handle);
    return $self->_normalize_rr_contact($contact) if $contact;
  }

  # Try EPP
  if ($self->epp) {
    my $info = {};
    if ($self->epp->contact_info($handle, $info)) {
      return $self->_normalize_epp_contact($info);
    }
  }

  return undef;
}

sub contact_create ($self, $data) {
  my $registries = $data->{registries} // [];

  # Registries can be array of strings (legacy) or array of {registry, handle} objects
  # Normalize to array of {registry, handle}
  my @reg_list;
  for my $reg (@$registries) {
    if (ref $reg eq 'HASH') {
      push @reg_list, $reg;
    } else {
      # Legacy format: just registry name, handle from $data
      push @reg_list, { registry => $reg, handle => $data->{handle} };
    }
  }

  # If no registries specified, use default behavior (prefer RTR)
  if (!@reg_list) {
    my $handle = $data->{handle} or return { success => 0, error => 'Handle required' };
    @reg_list = $self->realtimeregister ? [{ registry => 'rr', handle => $handle }]
              : $self->epp ? [{ registry => 'se', handle => $handle }]
              : ();
  }

  my @results;
  my @errors;

  for my $reg_info (@reg_list) {
    my $registry = $reg_info->{registry};
    my $handle = $reg_info->{handle} or do {
      push @errors, uc($registry) . ": Handle required";
      next;
    };

    # Create contact data with this handle
    my $contact_data = { %$data, handle => $handle };

    if ($registry eq 'rr' && $self->realtimeregister) {
      my $rr_data = $self->_to_rr_contact($contact_data);
      my $result = $self->realtimeregister->createContact($rr_data);
      if ($result && !$result->{error}) {
        push @results, { registry => 'rr', success => 1, contact => $result, handle => $handle };
      } else {
        my $err_msg = $result->{error} // 'Failed to create contact';
        push @errors, "RR: $err_msg";
      }
    }
    elsif (($registry eq 'se' || $registry eq 'nu') && $self->epp) {
      my $epp_data = $self->_to_epp_contact($contact_data);
      my $info = {};
      my $success = $self->epp->contact_create($handle, $epp_data, $info);
      if ($success) {
        push @results, { registry => $registry, success => 1, contact => $info, handle => $handle };
      } else {
        push @errors, uc($registry) . ": " . ($info->{error} // 'Failed to create contact');
      }
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

  # Prefer RealtimeRegister if available
  if ($self->realtimeregister) {
    my $rr_data = $self->_to_rr_contact($data);
    my $result = $self->realtimeregister->updateContact($handle, $rr_data);
    return { success => $result ? 1 : 0, contact => $result };
  }

  # Fall back to EPP
  if ($self->epp) {
    my $epp_data = $self->_to_epp_contact($data);
    my $info = {};
    my $success = $self->epp->contact_update($handle, $epp_data, $info);
    return { success => $success ? 1 : 0, contact => $info };
  }

  return { success => 0, error => 'No contact backend available' };
}

sub contact_delete ($self, $handle) {
  return { success => 0, error => 'Handle required' } unless $handle;

  # Prefer RealtimeRegister if available
  if ($self->realtimeregister) {
    my $result = $self->realtimeregister->deleteContact($handle);
    return { success => 1 };
  }

  # Fall back to EPP
  if ($self->epp) {
    my $info = {};
    my $success = $self->epp->contact_delete($handle, $info);
    return { success => $success ? 1 : 0 };
  }

  return { success => 0, error => 'No contact backend available' };
}

# Domain transfer - initiates transfer from another registrar
sub transfer ($self, $data) {
  my $domainname = $data->{domainname} or return { success => 0, error => 'Domain name required' };
  my $authcode = $data->{authcode} // '';

  # Prefer RealtimeRegister if available
  if ($self->realtimeregister) {
    my $transfer_data = {
      domainName => $domainname,
      authcode   => $authcode,
      registrant => $data->{registrant},
      period     => $data->{period} // 1,
    };
    # Add contacts if provided
    $transfer_data->{admin} = $data->{admin} if $data->{admin};
    $transfer_data->{tech} = $data->{tech} if $data->{tech};

    my $result = $self->realtimeregister->transferDomain($transfer_data);
    return { success => $result ? 1 : 0, domain => $result };
  }

  # Fall back to EPP
  if ($self->epp) {
    my $info = {};
    my $success = $self->epp->domain_transfer($domainname, $authcode, $info);
    return { success => $success ? 1 : 0, domain => $info };
  }

  return { success => 0, error => 'No domain backend available' };
}

# Normalize RealtimeRegister contact to common format
sub _normalize_rr_contact ($self, $c) {
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

# Normalize EPP contact to common format
sub _normalize_epp_contact ($self, $c) {
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

# Convert common format to RealtimeRegister format
sub _to_rr_contact ($self, $data) {
  return {
    handle       => $data->{handle},
    name         => $data->{name},
    organization => $data->{organization},
    email        => $data->{email},
    voice        => $data->{phone},  # RTR uses 'voice', E164a format: +31.384530759
    fax          => $data->{fax},
    addressLine  => $data->{street},
    city         => $data->{city},
    postalCode   => $data->{postalCode},
    country      => $data->{country},
    # RTR doesn't use orgno/vatno directly - these are SE/NU specific
  };
}

# Convert common format to EPP format
sub _to_epp_contact ($self, $data) {
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