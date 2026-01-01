# lib/Samizdat/Model/Zone.pm
package Samizdat::Model::Zone;

use Mojo::Base -base, -signatures;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::UserAgent;
use Net::IDN::Encode qw(:all);
use Net::DNS;
use Net::Whois::Raw qw(whois);
use Time::HiRes qw(gettimeofday tv_interval);
use Socket qw(inet_aton);
use Data::Dumper;

has 'config';
has 'cache';
has 'pdns';  # Mojo::Pg connection to PowerDNS database
has 'pg';    # Mojo::Pg connection to main Samizdat database (for templates)
has ua => sub { Mojo::UserAgent->new };

# Get configured source IPs for outgoing DNS connections
has 'source_ips' => sub ($self) {
  my $ips = $self->config->{check}->{source_ips} // [];
  return ref $ips eq 'ARRAY' ? $ips : [$ips];
};

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

  my $error = "No response";
  if ($res) {
    my $json = eval { $res->json };
    $error = ($json && $json->{error}) ? $json->{error} : $res->message;
  }
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

  my $error = "No response";
  if ($res) {
    my $json = eval { $res->json };
    $error = ($json && $json->{error}) ? $json->{error} : $res->message;
  }
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

  my $error = "No response";
  if ($res) {
    my $json = eval { $res->json };
    $error = ($json && $json->{error}) ? $json->{error} : $res->message;
  }
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

# Get a specific rrset from a zone by name and optionally type and content.
# PowerDNS rrsets are identified by name+type, not by a single ID.
# For multi-record rrsets (MX, NS, etc.), content is needed to identify the specific record.
# Returns the matching rrset with flattened record data for form population.
sub get_record ($self, $zone_id, $record_name, $record_type = undef, $record_content = undef) {
  my $filter = { name => $record_name };
  $filter->{type} = $record_type if $record_type;

  my $rrsets = $self->list_rrsets($zone_id, $filter);
  return undef unless @$rrsets;

  my $rrset = $rrsets->[0];
  my $record;

  # If content provided, find the specific record in the rrset
  if ($record_content && $rrset->{records}) {
    my $content_normalized = $self->_normalize_dns($record_content);
    for my $rec (@{$rrset->{records}}) {
      if ($self->_normalize_dns($rec->{content}) eq $content_normalized) {
        $record = $rec;
        last;
      }
    }
  }

  # Fall back to first record if no content match or no content specified
  $record //= $rrset->{records}[0] // {};

  # Priority is part of content (zone-file style) in PowerDNS 4.9+
  return {
    name     => $rrset->{name},
    type     => $rrset->{type},
    ttl      => $rrset->{ttl},
    content  => $record->{content},
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
  my %multi_record_types = map { $_ => 1 } qw(MX NS A AAAA TXT SRV NAPTR);

  my @records;

  # Build the full content first (prepend priority for MX/SRV/NAPTR)
  # PowerDNS 4.9+ requires priority in content (zone-file style), not as separate field
  my $content = $record_data->{content};
  if ($record_data->{type} eq 'MX' && defined $record_data->{priority}) {
    $content = int($record_data->{priority}) . " " . $content;
  } elsif ($record_data->{type} eq 'SRV' && defined $record_data->{priority}) {
    $content = int($record_data->{priority}) . " " . $content;
  } elsif ($record_data->{type} eq 'NAPTR' && defined $record_data->{priority}) {
    $content = int($record_data->{priority}) . " " . $content;
  }

  # Normalize for comparison (now includes priority)
  my $new_content_normalized = $self->_normalize_dns($content);
  my $original_content_normalized = $record_data->{original_content}
    ? $self->_normalize_dns($record_data->{original_content})
    : undef;

  # If this type supports multiple records, fetch existing and append
  if ($multi_record_types{$record_data->{type}}) {
    my $existing = $self->list_rrsets($zone_id, {
      name => $record_data->{name},
      type => $record_data->{type}
    });

    if (@$existing && $existing->[0]{records}) {
      for my $rec (@{$existing->[0]{records}}) {
        my $rec_normalized = $self->_normalize_dns($rec->{content});
        # Skip if this is the same as new content (prevents duplicates on retry)
        next if $rec_normalized eq $new_content_normalized;
        # Skip if this is the original content being updated (remove old record)
        next if $original_content_normalized && $rec_normalized eq $original_content_normalized;
        push @records, {
          content  => $rec->{content},
          disabled => $rec->{disabled} ? \1 : \0,
        };
      }
    }
  }

  # Add the new record
  push @records, {
    content  => $content,
    disabled => $record_data->{disabled} ? \1 : \0,
  };

  my $payload = {
    rrsets => [{
      name       => $record_data->{name},
      type       => $record_data->{type},
      ttl        => int($record_data->{ttl} || 3600),
      changetype => 'REPLACE',
      records    => \@records,
    }],
  };

  my $tx = $self->ua->patch($url, $self->_headers, json => $payload);
  my $res = $tx->result;

  if ($res && ($res->is_success || $res->code == 204)) {
    return { success => 1 };
  }

  my $error = "No response";
  if ($res) {
    my $json = eval { $res->json };
    $error = ($json && $json->{error}) ? $json->{error} : $res->message;
  }
  return { success => 0, error => $error };
}

# Create an rrset with multiple records (for templates with same name+type).
sub _create_rrset ($self, $zone_id, $rrset) {
  my $url = $self->_api_url() . '/zones/' . $zone_id;

  my $payload = {
    rrsets => [{
      name       => $rrset->{name},
      type       => $rrset->{type},
      ttl        => int($rrset->{ttl} || 3600),
      changetype => 'REPLACE',
      records    => $rrset->{records},
    }],
  };

  my $tx = $self->ua->patch($url, $self->_headers, json => $payload);
  my $res = $tx->result;

  if ($res && ($res->is_success || $res->code == 204)) {
    return { success => 1 };
  }

  my $error = "No response";
  if ($res) {
    my $json = eval { $res->json };
    $error = ($json && $json->{error}) ? $json->{error} : $res->message;
  }
  return { success => 0, error => $error };
}

# Update an existing record in a zone (same as create - REPLACE overwrites).
sub update_record ($self, $zone_id, $record_id, $record_data) {
  # PowerDNS uses name+type to identify rrsets, not record_id
  # The record_id format from JS is "TYPE_name" - we parse it but prefer record_data
  return $self->create_record($zone_id, $record_data);
}

# Delete a record using PowerDNS rrsets API.
# For multi-record rrsets (MX, NS, etc.), removes only the specified record.
# record_id format: "TYPE_name" (e.g., "A_www.example.com.")
# content: optional - if provided, only delete this specific record from the rrset
sub delete_record ($self, $zone_id, $record_id, $content = undef) {
  my $url = $self->_api_url() . '/zones/' . $zone_id;

  # Parse record_id: TYPE_name
  my ($type, $name) = $record_id =~ /^([^_]+)_(.+)$/;
  return { success => 0, error => "Invalid record ID format" } unless $type && $name;

  # Types that commonly have multiple records per name
  my %multi_record_types = map { $_ => 1 } qw(MX NS A AAAA TXT SRV NAPTR);

  my $payload;

  # If content provided and this is a multi-record type, use REPLACE to keep other records
  if ($content && $multi_record_types{$type}) {
    my $existing = $self->list_rrsets($zone_id, { name => $name, type => $type });

    if (@$existing && $existing->[0]{records}) {
      my $content_normalized = $self->_normalize_dns($content);
      my @remaining;

      for my $rec (@{$existing->[0]{records}}) {
        my $rec_normalized = $self->_normalize_dns($rec->{content});
        # Keep all records except the one matching content
        next if $rec_normalized eq $content_normalized;
        push @remaining, {
          content  => $rec->{content},
          disabled => $rec->{disabled} ? \1 : \0,
        };
      }

      if (@remaining) {
        # REPLACE with remaining records
        $payload = {
          rrsets => [{
            name       => $name,
            type       => $type,
            ttl        => int($existing->[0]{ttl} || 3600),
            changetype => 'REPLACE',
            records    => \@remaining,
          }],
        };
      } else {
        # No records left, DELETE the entire rrset
        $payload = {
          rrsets => [{
            name       => $name,
            type       => $type,
            changetype => 'DELETE',
          }],
        };
      }
    } else {
      # Rrset doesn't exist, nothing to delete
      return { success => 1 };
    }
  } else {
    # No content or single-record type: DELETE entire rrset
    $payload = {
      rrsets => [{
        name       => $name,
        type       => $type,
        changetype => 'DELETE',
      }],
    };
  }

  my $tx = $self->ua->patch($url, $self->_headers, json => $payload);
  my $res = $tx->result;

  if ($res && ($res->is_success || $res->code == 204)) {
    return { success => 1 };
  }

  my $error = "No response";
  if ($res) {
    my $json = eval { $res->json };
    $error = ($json && $json->{error}) ? $json->{error} : $res->message;
  }
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

  my $error = "No response";
  if ($res) {
    my $json = eval { $res->json };
    $error = ($json && $json->{error}) ? $json->{error} : $res->message;
  }
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

  my $error = "No response";
  if ($res) {
    my $json = eval { $res->json };
    $error = ($json && $json->{error}) ? $json->{error} : $res->message;
  }
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

### Zone Check Methods

# Check multiple zones matching a wildcard pattern
sub check_zones ($self, $pattern) {
  my $max_checks = $self->config->{check}->{max_checks} // 0;

  # Check if pattern contains wildcards
  if ($pattern =~ /[*?]/) {
    say "=== Zone Check (wildcard): $pattern ===";

    # Convert glob pattern to SQL LIKE pattern
    my $sql_pattern = $pattern;
    $sql_pattern =~ s/\*/%/g;
    $sql_pattern =~ s/\?/_/g;

    # Search for matching zones
    my $zones = $self->search_zones({ searchterm => '' });

    # Filter by pattern (search_zones doesn't support LIKE directly)
    my @matching = grep {
      my $name = $_->{name} =~ s/\.$//r;
      $name =~ /^$pattern$/i || $name =~ /$sql_pattern/i;
    } @$zones;

    # Apply regex matching for glob patterns
    my $regex = $pattern;
    $regex =~ s/\./\\./g;
    $regex =~ s/\*/.*/g;
    $regex =~ s/\?/./g;
    @matching = grep {
      my $name = $_->{name} =~ s/\.$//r;
      $name =~ /^$regex$/i;
    } @$zones;

    say "  Found " . scalar(@matching) . " matching zones";

    my @results;
    my $count = 0;
    for my $zone (@matching) {
      my $name = $zone->{name} =~ s/\.$//r;
      push @results, $self->check_zone($name);

      $count++;
      if ($max_checks > 0 && $count >= $max_checks) {
        say "  Stopping after $count zones (max_checks limit)";
        last;
      }
    }

    return {
      success => 1,
      pattern => $pattern,
      total_zones => scalar(@matching),
      checked_zones => $count,
      results => \@results,
    };
  }

  # No wildcard - check single zone
  return $self->check_zone($pattern);
}

# Main zone check method - performs whois and DNS checks
sub check_zone ($self, $zone_name) {
  $zone_name =~ s/\.$//;  # Remove trailing dot for whois

  say "=== Zone Check: $zone_name ===";

  my $result = {
    success => 1,
    zone => $zone_name,
    whois => {},
    checks => [],
    errors => [],
  };

  # Step 1: Whois lookup to get registered nameservers
  say "Step 1: Whois lookup...";
  my $whois_result = $self->_whois_lookup($zone_name);
  if ($whois_result->{error}) {
    say "  Whois error: $whois_result->{error}";
    push @{$result->{errors}}, "Whois: $whois_result->{error}";
  } else {
    say "  Registrar: " . ($whois_result->{registrar} // 'unknown');
    say "  Whois NS: " . join(', ', @{$whois_result->{nameservers} // []});
    $result->{whois} = $whois_result;
  }

  # Step 2: Get nameservers from DNS (authoritative)
  say "Step 2: DNS NS lookup...";
  my $dns_ns = $self->_get_ns_from_dns($zone_name);
  say "  DNS NS: " . join(', ', @{$dns_ns // []});

  # Combine whois and DNS nameservers
  my %all_ns;
  for my $ns (@{$whois_result->{nameservers} // []}) {
    $all_ns{lc($ns)} = 1;
  }
  for my $ns (@{$dns_ns // []}) {
    $all_ns{lc($ns)} = 1;
  }

  my @nameservers = sort keys %all_ns;
  say "  Combined NS: " . join(', ', @nameservers);

  if (!@nameservers) {
    say "  ERROR: No nameservers found!";
    push @{$result->{errors}}, "No nameservers found";
    $result->{success} = 0;
    return $result;
  }

  # Step 3: Check each nameserver
  my $source_ips = $self->source_ips;
  my $source_index = 0;
  my $rate_limit = $self->config->{check}->{rate_limit} // 2;
  my $timeout = $self->config->{check}->{timeout} // 5;
  my $delay = $rate_limit > 0 ? 1 / $rate_limit : 0;

  my $max_checks = $self->config->{check}->{max_checks} // 0;  # 0 = unlimited
  say "Step 3: Checking nameservers (rate_limit=$rate_limit/s, timeout=${timeout}s, delay=${delay}s, max=$max_checks)...";
  say "  Source IPs: " . (@$source_ips ? join(', ', @$source_ips) : 'default');

  my $check_count = 0;
  for my $ns (@nameservers) {
    # Rotate through source IPs
    my $source_ip = @$source_ips ? $source_ips->[$source_index++ % @$source_ips] : undef;

    say "  Checking $ns" . ($source_ip ? " (from $source_ip)" : "") . "...";
    my $check = $self->_check_nameserver($zone_name, $ns, $source_ip);
    push @{$result->{checks}}, $check;

    if ($check->{reachable}) {
      say "    OK: IP=$check->{ip}, SOA serial=" . ($check->{soa}{serial} // 'n/a') . ", $check->{response_time_ms}ms";
    } else {
      say "    FAILED: " . ($check->{error} // 'unknown error');
    }

    # Stop after max_checks (for testing)
    $check_count++;
    if ($max_checks > 0 && $check_count >= $max_checks) {
      say "  Stopping after $check_count checks (max_checks limit)";
      last;
    }

    # Rate limit between checks
    Time::HiRes::sleep($delay) if $delay > 0 && $ns ne $nameservers[-1];
  }

  # Step 4: Verify consistency
  say "Step 4: Verifying consistency...";
  my @soa_serials = map { $_->{soa}{serial} } grep { $_->{reachable} && $_->{soa} } @{$result->{checks}};
  my %unique_serials;
  $unique_serials{$_}++ for @soa_serials;

  if (keys %unique_serials > 1) {
    my $msg = "SOA serial mismatch: " . join(', ', sort keys %unique_serials);
    say "  WARNING: $msg";
    push @{$result->{errors}}, $msg;
  } else {
    say "  SOA serials: " . (join(', ', sort keys %unique_serials) || 'none');
  }

  # Check NS record consistency
  my @ns_sets = map { join(',', sort @{$_->{ns_records} // []}) }
                grep { $_->{reachable} && $_->{ns_records} } @{$result->{checks}};
  my %unique_ns_sets;
  $unique_ns_sets{$_}++ for @ns_sets;

  if (keys %unique_ns_sets > 1) {
    say "  WARNING: NS records inconsistent across nameservers";
    push @{$result->{errors}}, "NS records inconsistent across nameservers";
  } else {
    say "  NS records consistent: " . scalar(keys %unique_ns_sets) . " unique set(s)";
  }

  # Mark NS match status
  my $expected_ns = $result->{whois}{nameservers} // [];
  for my $check (@{$result->{checks}}) {
    next unless $check->{ns_records};
    my %expected = map { lc($_) => 1 } @$expected_ns;
    my %actual = map { lc($_) => 1 } @{$check->{ns_records}};
    $check->{ns_match} = _sets_equal(\%expected, \%actual);
  }

  say "=== Zone Check Complete: " . (@{$result->{errors}} ? scalar(@{$result->{errors}}) . " issue(s)" : "OK") . " ===";
  return $result;
}

# Helper to compare two sets
sub _sets_equal ($set_a, $set_b) {
  return 0 if keys %$set_a != keys %$set_b;
  for my $key (keys %$set_a) {
    return 0 unless exists $set_b->{$key};
  }
  return 1;
}

# Whois lookup for a zone
sub _whois_lookup ($self, $zone_name) {
  my $result = {
    nameservers => [],
    registrar => '',
    status => [],
  };

  eval {
    local $Net::Whois::Raw::OMIT_MSG = 1;
    local $Net::Whois::Raw::CHECK_FAIL = 1;
    local $Net::Whois::Raw::TIMEOUT = 10;

    my $whois_data = whois($zone_name);
    return { error => "No whois data returned" } unless $whois_data;

    # Parse nameservers (various formats)
    my @ns;
    while ($whois_data =~ /(?:Name\s*Server|nserver|NS|nameservers?)\s*[:\.]?\s*([a-z0-9.-]+\.[a-z]{2,})/gi) {
      my $ns = lc($1);
      $ns =~ s/\.$//;
      push @ns, $ns unless grep { $_ eq $ns } @ns;
    }
    $result->{nameservers} = \@ns;

    # Parse registrar
    if ($whois_data =~ /(?:Registrar|Sponsoring\s+Registrar)\s*[:\.]?\s*(.+)/i) {
      $result->{registrar} = $1;
      $result->{registrar} =~ s/\s+$//;
    }

    # Parse status
    while ($whois_data =~ /(?:Status|Domain\s+Status)\s*[:\.]?\s*([^\n]+)/gi) {
      my $status = $1;
      $status =~ s/\s+$//;
      push @{$result->{status}}, $status;
    }
  };

  if ($@) {
    return { error => $@ };
  }

  return $result;
}

# Get NS records from DNS
sub _get_ns_from_dns ($self, $zone_name) {
  my $timeout = $self->config->{check}->{timeout} // 5;
  my @nameservers;

  eval {
    my $resolver = Net::DNS::Resolver->new(
      recurse => 1,
      tcp_timeout => $timeout,
      udp_timeout => $timeout,
    );

    my $reply = $resolver->query($zone_name, 'NS');
    if ($reply) {
      for my $rr ($reply->answer) {
        next unless $rr->type eq 'NS';
        my $ns = lc($rr->nsdname);
        $ns =~ s/\.$//;
        push @nameservers, $ns;
      }
    }
  };

  return \@nameservers;
}

# Check a specific nameserver for SOA and NS records
sub _check_nameserver ($self, $zone_name, $ns_name, $source_ip = undef) {
  my $timeout = $self->config->{check}->{timeout} // 5;

  my $result = {
    nameserver => $ns_name,
    ip => '',
    source_ip => $source_ip // 'default',
    reachable => 0,
    soa => undef,
    ns_records => [],
    ns_match => 0,
    response_time_ms => 0,
    error => undef,
  };

  eval {
    # Resolve nameserver IP
    my $ns_ip = inet_aton($ns_name);
    unless ($ns_ip) {
      $result->{error} = "Cannot resolve nameserver IP";
      return;
    }
    $result->{ip} = join('.', unpack('C4', $ns_ip));

    # Create resolver targeting this specific nameserver
    my $resolver = Net::DNS::Resolver->new(
      nameservers => [$result->{ip}],
      recurse => 0,  # Non-recursive for authoritative query
      tcp_timeout => $timeout,
      udp_timeout => $timeout,
    );

    # Set source IP if configured
    if ($source_ip && $source_ip ne 'default') {
      $resolver->srcaddr($source_ip);
    }

    # Query SOA
    my $t0 = [gettimeofday];
    my $soa_reply = $resolver->query($zone_name, 'SOA');
    my $elapsed = tv_interval($t0) * 1000;
    $result->{response_time_ms} = int($elapsed);

    if ($soa_reply) {
      $result->{reachable} = 1;
      for my $rr ($soa_reply->answer) {
        next unless $rr->type eq 'SOA';
        $result->{soa} = {
          serial => $rr->serial,
          primary => $rr->mname,
          admin => $rr->rname,
          refresh => $rr->refresh,
          retry => $rr->retry,
          expire => $rr->expire,
          minimum => $rr->minimum,
        };
        last;
      }
    } else {
      $result->{error} = $resolver->errorstring;
      return;
    }

    # Query NS records
    my $ns_reply = $resolver->query($zone_name, 'NS');
    if ($ns_reply) {
      for my $rr ($ns_reply->answer) {
        next unless $rr->type eq 'NS';
        my $ns = lc($rr->nsdname);
        $ns =~ s/\.$//;
        push @{$result->{ns_records}}, $ns;
      }
      $result->{ns_records} = [sort @{$result->{ns_records}}];
    }
  };

  if ($@) {
    $result->{error} = $@;
  }

  return $result;
}

1;
