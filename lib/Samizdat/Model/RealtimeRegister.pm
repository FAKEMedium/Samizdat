package Samizdat::Model::RealtimeRegister;

use Mojo::Base -base, -signatures;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Data::Dumper;

has 'config';
has 'ua' => sub {
  state $ua = Mojo::UserAgent->new->connect_timeout(10)->request_timeout(30);
  return $ua;
};

# Get API base URL (production or test)
sub api_url ($self, $env = 'production') {
  return $self->config->{api}->{$env} // $self->config->{api}->{production};
}

# Make API request with authentication
sub _api_request ($self, $method, $endpoint, $data = undef, $env = 'production') {
  my $url = $self->api_url($env) . $endpoint;
  my $tx;

  my $headers = {
    'Authorization' => 'ApiKey ' . $self->config->{api_key},
    'Content-Type'  => 'application/json',
    'Accept'        => 'application/json',
  };

  if ($method eq 'GET') {
    $tx = $self->ua->get($url => $headers);
  } elsif ($method eq 'POST') {
    $tx = $self->ua->post($url => $headers => json => $data);
  } elsif ($method eq 'PUT') {
    $tx = $self->ua->put($url => $headers => json => $data);
  } elsif ($method eq 'DELETE') {
    $tx = $self->ua->delete($url => $headers);
  } else {
    die "Unsupported HTTP method: $method";
  }

  my $result = $tx->result;

  if ($result->is_error) {
    say "RealtimeRegister API error: " . $result->code . " - " . $result->message;
    say "Response body: " . ($result->body // 'empty');
    return { error => $result->message, code => $result->code };
  }

  return $result->json // {};
}

# Domain operations

sub getDomains ($self, $params = {}, $env = 'production') {
  my $query = Mojo::Parameters->new(%$params)->to_string;
  my $endpoint = 'v2/domains' . ($query ? "?$query" : '');
  return $self->_api_request('GET', $endpoint, undef, $env);
}

sub getDomain ($self, $domain_name, $env = 'production') {
  return $self->_api_request('GET', "v2/domains/$domain_name", undef, $env);
}

sub createDomain ($self, $domain_data, $env = 'production') {
  return $self->_api_request('POST', 'v2/domains', $domain_data, $env);
}

sub updateDomain ($self, $domain_name, $domain_data, $env = 'production') {
  return $self->_api_request('PUT', "v2/domains/$domain_name", $domain_data, $env);
}

sub deleteDomain ($self, $domain_name, $env = 'production') {
  return $self->_api_request('DELETE', "v2/domains/$domain_name", undef, $env);
}

# Contact operations

sub getContacts ($self, $params = {}, $env = 'production') {
  my $query = Mojo::Parameters->new(%$params)->to_string;
  my $endpoint = 'v2/contacts' . ($query ? "?$query" : '');
  return $self->_api_request('GET', $endpoint, undef, $env);
}

sub getContact ($self, $contact_handle, $env = 'production') {
  return $self->_api_request('GET', "v2/contacts/$contact_handle", undef, $env);
}

sub createContact ($self, $contact_data, $env = 'production') {
  return $self->_api_request('POST', 'v2/contacts', $contact_data, $env);
}

sub updateContact ($self, $contact_handle, $contact_data, $env = 'production') {
  return $self->_api_request('PUT', "v2/contacts/$contact_handle", $contact_data, $env);
}

sub deleteContact ($self, $contact_handle, $env = 'production') {
  return $self->_api_request('DELETE', "v2/contacts/$contact_handle", undef, $env);
}

1;

=head1 NAME

Samizdat::Model::RealtimeRegister - RealtimeRegister API integration

=head1 DESCRIPTION

This model provides integration with the RealtimeRegister domain registrar API.
It supports domain and contact management operations.

=head1 METHODS

=head2 Domain Methods

=over 4

=item getDomains($params, $env)

Get list of domains. Optional params for filtering. Returns array of domains.

=item getDomain($domain_name, $env)

Get details for a specific domain.

=item createDomain($domain_data, $env)

Register a new domain.

=item updateDomain($domain_name, $domain_data, $env)

Update domain information.

=item deleteDomain($domain_name, $env)

Delete/cancel a domain.

=back

=head2 Contact Methods

=over 4

=item getContacts($params, $env)

Get list of contacts. Optional params for filtering. Returns array of contacts.

=item getContact($contact_handle, $env)

Get details for a specific contact.

=item createContact($contact_data, $env)

Create a new contact.

=item updateContact($contact_handle, $contact_data, $env)

Update contact information.

=item deleteContact($contact_handle, $env)

Delete a contact.

=back

=head1 CONFIGURATION

Configure in samizdat.yml:

  manager:
    realtimeregister:
      api_key: your-api-key
      api:
        production: https://api.yoursrs.com/
        test: https://api.yoursrs-ote.com/

=cut
