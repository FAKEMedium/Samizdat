package Samizdat::Model::PayPal;

use Mojo::Base -base, -signatures;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::URL;
use Mojo::Util qw(b64_encode);
use Digest::SHA qw(hmac_sha256_hex);

has 'config';
has 'redis';
has 'pg';
has 'ua' => sub {
  my $ua = Mojo::UserAgent->new;
  $ua->max_redirects(5);
  $ua->request_timeout(30);
  return $ua;
};
has 'access_token';
has 'token_expires_at';

=head1 NAME

Samizdat::Model::PayPal - PayPal integration model

=head1 SYNOPSIS

    my $paypal = $c->paypal;

    # Generate a payment button
    my $button_html = $paypal->button(
      amount => 99.00,
      description => 'Premium Membership',
      item_number => 'MEM-001',
      return_url => 'https://example.com/paypal/success',
      cancel_url => 'https://example.com/paypal/cancel',
    );

    # Verify IPN notification
    my $verified = $paypal->verify_ipn($tx);

=head1 DESCRIPTION

This model provides PayPal integration functionality including:

=over 4

=item * Payment button generation

=item * IPN (Instant Payment Notification) verification

=item * Payment status tracking

=item * Transaction logging

=back

=head1 METHODS

=head2 button

Generate a PayPal payment button with the specified parameters.

    my $button_html = $paypal->button(
      amount => 99.00,
      description => 'Item description',
      item_number => 'ITEM-001',
      currency => 'USD',        # Optional, defaults to config
      return_url => $url,       # Optional
      cancel_url => $url,       # Optional
      notify_url => $url,       # Optional, defaults to IPN endpoint
    );

Returns HTML for a PayPal payment button.

=cut

sub button ($self, %params) {
  my $config = $self->config;

  # Required parameters
  my $amount = $params{amount} or die "amount is required";
  my $description = $params{description} || 'Payment';

  # Optional parameters with defaults
  my $currency = $params{currency} || $config->{currency} || 'USD';
  my $item_number = $params{item_number} || '';
  my $business = $config->{business} || die "PayPal business email not configured";

  # Payment environment (sandbox or live)
  my $mode = $config->{mode} || 'live';
  my $paypal_url = $mode eq 'sandbox'
    ? 'https://www.sandbox.paypal.com/cgi-bin/webscr'
    : 'https://www.paypal.com/cgi-bin/webscr';

  # URLs
  my $return_url = $params{return_url} || '';
  my $cancel_url = $params{cancel_url} || '';
  my $notify_url = $params{notify_url} || $config->{ipn_url} || '';

  # Custom field for tracking
  my $custom = $params{custom} || '';

  return {
    paypal_url => $paypal_url,
    business => $business,
    amount => $amount,
    description => $description,
    item_number => $item_number,
    currency => $currency,
    return_url => $return_url,
    cancel_url => $cancel_url,
    notify_url => $notify_url,
    custom => $custom,
  };
}

=head2 get_env_config

Get the current environment configuration (sandbox or production).

    my $env_config = $paypal->get_env_config();

Returns a hashref with api, client_id, and secret for the current environment.

=cut

sub get_env_config ($self) {
  my $config = $self->config;
  my $env = $config->{default_env} || 'sandbox';

  return $config->{env}->{$env};
}

=head2 get_access_token

Get an OAuth 2.0 access token using client credentials flow.

    my $token = $paypal->get_access_token();

Returns the access token string, or undef on failure.
Tokens are cached and reused until they expire.

=cut

sub get_access_token ($self) {
  # Check if we have a valid cached token
  if ($self->access_token && $self->token_expires_at) {
    my $now = time();
    if ($now < $self->token_expires_at - 60) {  # Refresh 60 seconds before expiry
      return $self->access_token;
    }
  }

  # Get a new token using OAuth2 client credentials flow
  my $env_config = $self->get_env_config();
  my $api_url = $env_config->{api};
  my $client_id = $env_config->{client_id};
  my $secret = $env_config->{secret};

  unless ($client_id && $secret) {
    warn "PayPal OAuth2 credentials not configured";
    return undef;
  }

  # Build token URL from template if available, otherwise use default
  my $token_url;
  if ($self->config->{oauth2} && $self->config->{oauth2}->{token_url_template}) {
    $token_url = $self->config->{oauth2}->{token_url_template};
    $token_url =~ s/\{api\}/$api_url/g;
  } else {
    $token_url = "$api_url/v1/oauth2/token";
  }

  # Create Basic auth header for client credentials
  my $auth = b64_encode("$client_id:$secret", '');

  # Request token using client credentials grant
  my $tx = $self->ua->post(
    $token_url => {
      'Authorization' => "Basic $auth",
      'Content-Type' => 'application/x-www-form-urlencoded'
    } => form => {
      grant_type => 'client_credentials'
    }
  );

  if ($tx->result->is_success) {
    my $data = $tx->result->json;
    $self->access_token($data->{access_token});

    # Set expiration time (default is 32400 seconds / 9 hours)
    my $expires_in = $data->{expires_in} || 32400;
    $self->token_expires_at(time() + $expires_in);

    return $self->access_token;
  } else {
    warn "Failed to get PayPal access token: " . $tx->result->message;
    return undef;
  }
}

=head2 create_order

Create a PayPal order using the REST API.

    my $order = $paypal->create_order(
      amount => 99.00,
      currency => 'USD',
      description => 'Premium Membership',
      return_url => 'https://example.com/paypal/success',
      cancel_url => 'https://example.com/paypal/cancel',
    );

Returns the order data including approval URL, or undef on failure.

=cut

sub create_order ($self, %params) {
  my $token = $self->get_access_token();
  return undef unless $token;

  my $env_config = $self->get_env_config();
  my $api_url = $env_config->{api};

  my $amount = $params{amount} or die "amount is required";
  my $currency = $params{currency} || $self->config->{currency} || 'USD';
  my $description = $params{description} || 'Payment';
  my $return_url = $params{return_url};
  my $cancel_url = $params{cancel_url};

  # Build order request
  my $order_data = {
    intent => 'CAPTURE',
    purchase_units => [{
      amount => {
        currency_code => $currency,
        value => sprintf("%.2f", $amount)
      },
      description => $description
    }],
    application_context => {
      return_url => $return_url,
      cancel_url => $cancel_url,
      brand_name => $params{brand_name} || 'Samizdat',
      user_action => 'PAY_NOW'
    }
  };

  # Create order
  my $tx = $self->ua->post(
    "$api_url/v2/checkout/orders" => {
      'Authorization' => "Bearer $token",
      'Content-Type' => 'application/json'
    } => json => $order_data
  );

  if ($tx->result->is_success) {
    my $order = $tx->result->json;

    # Extract approval URL
    my $approval_url;
    for my $link (@{$order->{links} || []}) {
      if ($link->{rel} eq 'approve') {
        $approval_url = $link->{href};
        last;
      }
    }

    return {
      id => $order->{id},
      status => $order->{status},
      approval_url => $approval_url,
      order => $order
    };
  } else {
    warn "Failed to create PayPal order: " . $tx->result->message;
    return undef;
  }
}

=head2 capture_order

Capture payment for an approved order.

    my $result = $paypal->capture_order($order_id);

=cut

sub capture_order ($self, $order_id) {
  my $token = $self->get_access_token();
  return undef unless $token;

  my $env_config = $self->get_env_config();
  my $api_url = $env_config->{api};

  my $tx = $self->ua->post(
    "$api_url/v2/checkout/orders/$order_id/capture" => {
      'Authorization' => "Bearer $token",
      'Content-Type' => 'application/json'
    }
  );

  if ($tx->result->is_success) {
    return $tx->result->json;
  } else {
    warn "Failed to capture PayPal order: " . $tx->result->message;
    return undef;
  }
}

=head2 get_order

Get details of an order.

    my $order = $paypal->get_order($order_id);

=cut

sub get_order ($self, $order_id) {
  my $token = $self->get_access_token();
  return undef unless $token;

  my $env_config = $self->get_env_config();
  my $api_url = $env_config->{api};

  my $tx = $self->ua->get(
    "$api_url/v2/checkout/orders/$order_id" => {
      'Authorization' => "Bearer $token"
    }
  );

  if ($tx->result->is_success) {
    return $tx->result->json;
  } else {
    warn "Failed to get PayPal order: " . $tx->result->message;
    return undef;
  }
}

=head2 verify_ipn

Verify an IPN (Instant Payment Notification) by posting back to PayPal.

    my $verified = $paypal->verify_ipn($tx);

Returns true if the IPN is verified, false otherwise.

=cut

sub verify_ipn ($self, $tx) {
  my $body = $tx->req->body;
  my $config = $self->config;

  # Determine PayPal URL based on mode
  my $mode = $config->{mode} || 'live';
  my $paypal_url = $mode eq 'sandbox'
    ? 'https://www.sandbox.paypal.com/cgi-bin/webscr'
    : 'https://www.paypal.com/cgi-bin/webscr';

  # Add cmd=_notify-validate to the original POST data
  my $validation_body = "cmd=_notify-validate&" . $body;

  # Post back to PayPal
  my $verify_tx = $self->ua->post($paypal_url => form => $validation_body);

  if ($verify_tx->result->is_success) {
    my $response = $verify_tx->result->body;
    return $response eq 'VERIFIED';
  }

  return 0;
}

=head2 process_ipn

Process a verified IPN notification.

    my $result = $paypal->process_ipn($params);

Takes the IPN parameters and processes the payment, updating the database
and triggering any necessary actions.

Returns a hashref with processing details.

=cut

sub process_ipn ($self, $params) {
  my $payment_status = $params->{payment_status} || '';
  my $txn_id = $params->{txn_id} || '';
  my $txn_type = $params->{txn_type} || '';
  my $receiver_email = $params->{receiver_email} || '';
  my $payer_email = $params->{payer_email} || '';
  my $amount = $params->{mc_gross} || 0;
  my $currency = $params->{mc_currency} || '';
  my $item_number = $params->{item_number} || '';
  my $custom = $params->{custom} || '';

  # Verify receiver email matches our business email
  my $business = $self->config->{business};
  unless ($receiver_email eq $business) {
    return {
      success => 0,
      error => 'Receiver email mismatch',
      status => $payment_status,
    };
  }

  # Process based on payment status
  my $result = {
    success => 1,
    txn_id => $txn_id,
    txn_type => $txn_type,
    status => $payment_status,
    amount => $amount,
    currency => $currency,
    payer => $payer_email,
    item_number => $item_number,
    custom => $custom,
    action => 'processed',
  };

  # Handle different payment statuses
  if ($payment_status eq 'Completed') {
    $result->{action} = 'completed';
    # Fulfill order, activate service, etc.
  }
  elsif ($payment_status eq 'Pending') {
    $result->{action} = 'pending';
    # Wait for payment to clear
  }
  elsif ($payment_status eq 'Refunded' || $payment_status eq 'Reversed') {
    $result->{action} = 'refunded';
    # Cancel service, mark refund, etc.
  }
  elsif ($payment_status eq 'Failed') {
    $result->{action} = 'failed';
    # Handle failed payment
  }

  return $result;
}

=head2 store_ipn_event

Store an IPN event in the database for audit trail.

    $paypal->store_ipn_event($params);

=cut

sub store_ipn_event ($self, $params) {
  return unless $self->pg;

  eval {
    $self->pg->db->insert('paypal_ipn_log', {
      txn_id => $params->{txn_id} || '',
      txn_type => $params->{txn_type} || '',
      payment_status => $params->{payment_status} || '',
      payer_email => $params->{payer_email} || '',
      receiver_email => $params->{receiver_email} || '',
      amount => $params->{mc_gross} || 0,
      currency => $params->{mc_currency} || '',
      item_number => $params->{item_number} || '',
      custom => $params->{custom} || '',
      raw_data => encode_json($params),
      created_at => \'NOW()',
    });
  };

  if ($@) {
    warn "Failed to store PayPal IPN event: $@";
  }
}

=head2 get_transaction

Retrieve a transaction by transaction ID.

    my $txn = $paypal->get_transaction($txn_id);

=cut

sub get_transaction ($self, $txn_id) {
  return unless $self->pg;

  my $result = $self->pg->db->select(
    'paypal_ipn_log',
    '*',
    {txn_id => $txn_id}
  )->hash;

  return $result;
}

=head2 get_recent_payments

Retrieve recent payment transactions.

    my $payments = $paypal->get_recent_payments(limit => 50);

=cut

sub get_recent_payments ($self, %params) {
  return [] unless $self->pg;

  my $limit = $params{limit} || 50;
  my $offset = $params{offset} || 0;

  my $results = $self->pg->db->query(
    'SELECT * FROM paypal_ipn_log
     ORDER BY created_at DESC
     LIMIT ? OFFSET ?',
    $limit, $offset
  )->hashes->to_array;

  return $results;
}

=head2 get_payment_stats

Get payment statistics including total amount, count by status, etc.

    my $stats = $paypal->get_payment_stats();

Returns a hashref with:
  - total_completed: Total amount of completed payments
  - total_pending: Total amount of pending payments
  - count_completed: Number of completed payments
  - count_pending: Number of pending payments
  - count_refunded: Number of refunded payments
  - count_failed: Number of failed payments

=cut

sub get_payment_stats ($self) {
  return {} unless $self->pg;

  my $stats = {};

  # Get completed payments stats
  my $completed = $self->pg->db->query(
    'SELECT COUNT(*) as count, COALESCE(SUM(amount), 0) as total
     FROM paypal_ipn_log
     WHERE payment_status = ?',
    'Completed'
  )->hash;
  $stats->{count_completed} = $completed->{count} || 0;
  $stats->{total_completed} = $completed->{total} || 0;

  # Get pending payments stats
  my $pending = $self->pg->db->query(
    'SELECT COUNT(*) as count, COALESCE(SUM(amount), 0) as total
     FROM paypal_ipn_log
     WHERE payment_status = ?',
    'Pending'
  )->hash;
  $stats->{count_pending} = $pending->{count} || 0;
  $stats->{total_pending} = $pending->{total} || 0;

  # Get refunded count
  my $refunded = $self->pg->db->query(
    'SELECT COUNT(*) as count
     FROM paypal_ipn_log
     WHERE payment_status IN (?, ?)',
    'Refunded', 'Reversed'
  )->hash;
  $stats->{count_refunded} = $refunded->{count} || 0;

  # Get failed count
  my $failed = $self->pg->db->query(
    'SELECT COUNT(*) as count
     FROM paypal_ipn_log
     WHERE payment_status = ?',
    'Failed'
  )->hash;
  $stats->{count_failed} = $failed->{count} || 0;

  # Calculate balance (completed - refunded amounts)
  my $balance = $self->pg->db->query(
    'SELECT COALESCE(
       (SELECT SUM(amount) FROM paypal_ipn_log WHERE payment_status = ?) -
       (SELECT SUM(amount) FROM paypal_ipn_log WHERE payment_status IN (?, ?))
     , 0) as balance',
    'Completed', 'Refunded', 'Reversed'
  )->hash;
  $stats->{balance} = $balance->{balance} || 0;

  return $stats;
}

1;

=head1 CONFIGURATION

The PayPal model requires configuration in samizdat.yml:

    paypal:
      cardnumber: 16
      dbtype: postgresql
      currency: USD
      default_env: sandbox  # or production
      oauth2:
        token_url_template: '{api}/v1/oauth2/token'
      env:
        sandbox:
          api: https://api-m.sandbox.paypal.com
          client_id: your-sandbox-client-id
          secret: your-sandbox-secret
        production:
          api: https://api-m.paypal.com
          client_id: your-production-client-id
          secret: your-production-secret

The oauth2 section follows the pattern used by other OAuth2-enabled modules
and enables automatic provider registration by Samizdat.pm.

=head1 IPN SETUP

To receive IPN notifications:

1. Log into your PayPal account
2. Go to Profile → My selling tools → Instant payment notifications
3. Click "Update"
4. Set your IPN URL to: https://yoursite.com/paypal/ipn
5. Enable IPN messages

=head1 DATABASE SCHEMA

Create the following table for IPN logging:

    CREATE TABLE paypal_ipn_log (
      id SERIAL PRIMARY KEY,
      txn_id VARCHAR(255) UNIQUE,
      txn_type VARCHAR(100),
      payment_status VARCHAR(50),
      payer_email VARCHAR(255),
      receiver_email VARCHAR(255),
      amount DECIMAL(10,2),
      currency VARCHAR(10),
      item_number VARCHAR(255),
      custom TEXT,
      raw_data JSONB,
      created_at TIMESTAMP DEFAULT NOW()
    );

    CREATE INDEX idx_paypal_txn_id ON paypal_ipn_log(txn_id);
    CREATE INDEX idx_paypal_status ON paypal_ipn_log(payment_status);
    CREATE INDEX idx_paypal_created ON paypal_ipn_log(created_at);

=head1 SEE ALSO

L<Samizdat::Controller::PayPal>, L<Samizdat::Plugin::PayPal>

=head1 AUTHOR

Samizdat Development Team

=cut
