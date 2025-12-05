# lib/Samizdat/Model/Zone.pm
package Samizdat::Model::Zone;

use Mojo::Base -base, -signatures;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::UserAgent;
use Net::IDN::Encode qw(:all);
use Data::Dumper;

has 'config';
has 'cache';
has 'db';  # Mojo::Pg database connection for PowerDNS
has ua => sub { Mojo::UserAgent->new };

# Get environment configuration (production or test)
sub get_env_config ($self) {
  my $config = $self->config;
  my $env = $config->{default_env} || 'production';

  return $config->{env}->{$env};
}

# Helper to set API headers.
sub _headers ($self) {
  my $env_config = $self->get_env_config();
  return {
    'X-API-Key'    => $env_config->{api}->{key},
    'Content-Type' => 'application/json',
  };
}

# Helper to get API URL
sub _api_url ($self) {
  my $env_config = $self->get_env_config();
  return $env_config->{api}->{url};
}

### Zone Methods

# List zones. Accepts optional query parameters.
# Uses cache to avoid frequent API calls.
sub list_zones ($self, $params = {}) {
  my $cache_key = 'zone:list';

  # Check if we should use cache
  if (!exists($params->{nocache}) || !$params->{nocache}) {
    my $cached = $self->cache->get($cache_key);
    return $cached if $cached;
  }

  # Fetch from API
  $params->{dnssec} //= 'false';
  delete $params->{nocache};
  my $url = $self->_api_url() . '/zones';
  my $tx  = $self->ua->get($url, $self->_headers, form => $params);

  if (my $res = $tx->result) {
    if ($res->is_success) {
      my $zones = $res->json;
      $self->cache->set($cache_key => $zones);
      return $zones;
    } else {
      say "Error fetching zones: " . $res->message;
    }
  }
  return [];
}

# Get details for a specific zone.
# The "rrsets" parameter defaults to "true".
sub get_zone ($self, $zone_id, $params = {}) {
  $params->{rrsets} //= 'false';
  my $url = $self->_api_url() . '/zones/' . $zone_id;
  my $tx  = $self->ua->get($url, $self->_headers, form => $params);
  if (my $res = $tx->result) {
    return $res->is_success ? $res->json : undef;
  }
  return undef;
}

# Normalize zone name - ensure trailing dot for PowerDNS
sub _normalize_zone_name ($self, $name) {
  return $name unless $name;
  return $name =~ /\.$/ ? $name : "$name.";
}

# Create a new zone. Expects a hashref with keys like name and kind.
sub create_zone ($self, $zone_data) {
  my $url = $self->_api_url() . '/zones';
  my $payload = {
    name       => $self->_normalize_zone_name($zone_data->{name}),
    kind       => $zone_data->{kind} // 'Native',
    account    => $zone_data->{account} // '',
    'soa-edit' => 'DEFAULT',
  };
  my $tx = $self->ua->post($url, $self->_headers, json => $payload);
  my $res = $tx->result;

  if ($res && $res->is_success) {
    $self->clear_cache;
    return { success => 1 };
  }
  return { success => 0, error => $res ? $res->message : "No response" };
}

# Import a zone from BIND/AXFR format zone file content.
sub import_zone ($self, $zone_data) {
  my $url = $self->_api_url() . '/zones';
  my $payload = {
    name       => $self->_normalize_zone_name($zone_data->{name}),
    kind       => $zone_data->{kind} // 'Native',
    zone       => $zone_data->{zone},  # BIND format zone content
    account    => $zone_data->{account} // '',
    'soa-edit' => 'DEFAULT',
  };
  my $tx = $self->ua->post($url, $self->_headers, json => $payload);
  my $res = $tx->result;

  if ($res && $res->is_success) {
    $self->clear_cache;
    return { success => 1, zone => $res->json };
  }

  my $error = $res ? ($res->json->{error} // $res->message) : "No response";
  return { success => 0, error => $error };
}

# Update an existing zone. Only kind, masters, catalog, account, soa_edit,
# soa_edit_api, api_rectify, dnssec, nsec3param can be modified via PUT.
sub update_zone ($self, $zone_id, $zone_data) {
  my $url = $self->_api_url() . '/zones/' . $zone_id;

  # Only send modifiable fields
  my $payload = {
    kind    => $zone_data->{kind},
    account => $zone_data->{account} // '',
  };

  my $tx = $self->ua->put($url, $self->_headers, json => $payload);
  my $res = $tx->result;

  # PowerDNS returns 204 No Content on success
  if ($res && $res->code == 204) {
    $self->clear_cache;
    return { success => 1 };
  }

  my $error = $res ? ($res->json->{error} // $res->message) : "No response";
  return { success => 0, error => $error };
}

# Export a zone in AXFR format (standard zone file format).
sub export_zone ($self, $zone_id) {
  my $url = $self->_api_url() . '/zones/' . $zone_id . '/export';
  my $tx = $self->ua->get($url, $self->_headers);
  my $res = $tx->result;

  if ($res && $res->is_success) {
    return { success => 1, content => $res->body };
  }

  my $error = $res ? ($res->json->{error} // $res->message) : "No response";
  return { success => 0, error => $error };
}

# Delete a zone.
sub delete_zone ($self, $zone_id) {
  my $url = $self->_api_url() . '/zones/' . $zone_id;
  my $tx  = $self->ua->delete($url, $self->_headers);
  my $res = $tx->result;

  if ($res && $res->is_success) {
    $self->clear_cache;
    return { success => 1 };
  }
  return { success => 0, error => $res ? $res->message : "No response" };
}

### Record Methods (Records are managed as part of the zone object)

# List records for a zone. Optionally filter the records (e.g. by type or name).
sub list_rrsets ($self, $zone_id, $filter = {}) {
  my $zone = $self->get_zone($zone_id, { rrsets => 'true' });
  my $records = [];
  my $rrsets = $zone->{rrsets} // [];
  if (%$filter) {
    $rrsets = [ grep {
      my $ok = 1;
      $ok &&= ($_->{type} eq $filter->{type}) if exists $filter->{type};
      $ok &&= ($_->{name} eq $filter->{name}) if exists $filter->{name};
      $ok;
    } @$rrsets ];
  }
  return $rrsets;
}

# Get a specific rrset from a zone by name and optionally type.
# PowerDNS rrsets are identified by name+type, not by a single ID.
# Returns the matching rrset with flattened record data for form population.
sub get_record ($self, $zone_id, $record_name, $record_type = undef) {
  my $filter = { name => $record_name };
  $filter->{type} = $record_type if $record_type;

  my $rrsets = $self->list_rrsets($zone_id, $filter);
  return undef unless @$rrsets;

  # Return first matching rrset, flatten first record's content for the form
  my $rrset = $rrsets->[0];
  my $record = $rrset->{records}[0] // {};

  return {
    name    => $rrset->{name},
    type    => $rrset->{type},
    ttl     => $rrset->{ttl},
    content => $record->{content},
    disabled => $record->{disabled},
  };
}

# Create or update a record using PowerDNS rrsets API.
# PowerDNS uses PATCH with rrsets and changetype REPLACE to create/update.
sub create_record ($self, $zone_id, $record_data) {
  my $url = $self->_api_url() . '/zones/' . $zone_id;

  my $payload = {
    rrsets => [{
      name       => $record_data->{name},
      type       => $record_data->{type},
      ttl        => $record_data->{ttl} || 3600,
      changetype => 'REPLACE',
      records    => [{
        content  => $record_data->{content},
        disabled => $record_data->{disabled} ? \1 : \0,
      }],
    }],
  };

  my $tx = $self->ua->patch($url, $self->_headers, json => $payload);
  my $res = $tx->result;

  if ($res && ($res->is_success || $res->code == 204)) {
    return { success => 1 };
  }

  my $error = $res ? ($res->json->{error} // $res->message) : "No response";
  return { success => 0, error => $error };
}

# Update an existing record in a zone (same as create - REPLACE overwrites).
sub update_record ($self, $zone_id, $record_id, $record_data) {
  # PowerDNS uses name+type to identify rrsets, not record_id
  # The record_id format from JS is "TYPE_name" - we parse it but prefer record_data
  return $self->create_record($zone_id, $record_data);
}

# Delete a record using PowerDNS rrsets API with changetype DELETE.
# record_id format: "TYPE_name" (e.g., "A_www.example.com.")
sub delete_record ($self, $zone_id, $record_id) {
  my $url = $self->_api_url() . '/zones/' . $zone_id;

  # Parse record_id: TYPE_name
  my ($type, $name) = $record_id =~ /^([^_]+)_(.+)$/;
  return { success => 0, error => "Invalid record ID format" } unless $type && $name;

  my $payload = {
    rrsets => [{
      name       => $name,
      type       => $type,
      changetype => 'DELETE',
    }],
  };

  my $tx = $self->ua->patch($url, $self->_headers, json => $payload);
  my $res = $tx->result;

  if ($res && ($res->is_success || $res->code == 204)) {
    return { success => 1 };
  }

  my $error = $res ? ($res->json->{error} // $res->message) : "No response";
  return { success => 0, error => $error };
}

# Clear the zone list cache (e.g., after creating/updating/deleting a zone)
sub clear_cache ($self) {
  $self->cache->del('zone:list');
}

### Cryptokeys Methods (DNSSEC)

# List cryptokeys for a zone.
sub list_cryptokeys ($self, $zone_id) {
  my $url = $self->_api_url() . '/zones/' . $zone_id . '/cryptokeys';
  my $tx = $self->ua->get($url, $self->_headers);
  if (my $res = $tx->result) {
    return $res->is_success ? $res->json : [];
  }
  return [];
}

# Create a new cryptokey for a zone.
sub create_cryptokey ($self, $zone_id, $key_data = {}) {
  my $url = $self->_api_url() . '/zones/' . $zone_id . '/cryptokeys';
  my $payload = {
    keytype  => $key_data->{keytype}  // 'ksk',
    active   => $key_data->{active}   // \1,
    algorithm => $key_data->{algorithm} // 'ECDSAP256SHA256',
  };
  # Add bits if specified (required for RSA algorithms)
  $payload->{bits} = $key_data->{bits} if $key_data->{bits};

  my $tx = $self->ua->post($url, $self->_headers, json => $payload);
  my $res = $tx->result;

  if ($res && $res->is_success) {
    return { success => 1, key => $res->json };
  }

  my $error = $res ? ($res->json->{error} // $res->message) : "No response";
  return { success => 0, error => $error };
}

# Delete a cryptokey.
sub delete_cryptokey ($self, $zone_id, $key_id) {
  my $url = $self->_api_url() . '/zones/' . $zone_id . '/cryptokeys/' . $key_id;
  my $tx = $self->ua->delete($url, $self->_headers);
  my $res = $tx->result;

  if ($res && ($res->is_success || $res->code == 204)) {
    return { success => 1 };
  }

  my $error = $res ? ($res->json->{error} // $res->message) : "No response";
  return { success => 0, error => $error };
}

# Decode a punycode domain name to Unicode.
sub _decode_idn ($self, $name) {
  return $name unless $name && $name =~ /xn--/;
  my $decoded = eval { domain_to_unicode($name) };
  return $@ ? $name : $decoded;
}

# Search zones directly via PostgreSQL (faster for live search).
# Supports filtering by name pattern (ILIKE) and account (exact match).
# Handles IDN/punycode: Unicode search terms match decoded domain names.
# Returns array of zone hashes with id, name, and unicode_name.
sub search_zones ($self, $params = {}) {
  my $db = $self->db->db;
  my $searchterm = $params->{searchterm};
  my $is_unicode_search = $searchterm && $searchterm =~ /[^\x00-\x7F]/;

  my @conditions;
  my @bindings;

  # Name search (ILIKE for case-insensitive partial match)
  if ($searchterm && !$is_unicode_search) {
    # ASCII search - direct SQL match
    push @conditions, 'd.name ILIKE ?';
    push @bindings, '%' . $searchterm . '%';
  }

  # Filter by account (standard PowerDNS field)
  if (defined $params->{account} && $params->{account} ne '') {
    push @conditions, 'd.account = ?';
    push @bindings, $params->{account};
  }

  my $sql = 'SELECT d.id, d.name, d.type AS kind, d.account, COUNT(DISTINCT r.id) AS record_count, COUNT(DISTINCT c.id) AS cryptokey_count FROM domains d LEFT JOIN records r ON d.id = r.domain_id LEFT JOIN cryptokeys c ON d.id = c.domain_id';

  # For Unicode search, fetch all xn-- domains to decode and filter in Perl
  if ($is_unicode_search) {
    if (@conditions) {
      push @conditions, 'd.name LIKE ?';
      push @bindings, '%xn--%';
      $sql .= ' WHERE ' . join(' AND ', @conditions);
    } else {
      $sql .= ' WHERE d.name LIKE ?';
      push @bindings, '%xn--%';
    }
  } elsif (@conditions) {
    $sql .= ' WHERE ' . join(' AND ', @conditions);
  }

  $sql .= ' GROUP BY d.id, d.name, d.type, d.account ORDER BY d.name ASC';

  # Optional limit (applied after filtering for Unicode search)
  my $limit = $params->{limit};
  if ($limit && !$is_unicode_search) {
    $sql .= ' LIMIT ?';
    push @bindings, $limit;
  }

  my $results = $db->query($sql, @bindings)->hashes->to_array;

  # Add decoded Unicode name for display
  for my $zone (@$results) {
    $zone->{unicode_name} = $self->_decode_idn($zone->{name});
  }

  # For Unicode search, filter by decoded name
  if ($is_unicode_search) {
    my $pattern = lc($searchterm);
    $results = [ grep { index(lc($_->{unicode_name}), $pattern) >= 0 } @$results ];
    # Apply limit after filtering
    if ($limit && @$results > $limit) {
      $results = [ @$results[0 .. $limit - 1] ];
    }
  }

  return $results;
}

1;
