# lib/Samizdat/Model/Zone.pm
package Samizdat::Model::Zone;

use Mojo::Base -base, -signatures;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::UserAgent;
use Data::Dumper;

has 'config';
has 'cache';
has ua => sub { Mojo::UserAgent->new };

# Helper to set API headers.
sub _headers ($self) {
  return {
    'X-API-Key'    => $self->config->{api}->{key},
    'Content-Type' => 'application/json',
  };
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
  my $url = $self->config->{api}->{url} . '/zones';
  my $tx  = $self->ua->get($url, $self->_headers, form => $params);

  if (my $res = $tx->result) {
    if ($res->is_success) {
      my $zones = $res->json;
      $self->cache->set($cache_key => $zones);
      return $zones;
    }
  }
  return [];
}

# Get details for a specific zone.
# The "rrsets" parameter defaults to "true".
sub get_zone ($self, $zone_id, $params = {}) {
  $params->{rrsets} //= 'false';
  my $url = $self->config->{api}->{url} . '/zones/' . $zone_id;
  my $tx  = $self->ua->get($url, $self->_headers, form => $params);
  if (my $res = $tx->result) {
    return $res->is_success ? $res->json : undef;
  }
  return undef;
}

# Create a new zone. Expects a hashref with keys like name and kind.
sub create_zone ($self, $zone_data) {
  my $url = $self->config->{api}->{url} . '/zones';
  my $payload = {
    name       => $zone_data->{name},
    kind       => $zone_data->{kind} // 'Master',
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

# Update an existing zone.
sub update_zone ($self, $zone_id, $zone_data) {
  my $url = $self->config->{api}->{url} . '/zones/' . $zone_id;
  my $payload = {
    name => $zone_data->{name},
    kind => $zone_data->{kind},
  };
  my $tx = $self->ua->patch($url, $self->_headers, json => $payload);
  my $res = $tx->result;

  if ($res && $res->is_success) {
    $self->clear_cache;
    return { success => 1 };
  }
  return { success => 0, error => $res ? $res->message : "No response" };
}

# Delete a zone.
sub delete_zone ($self, $zone_id) {
  my $url = $self->config->{api}->{url} . '/zones/' . $zone_id;
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

# Get a specific record from a zone.
sub get_record ($self, $zone_id, $record_id) {
#  my $records = $self->list_records($zone_id);
  my $records = $self->list_rrsets($zone_id, { name => $record_id});
  for my $rec (@$records) {
    return $rec if defined $rec->{id} && $rec->{id} eq $record_id;
  }
  return undef;
}

# Create a record by adding it to the zone's records array and updating the zone.
sub create_record ($self, $zone_id, $record_data) {
  my $url = $self->config->{api}->{url} . '/zones/' . $zone_id;
  my $zone_tx = $self->ua->get($url, $self->_headers);
  my $zone = $zone_tx->result->json;
  push @{ $zone->{records} //= [] }, $record_data;
  my $tx = $self->ua->patch($url, $self->_headers, json => $zone);
  my $res = $tx->result;
  return ($res && $res->is_success)
    ? { success => 1 }
    : { success => 0, error => $res ? $res->message : "No response" };
}

# Update an existing record in a zone.
sub update_record ($self, $zone_id, $record_id, $record_data) {
  my $url = $self->config->{api}->{url} . '/zones/' . $zone_id;
  my $zone_tx = $self->ua->get($url, $self->_headers);
  my $zone = $zone_tx->result->json;
  my $found;
  for my $rec (@{ $zone->{records} // [] }) {
    if (defined $rec->{id} && $rec->{id} eq $record_id) {
      $rec = { %$rec, %$record_data };
      $found = 1;
      last;
    }
  }
  return { success => 0, error => "Record not found" } unless $found;
  my $tx = $self->ua->patch($url, $self->_headers, json => $zone);
  my $res = $tx->result;
  return ($res && $res->is_success)
    ? { success => 1 }
    : { success => 0, error => $res ? $res->message : "No response" };
}

# Delete a record by removing it from the zone's records array and updating the zone.
sub delete_record ($self, $zone_id, $record_id) {
  my $url = $self->config->{api}->{url} . '/zones/' . $zone_id;
  my $zone_tx = $self->ua->get($url, $self->_headers);
  my $zone = $zone_tx->result->json;
  my $records = $zone->{records} // [];
  my $original_count = scalar(@$records);
  @$records = grep { !(defined $_->{id} && $_->{id} eq $record_id) } @$records;
  return { success => 0, error => "Record not found" } if scalar(@$records) == $original_count;
  my $tx = $self->ua->patch($url, $self->_headers, json => $zone);
  my $res = $tx->result;
  return ($res && $res->is_success)
    ? { success => 1 }
    : { success => 0, error => $res ? $res->message : "No response" };
}

# Clear the zone list cache (e.g., after creating/updating/deleting a zone)
sub clear_cache ($self) {
  $self->cache->del('zone:list');
}

1;
