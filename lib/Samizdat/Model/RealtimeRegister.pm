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

# Get API base URL from config
sub api_url ($self) {
  my $env = $self->config->{default_env} // 'production';
  return $self->config->{env}->{$env}->{api} // $self->config->{env}->{production}->{api};
}

# Make API request with authentication
sub _api_request ($self, $method, $endpoint, $data = undef) {
  my $url = $self->api_url() . $endpoint;
  my $api_key = $self->config->{api_key} // '';
  my $tx;

  my $headers = {
    'Authorization' => "ApiKey $api_key",
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

sub getDomains ($self, $params = {}) {
  my $query = Mojo::Parameters->new(%$params)->to_string;
  my $endpoint = 'v2/domains' . ($query ? "?$query" : '');
  return $self->_api_request('GET', $endpoint, undef);
}

sub getDomain ($self, $domain_name) {
  say $domain_name;
  return $self->_api_request('GET', "v2/domains/$domain_name", undef);
}

sub createDomain ($self, $domain_data) {
  return $self->_api_request('POST', 'v2/domains', $domain_data);
}

sub updateDomain ($self, $domain_name, $domain_data) {
  # RTR API uses POST to /v2/domains/{domainName}/update
  # Convert boolean designatedAgent to API enum: NONE, OLD, NEW, BOTH
  if (exists $domain_data->{designatedAgent}) {
    if ($domain_data->{designatedAgent} && $domain_data->{designatedAgent} !~ /^(NONE|OLD|NEW|BOTH)$/) {
      $domain_data->{designatedAgent} = 'BOTH';
    } elsif (!$domain_data->{designatedAgent}) {
      delete $domain_data->{designatedAgent};
    }
  }
  return $self->_api_request('POST', "v2/domains/$domain_name/update", $domain_data);
}

sub deleteDomain ($self, $domain_name) {
  return $self->_api_request('DELETE', "v2/domains/$domain_name", undef);
}

# Contact operations

sub getContacts ($self, $params = {}) {
  my $customer = $self->config->{customer};
  my $query = Mojo::Parameters->new(%$params)->to_string;
  my $endpoint = "v2/customers/$customer/contacts" . ($query ? "?$query" : '');
  return $self->_api_request('GET', $endpoint, undef);
}

sub getContact ($self, $contact_handle) {
  my $customer = $self->config->{customer};
  return $self->_api_request('GET', "v2/customers/$customer/contacts/$contact_handle", undef);
}

sub createContact ($self, $contact_data) {
  my $customer = $self->config->{customer};
  my $handle = $contact_data->{handle} or return { error => 'Handle required' };
  return $self->_api_request('POST', "v2/customers/$customer/contacts/$handle", $contact_data);
}

sub updateContact ($self, $contact_handle, $contact_data) {
  my $customer = $self->config->{customer};
  # RTR API uses POST to /update endpoint (same pattern as domain update)
  # Convert boolean designatedAgent to API enum: NONE, OLD, NEW, BOTH
  # (email change is treated like owner change, requires designatedAgent)
  if (exists $contact_data->{designatedAgent}) {
    if ($contact_data->{designatedAgent} && $contact_data->{designatedAgent} !~ /^(NONE|OLD|NEW|BOTH)$/) {
      $contact_data->{designatedAgent} = 'BOTH';
    } elsif (!$contact_data->{designatedAgent}) {
      delete $contact_data->{designatedAgent};
    }
  }
  return $self->_api_request('POST', "v2/customers/$customer/contacts/$contact_handle/update", $contact_data);
}

sub deleteContact ($self, $contact_handle) {
  my $customer = $self->config->{customer};
  return $self->_api_request('DELETE', "v2/customers/$customer/contacts/$contact_handle", undef);
}

# Pricelist operations

sub getPricelist ($self, $params = {}) {
  my $customer = $self->config->{customer};
  my $currency = $params->{currency} // $self->default_currency;
  return $self->_api_request('GET', "v2/customers/$customer/pricelist?currency=$currency", undef);
}

sub currencies ($self) {
  my $cfg = $self->config->{currency} // ['EUR'];
  return ref $cfg eq 'ARRAY' ? $cfg : [$cfg];
}

sub default_currency ($self) {
  return $self->currencies->[0];
}

# Financial transactions

sub getTransactions ($self, $params = {}) {
  my $query = Mojo::Parameters->new(%$params)->to_string;
  my $endpoint = 'v2/billing/financialtransactions' . ($query ? "?$query" : '');
  return $self->_api_request('GET', $endpoint, undef);
}

sub getTransaction ($self, $id) {
  return $self->_api_request('GET', "v2/billing/financialtransactions/$id", undef);
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

=item getDomains($params)

Get list of domains. Optional params for filtering. Returns array of domains.

=item getDomain($domain_name)

Get details for a specific domain.

=item createDomain($domain_data)

Register a new domain.

=item updateDomain($domain_name, $domain_data)

Update domain information.

=item deleteDomain($domain_name)

Delete/cancel a domain.

=back

=head2 Contact Methods

=over 4

=item getContacts($params)

Get list of contacts. Optional params for filtering. Returns array of contacts.

=item getContact($contact_handle)

Get details for a specific contact.

=item createContact($contact_data)

Create a new contact.

=item updateContact($contact_handle, $contact_data)

Update contact information.

=item deleteContact($contact_handle)

Delete a contact.

=back

=head1 CONFIGURATION

Configure in samizdat.yml:

  manager:
    realtimeregister:
      api_key: your-api-key
      customer: yourcustomerhandle  # Your customer handle
      default_env: production  # production or test
      env:
        production:
          api: https://api.yoursrs.com/
        test:
          api: https://api.yoursrs-ote.com/

=cut
