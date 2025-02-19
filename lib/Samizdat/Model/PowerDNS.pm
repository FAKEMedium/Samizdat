package Samizdat::Model::PowerDNS;

use Mojo::Base -base, -signatures;
use Mojo::UserAgent;
use Mojo::JSON qw(encode_json decode_json);

has api_url => sub { die "api_url required" };
has api_key => sub { die "api_key required" };
has ua      => sub { Mojo::UserAgent->new };


# Set API headers
sub _headers ($self) {
  return {
    'X-API-Key'    => $self->api_key,
    'Content-Type' => 'application/json',
  };
}

### Zone methods

sub list_zones ($self) {
  my $url = $self->api_url . '/servers/localhost/zones';
  my $tx  = $self->ua->get($url, $self->_headers);
  if (my $res = $tx->result) {
    return $res->is_success ? $res->json : [];
  }
  return [];
}

sub get_zone ($self, $zone_id) {
  my $url = $self->api_url . '/servers/localhost/zones/' . $zone_id;
  my $tx  = $self->ua->get($url, $self->_headers);
  if (my $res = $tx->result) {
    return $res->is_success ? $res->json : undef;
  }
  return undef;
}

sub create_zone ($self, $zone_data) {
  my $url = $self->api_url . '/servers/localhost/zones';
  my $payload = {
    name       => $zone_data->{name},
    kind       => $zone_data->{kind} // 'Master',
    'soa-edit' => 'DEFAULT',
  };
  my $tx = $self->ua->post($url, $self->_headers, json => $payload);
  my $res = $tx->result;
  return ($res && $res->is_success)
    ? { success => 1 }
    : { success => 0, error => $res ? $res->message : "No response" };
}

sub update_zone ($self, $zone_id, $zone_data) {
  my $url = $self->api_url . '/servers/localhost/zones/' . $zone_id;
  my $payload = {
    name => $zone_data->{name},
    kind => $zone_data->{kind},
  };
  my $tx = $self->ua->patch($url, $self->_headers, json => $payload);
  my $res = $tx->result;
  return ($res && $res->is_success)
    ? { success => 1 }
    : { success => 0, error => $res ? $res->message : "No response" };
}

sub delete_zone ($self, $zone_id) {
  my $url = $self->api_url . '/servers/localhost/zones/' . $zone_id;
  my $tx = $self->ua->delete($url, $self->_headers);
  my $res = $tx->result;
  return ($res && $res->is_success)
    ? { success => 1 }
    : { success => 0, error => $res ? $res->message : "No response" };
}

### Record methods

sub list_records ($self, $zone_id) {
  my $url = $self->api_url . '/servers/localhost/zones/' . $zone_id . '/records';
  my $tx  = $self->ua->get($url, $self->_headers);
  if (my $res = $tx->result) {
    return $res->is_success ? $res->json : [];
  }
  return [];
}

sub get_record ($self, $zone_id, $record_id) {
  my $url = $self->api_url . '/servers/localhost/zones/' . $zone_id . '/records/' . $record_id;
  my $tx  = $self->ua->get($url, $self->_headers);
  if (my $res = $tx->result) {
    return $res->is_success ? $res->json : undef;
  }
  return undef;
}

sub create_record ($self, $zone_id, $record_data) {
  my $url = $self->api_url . '/servers/localhost/zones/' . $zone_id . '/records';
  my $tx = $self->ua->post($url, $self->_headers, json => $record_data);
  my $res = $tx->result;
  return ($res && $res->is_success)
    ? { success => 1 }
    : { success => 0, error => $res ? $res->message : "No response" };
}

sub update_record ($self, $zone_id, $record_id, $record_data) {
  my $url = $self->api_url . '/servers/localhost/zones/' . $zone_id . '/records/' . $record_id;
  my $tx = $self->ua->patch($url, $self->_headers, json => $record_data);
  my $res = $tx->result;
  return ($res && $res->is_success)
    ? { success => 1 }
    : { success => 0, error => $res ? $res->message : "No response" };
}

sub delete_record ($self, $zone_id, $record_id) {
  my $url = $self->api_url . '/servers/localhost/zones/' . $zone_id . '/records/' . $record_id;
  my $tx = $self->ua->delete($url, $self->_headers);
  my $res = $tx->result;
  return ($res && $res->is_success)
    ? { success => 1 }
    : { success => 0, error => $res ? $res->message : "No response" };
}

1;
