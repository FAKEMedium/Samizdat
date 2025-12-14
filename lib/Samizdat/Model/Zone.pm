# lib/Samizdat/Model/Zone.pm
package Samizdat::Model::Zone;

use Mojo::Base -base, -signatures;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::UserAgent;
use Net::IDN::Encode qw(:all);
use Data::Dumper;

has 'config';
has 'cache';
has 'pdns';  # Mojo::Pg connection to PowerDNS database
has 'pg';    # Mojo::Pg connection to main Samizdat database (for templates)
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

# Normalize DNS name/content for comparison (handle trailing dots)
sub _normalize_dns ($self, $value) {
  return '' unless defined $value;
  $value =~ s/\.$//;  # Remove trailing dot
  return lc($value);  # Case-insensitive
}

# Create or update a record using PowerDNS rrsets API.
# PowerDNS uses PATCH with rrsets and changetype REPLACE to create/update.
# For types that allow multiple records (MX, NS, A, AAAA, TXT), we preserve existing records.
sub create_record ($self, $zone_id, $record_data) {
  my $url = $self->_api_url() . '/zones/' . $zone_id;

  # Types that commonly have multiple records per name
  my %multi_record_types = map { $_ => 1 } qw(MX NS A AAAA TXT SRV);

  my @records;

  # If this type supports multiple records, fetch existing and append
  if ($multi_record_types{$record_data->{type}}) {
    my $existing = $self->list_rrsets($zone_id, {
      name => $record_data->{name},
      type => $record_data->{type}
    });

    if (@$existing && $existing->[0]{records}) {
      # Keep existing records that don't match the new content
      my $new_content_normalized = $self->_normalize_dns($record_data->{content});
      for my $rec (@{$existing->[0]{records}}) {
        # Skip if this is the same content (updating existing)
        next if $self->_normalize_dns($rec->{content}) eq $new_content_normalized;
        push @records, {
          content  => $rec->{content},
          disabled => $rec->{disabled} ? \1 : \0,
        };
      }
    }
  }

  # Add the new/updated record
  push @records, {
    content  => $record_data->{content},
    disabled => $record_data->{disabled} ? \1 : \0,
  };

  my $payload = {
    rrsets => [{
      name       => $record_data->{name},
      type       => $record_data->{type},
      ttl        => $record_data->{ttl} || 3600,
      changetype => 'REPLACE',
      records    => \@records,
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

# Create an rrset with multiple records (for templates with same name+type).
sub _create_rrset ($self, $zone_id, $rrset) {
  my $url = $self->_api_url() . '/zones/' . $zone_id;

  my $payload = {
    rrsets => [{
      name       => $rrset->{name},
      type       => $rrset->{type},
      ttl        => $rrset->{ttl} || 3600,
      changetype => 'REPLACE',
      records    => $rrset->{records},
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

# Expand @ references in template record content based on record type.
# Different record types have different content formats:
#   A/AAAA: IP address - no replacement
#   CNAME/NS: hostname - replace @ with zone FQDN
#   TXT: text - no replacement
#   MX: "priority hostname" - replace @ in hostname part
#   SRV: "priority weight port target" - replace @ in target part
#   CAA: "flags tag value" - no replacement (value is CA name)
#   SOA: "primary admin ..." - replace @ in primary and admin parts
sub _expand_template_content ($self, $type, $content, $zone_name) {
  return $content unless defined $content;

  # zone_name already has trailing dot from _normalize_zone_name
  my $zone_fqdn = $zone_name;

  # Helper to replace @ patterns with zone FQDN
  # Handles: @ -> example.com.
  #          ns1.@ -> ns1.example.com.
  #          admin.@ -> admin.example.com.
  my $expand = sub {
    my ($val) = @_;
    return $val unless defined $val;
    return $zone_fqdn if $val eq '@';
    if ($val =~ /^(.+)\.\@$/) {
      return "$1.$zone_fqdn";
    }
    return $val;
  };

  if ($type eq 'CNAME' || $type eq 'NS') {
    # Simple hostname - replace @ directly
    return $expand->($content);
  }
  elsif ($type eq 'MX') {
    # Format: "priority hostname"
    my ($priority, $hostname) = split /\s+/, $content, 2;
    return "$priority " . $expand->($hostname // '');
  }
  elsif ($type eq 'SRV') {
    # Format: "priority weight port target"
    my @parts = split /\s+/, $content;
    if (@parts >= 4) {
      $parts[3] = $expand->($parts[3]);
    }
    return join ' ', @parts;
  }
  elsif ($type eq 'SOA') {
    # Format: "primary admin serial refresh retry expire minimum"
    my @parts = split /\s+/, $content;
    $parts[0] = $expand->($parts[0]) if @parts > 0;  # primary NS
    $parts[1] = $expand->($parts[1]) if @parts > 1;  # admin email
    return join ' ', @parts;
  }

  # A, AAAA, TXT, CAA - return as-is
  return $content;
}

### Zone Templates (stored in zone schema)

# List available templates, optionally filtered by customerid.
sub list_templates ($self, $params = {}) {
  my $db = $self->pg->db;
  my $sql = 'SELECT t.templateid, t.customerid, t.name, t.description,
             COUNT(r.recordid) AS record_count
             FROM zone.templates t
             LEFT JOIN zone.template_records r ON t.templateid = r.templateid
             WHERE t.customerid IS NULL';
  my @bindings;

  # Include customer-specific templates if customerid provided
  if ($params->{customerid}) {
    $sql .= ' OR t.customerid = ?';
    push @bindings, $params->{customerid};
  }

  $sql .= ' GROUP BY t.templateid ORDER BY t.name';
  return $db->query($sql, @bindings)->hashes->to_array;
}

# Get a template with its records.
sub get_template ($self, $templateid) {
  my $db = $self->pg->db;
  my $template = $db->query(
    'SELECT * FROM zone.templates WHERE templateid = ?', $templateid
  )->hash;
  return undef unless $template;

  $template->{records} = $db->query(
    'SELECT * FROM zone.template_records WHERE templateid = ? ORDER BY type, name',
    $templateid
  )->hashes->to_array;

  return $template;
}

# Create a new template.
sub create_template ($self, $data) {
  my $db = $self->pg->db;
  my $result = $db->insert('zone.templates', {
    name        => $data->{name},
    description => $data->{description} // '',
    customerid  => $data->{customerid} || undef,
  }, { returning => 'templateid' });
  return { success => 1, templateid => $result->hash->{templateid} };
}

# Update a template.
sub update_template ($self, $templateid, $data) {
  my $db = $self->pg->db;
  $db->update('zone.templates', {
    name        => $data->{name},
    description => $data->{description} // '',
    customerid  => $data->{customerid} || undef,
  }, { templateid => $templateid });
  return { success => 1 };
}

# Delete a template (cascade deletes records).
sub delete_template ($self, $templateid) {
  my $db = $self->pg->db;
  $db->delete('zone.templates', { templateid => $templateid });
  return { success => 1 };
}

# Duplicate a template with all its records.
sub duplicate_template ($self, $templateid) {
  my $db = $self->pg->db;

  # Get original template
  my $original = $self->get_template($templateid);
  return { success => 0, error => 'Template not found' } unless $original;

  # Create new template with "Copy of" prefix
  my $tx = $db->begin;
  my $new_template = $db->insert('zone.templates', {
    name        => "Copy of $original->{name}",
    description => $original->{description} // '',
    customerid  => $original->{customerid},
  }, { returning => 'templateid' });
  my $new_id = $new_template->hash->{templateid};

  # Copy all records
  for my $rec (@{$original->{records}}) {
    $db->insert('zone.template_records', {
      templateid => $new_id,
      name       => $rec->{name},
      type       => $rec->{type},
      content    => $rec->{content},
      ttl        => $rec->{ttl},
      disabled   => $rec->{disabled},
    });
  }

  $tx->commit;
  return { success => 1, templateid => $new_id };
}

# Create a template record.
sub create_template_record ($self, $templateid, $data) {
  my $db = $self->pg->db;
  my $result = $db->insert('zone.template_records', {
    templateid => $templateid,
    name       => $data->{name},
    type       => $data->{type},
    content    => $data->{content},
    ttl        => $data->{ttl} // 3600,
    disabled   => $data->{disabled} ? 1 : 0,
  }, { returning => 'recordid' });
  return { success => 1, recordid => $result->hash->{recordid} };
}

# Update a template record.
sub update_template_record ($self, $recordid, $data) {
  my $db = $self->pg->db;
  $db->update('zone.template_records', {
    name     => $data->{name},
    type     => $data->{type},
    content  => $data->{content},
    ttl      => $data->{ttl} // 3600,
    disabled => $data->{disabled} ? 1 : 0,
  }, { recordid => $recordid });
  return { success => 1 };
}

# Delete a template record.
sub delete_template_record ($self, $recordid) {
  my $db = $self->pg->db;
  $db->delete('zone.template_records', { recordid => $recordid });
  return { success => 1 };
}

# Get a single template record.
sub get_template_record ($self, $recordid) {
  my $db = $self->pg->db;
  return $db->select('zone.template_records', '*', { recordid => $recordid })->hash;
}

# Create zone from template - creates zone then adds template records.
sub create_zone_from_template ($self, $zone_data, $templateid) {
  # First create the zone
  my $result = $self->create_zone($zone_data);
  return $result unless $result->{success};

  # Get the template
  my $template = $self->get_template($templateid);
  return { success => 0, error => 'Template not found' } unless $template;

  my $zone_name = $self->_normalize_zone_name($zone_data->{name});

  # Group template records by name+type (PowerDNS replaces entire rrsets)
  my %rrsets;
  for my $rec (@{$template->{records}}) {
    # Replace @ with zone name, append zone to relative names
    # Handles: @ -> example.com, ns1.@ -> ns1.example.com, ns1 -> ns1.example.com
    my $name = $rec->{name};
    if ($name eq '@' || $name eq '') {
      $name = $zone_name;
    } elsif ($name =~ /^(.+)\.\@$/) {
      # Pattern like ns1.@ -> ns1.example.com
      $name = "$1.$zone_name";
    } elsif ($name !~ /\.$/) {
      $name = "$name.$zone_name";
    }

    # Replace @ in content with zone FQDN based on record type
    my $content = $self->_expand_template_content($rec->{type}, $rec->{content}, $zone_name);

    my $key = "$name|$rec->{type}";
    $rrsets{$key} //= { name => $name, type => $rec->{type}, ttl => $rec->{ttl}, records => [] };
    push @{$rrsets{$key}{records}}, { content => $content, disabled => $rec->{disabled} ? \1 : \0 };

    say "Template record: $rec->{name} $rec->{type} $rec->{content} -> $name $rec->{type} $content";
  }

  # Create each rrset (with all records of same name+type together)
  for my $rrset (values %rrsets) {
    my $rec_result = $self->_create_rrset($zone_name, $rrset);
    if ($rec_result->{success}) {
      say "  Created: $rrset->{name} $rrset->{type} (" . scalar(@{$rrset->{records}}) . " records)";
    } else {
      say "  FAILED: $rrset->{name} $rrset->{type} - $rec_result->{error}";
    }
  }

  return { success => 1, zone => $zone_name, template => $template->{name} };
}

# Search zones directly via PostgreSQL (faster for live search).
# Supports filtering by name pattern (ILIKE) and account (exact match).
# Handles IDN/punycode: Unicode search terms match decoded domain names.
# Returns array of zone hashes with id, name, and unicode_name.
sub search_zones ($self, $params = {}) {
  my $db = $self->pdns->db;
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
