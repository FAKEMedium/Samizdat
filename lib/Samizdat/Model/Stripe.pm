package Samizdat::Model::Stripe;

use Mojo::Base -base, -signatures;
use Mojo::UserAgent;
use Mojo::JSON qw(encode_json decode_json);
use Mojo::URL;

has 'config';
has 'redis';
has 'pg';
has 'ua' => sub { Mojo::UserAgent->new->connect_timeout(30)->request_timeout(60) };

=head1 NAME

Samizdat::Model::Stripe - Stripe payment integration model

=head1 SYNOPSIS

  my $stripe = Samizdat::Model::Stripe->new(
    config => $app->config->{manager}->{stripe},
    pg     => $app->pg,
  );

  # Create a checkout session
  my $session = $stripe->create_checkout_session(
    amount => 10000,
    currency => 'sek',
    success_url => 'https://example.com/stripe/success',
    cancel_url => 'https://example.com/stripe/cancel',
  );

  # Create a payment intent for embedded components
  my $intent = $stripe->create_payment_intent(
    amount => 10000,
    currency => 'sek',
  );

=head1 DESCRIPTION

This model provides Stripe payment integration using the Stripe API.
It supports embedded components (Payment Element) and Checkout Sessions.

=cut

# API base URL
sub _api_url ($self) {
  return 'https://api.stripe.com/v1';
}

# Get secret key from config
sub _secret_key ($self) {
  my $env = $self->config->{default_env} || 'test';
  return $self->config->{env}->{$env}->{secret_key};
}

# Get publishable key for frontend
sub publishable_key ($self) {
  my $env = $self->config->{default_env} || 'test';
  return $self->config->{env}->{$env}->{publishable_key};
}

# Make API request
sub _request ($self, $method, $endpoint, $params = {}) {
  my $url = $self->_api_url . $endpoint;
  my $secret_key = $self->_secret_key;

  unless ($secret_key) {
    return { error => 1, error_message => 'Stripe secret key not configured' };
  }

  # Build request with Basic Auth (secret key as username, no password)
  my $tx;
  my $headers = {
    'Authorization' => 'Basic ' . _base64_encode($secret_key . ':'),
    'Content-Type'  => 'application/x-www-form-urlencoded',
  };

  if ($method eq 'GET') {
    my $query_url = Mojo::URL->new($url);
    $query_url->query($params) if %$params;
    $tx = $self->ua->get($query_url, $headers);
  } elsif ($method eq 'POST') {
    $tx = $self->ua->post($url, $headers, form => $params);
  } elsif ($method eq 'DELETE') {
    $tx = $self->ua->delete($url, $headers);
  }

  my $res = $tx->result;

  if ($res->is_success) {
    return decode_json($res->body);
  } else {
    my $error = eval { decode_json($res->body) } || {};
    return {
      error => 1,
      error_code => $error->{error}->{code} || $res->code,
      error_message => $error->{error}->{message} || $res->message,
      status_code => $res->code,
    };
  }
}

# Simple base64 encoding
sub _base64_encode ($str) {
  require MIME::Base64;
  return MIME::Base64::encode_base64($str, '');
}

=head2 create_payment_intent

Create a PaymentIntent for use with embedded Payment Element.

  my $intent = $stripe->create_payment_intent(
    amount => 10000,          # In smallest currency unit
    currency => 'sek',
    customerid => $cust_id,   # Optional: link to local customer
    customer_email => $email, # Optional
    description => 'Order',   # Optional
    metadata => { ... },      # Optional
  );

Returns hashref with client_secret for frontend.

=cut

sub create_payment_intent ($self, %params) {
  my $amount = $params{amount} or return { error => 1, error_message => 'Amount required' };
  my $currency = $params{currency} || $self->config->{currency} || 'SEK';

  my $api_params = {
    amount => $amount,
    currency => lc($currency),
    'automatic_payment_methods[enabled]' => 'true',
  };

  # Optional parameters
  $api_params->{description} = $params{description} if $params{description};
  $api_params->{receipt_email} = $params{customer_email} if $params{customer_email};

  # Metadata
  if ($params{metadata}) {
    for my $key (keys %{$params{metadata}}) {
      $api_params->{"metadata[$key]"} = $params{metadata}->{$key};
    }
  }
  $api_params->{'metadata[customerid]'} = $params{customerid} if $params{customerid};

  my $result = $self->_request('POST', '/payment_intents', $api_params);

  if ($result->{id}) {
    # Store in database
    $self->_store_payment($result, %params);

    return {
      payment_intent_id => $result->{id},
      client_secret => $result->{client_secret},
      amount => $result->{amount},
      currency => $result->{currency},
      status => $result->{status},
    };
  }

  return $result;
}

=head2 create_checkout_session

Create a Stripe Checkout Session for redirect-based checkout.

  my $session = $stripe->create_checkout_session(
    amount => 10000,
    currency => 'sek',
    success_url => 'https://...',
    cancel_url => 'https://...',
    line_items => [...],      # Optional: custom line items
  );

=cut

sub create_checkout_session ($self, %params) {
  my $success_url = $params{success_url} or return { error => 1, error_message => 'success_url required' };
  my $cancel_url = $params{cancel_url} or return { error => 1, error_message => 'cancel_url required' };

  my $api_params = {
    mode => 'payment',
    success_url => $success_url . '?session_id={CHECKOUT_SESSION_ID}',
    cancel_url => $cancel_url,
  };

  # Line items
  if ($params{line_items}) {
    my $i = 0;
    for my $item (@{$params{line_items}}) {
      $api_params->{"line_items[$i][price_data][currency]"} = lc($item->{currency} || $self->config->{currency} || 'SEK');
      $api_params->{"line_items[$i][price_data][product_data][name]"} = $item->{name} || 'Payment';
      $api_params->{"line_items[$i][price_data][unit_amount]"} = $item->{amount};
      $api_params->{"line_items[$i][quantity]"} = $item->{quantity} || 1;
      $i++;
    }
  } elsif ($params{amount}) {
    my $currency = $params{currency} || $self->config->{currency} || 'SEK';
    $api_params->{'line_items[0][price_data][currency]'} = lc($currency);
    $api_params->{'line_items[0][price_data][product_data][name]'} = $params{description} || 'Payment';
    $api_params->{'line_items[0][price_data][unit_amount]'} = $params{amount};
    $api_params->{'line_items[0][quantity]'} = 1;
  }

  # Optional customer email
  $api_params->{customer_email} = $params{customer_email} if $params{customer_email};

  # Metadata
  if ($params{metadata}) {
    for my $key (keys %{$params{metadata}}) {
      $api_params->{"metadata[$key]"} = $params{metadata}->{$key};
    }
  }
  $api_params->{'metadata[customerid]'} = $params{customerid} if $params{customerid};

  my $result = $self->_request('POST', '/checkout/sessions', $api_params);

  if ($result->{id}) {
    # Store session
    $self->_store_checkout_session($result, %params);

    return {
      session_id => $result->{id},
      url => $result->{url},
      amount => $params{amount},
      currency => $params{currency},
    };
  }

  return $result;
}

=head2 retrieve_payment_intent

Get payment intent details from Stripe.

=cut

sub retrieve_payment_intent ($self, $payment_intent_id) {
  return $self->_request('GET', "/payment_intents/$payment_intent_id");
}

=head2 retrieve_checkout_session

Get checkout session details from Stripe.

=cut

sub retrieve_checkout_session ($self, $session_id) {
  return $self->_request('GET', "/checkout/sessions/$session_id");
}

=head2 create_refund

Create a refund for a payment.

  my $refund = $stripe->create_refund(
    payment_intent_id => 'pi_xxx',
    amount => 5000,           # Optional: partial refund
    reason => 'requested_by_customer',
  );

=cut

sub create_refund ($self, %params) {
  my $payment_intent = $params{payment_intent_id}
    or return { error => 1, error_message => 'payment_intent_id required' };

  my $api_params = {
    payment_intent => $payment_intent,
  };

  $api_params->{amount} = $params{amount} if $params{amount};
  $api_params->{reason} = $params{reason} if $params{reason};

  my $result = $self->_request('POST', '/refunds', $api_params);

  if ($result->{id}) {
    $self->_store_refund($result, %params);
  }

  return $result;
}

=head2 construct_webhook_event

Verify and construct webhook event from payload and signature.

=cut

sub verify_webhook ($self, $payload, $signature) {
  my $webhook_secret = $self->config->{webhook_secret};

  unless ($webhook_secret) {
    warn "Stripe webhook secret not configured";
    return undef;
  }

  # Parse signature header
  my %sig_parts;
  for my $part (split /,/, $signature) {
    my ($key, $value) = split /=/, $part, 2;
    $sig_parts{$key} = $value;
  }

  my $timestamp = $sig_parts{t};
  my $expected_sig = $sig_parts{v1};

  unless ($timestamp && $expected_sig) {
    warn "Invalid Stripe signature format";
    return undef;
  }

  # Verify timestamp (within 5 minutes)
  if (abs(time() - $timestamp) > 300) {
    warn "Stripe webhook timestamp too old";
    return undef;
  }

  # Compute expected signature
  require Digest::SHA;
  my $signed_payload = "$timestamp.$payload";
  my $computed_sig = Digest::SHA::hmac_sha256_hex($signed_payload, $webhook_secret);

  # Constant-time comparison
  unless (_secure_compare($expected_sig, $computed_sig)) {
    warn "Stripe webhook signature mismatch";
    return undef;
  }

  return decode_json($payload);
}

sub _secure_compare ($a, $b) {
  return 0 unless length($a) == length($b);
  my $result = 0;
  for my $i (0 .. length($a) - 1) {
    $result |= ord(substr($a, $i, 1)) ^ ord(substr($b, $i, 1));
  }
  return $result == 0;
}

=head2 process_webhook

Process a webhook event and update payment status.

=cut

sub process_webhook ($self, $event) {
  return { error => 1, error_message => 'Invalid event' } unless $event && $event->{type};

  my $event_type = $event->{type};
  my $data = $event->{data}->{object};

  # Log webhook
  $self->_store_webhook($event);

  # Handle different event types
  if ($event_type eq 'payment_intent.succeeded') {
    $self->_update_payment_status($data->{id}, 'succeeded', $event);
    return { processed => 1, status => 'succeeded', payment_intent_id => $data->{id} };
  }
  elsif ($event_type eq 'payment_intent.payment_failed') {
    $self->_update_payment_status($data->{id}, 'failed', $event);
    return { processed => 1, status => 'failed', payment_intent_id => $data->{id} };
  }
  elsif ($event_type eq 'payment_intent.canceled') {
    $self->_update_payment_status($data->{id}, 'canceled', $event);
    return { processed => 1, status => 'canceled', payment_intent_id => $data->{id} };
  }
  elsif ($event_type eq 'checkout.session.completed') {
    $self->_update_checkout_session($data->{id}, $data);
    return { processed => 1, status => 'completed', session_id => $data->{id} };
  }
  elsif ($event_type eq 'charge.refunded') {
    return { processed => 1, status => 'refunded' };
  }

  # Event type not handled but acknowledged
  return { processed => 1, status => 'ignored', event_type => $event_type };
}

=head2 get_payment_by_intent_id

Get local payment record by PaymentIntent ID.

=cut

sub get_payment_by_intent_id ($self, $payment_intent_id) {
  return unless $self->pg;

  return $self->pg->db->select(
    'stripe.payments',
    '*',
    { payment_intent_id => $payment_intent_id }
  )->hash;
}

=head2 get_recent_payments

Get recent payments for the manager panel.

=cut

sub get_recent_payments ($self, %params) {
  return [] unless $self->pg;

  my $limit = $params{limit} || 50;
  my $offset = $params{offset} || 0;

  return $self->pg->db->query(
    'SELECT * FROM stripe.payments
     ORDER BY created_at DESC
     LIMIT ? OFFSET ?',
    $limit, $offset
  )->hashes->to_array;
}

=head2 get_payment_stats

Get payment statistics for the manager panel.

=cut

sub get_payment_stats ($self) {
  return {} unless $self->pg;

  my $stats = {};

  # Succeeded payments
  my $succeeded = $self->pg->db->query(
    'SELECT COUNT(*) as count, COALESCE(SUM(amount), 0) as total
     FROM stripe.payments WHERE status = ?',
    'succeeded'
  )->hash;
  $stats->{count_succeeded} = $succeeded->{count} || 0;
  $stats->{total_succeeded} = $succeeded->{total} || 0;

  # Pending payments
  my $pending = $self->pg->db->query(
    'SELECT COUNT(*) as count, COALESCE(SUM(amount), 0) as total
     FROM stripe.payments WHERE status IN (?, ?)',
    'created', 'pending'
  )->hash;
  $stats->{count_pending} = $pending->{count} || 0;
  $stats->{total_pending} = $pending->{total} || 0;

  # Failed payments
  my $failed = $self->pg->db->query(
    'SELECT COUNT(*) as count, COALESCE(SUM(amount), 0) as total
     FROM stripe.payments WHERE status = ?',
    'failed'
  )->hash;
  $stats->{count_failed} = $failed->{count} || 0;
  $stats->{total_failed} = $failed->{total} || 0;

  # Canceled payments
  my $canceled = $self->pg->db->query(
    'SELECT COUNT(*) as count, COALESCE(SUM(amount), 0) as total
     FROM stripe.payments WHERE status = ?',
    'canceled'
  )->hash;
  $stats->{count_canceled} = $canceled->{count} || 0;
  $stats->{total_canceled} = $canceled->{total} || 0;

  # Refunds
  my $refunded = $self->pg->db->query(
    'SELECT COUNT(*) as count, COALESCE(SUM(amount), 0) as total
     FROM stripe.refunds WHERE status = ?',
    'succeeded'
  )->hash;
  $stats->{count_refunded} = $refunded->{count} || 0;
  $stats->{total_refunded} = $refunded->{total} || 0;

  # Balance
  $stats->{balance} = ($stats->{total_succeeded} || 0) - ($stats->{total_refunded} || 0);

  return $stats;
}

# Private methods for database operations

sub _store_payment ($self, $intent, %params) {
  return unless $self->pg;

  eval {
    $self->pg->db->insert('stripe.payments', {
      customerid => $params{customerid},
      payment_intent_id => $intent->{id},
      amount => $intent->{amount},
      currency => uc($intent->{currency}),
      status => $intent->{status},
      description => $params{description},
      customer_email => $params{customer_email},
      metadata => $params{metadata} ? encode_json($params{metadata}) : undef,
      created_at => \'NOW()',
      updated_at => \'NOW()',
    });
  };
  warn "Failed to store Stripe payment: $@" if $@;
}

sub _store_checkout_session ($self, $session, %params) {
  return unless $self->pg;

  eval {
    $self->pg->db->insert('stripe.payments', {
      customerid => $params{customerid},
      checkout_session_id => $session->{id},
      payment_intent_id => $session->{payment_intent},
      amount => $params{amount} || 0,
      currency => uc($params{currency} || $self->config->{currency} || 'SEK'),
      status => 'created',
      customer_email => $session->{customer_email},
      metadata => $params{metadata} ? encode_json($params{metadata}) : undef,
      created_at => \'NOW()',
      updated_at => \'NOW()',
    });
  };
  warn "Failed to store Stripe checkout session: $@" if $@;
}

sub _update_payment_status ($self, $payment_intent_id, $status, $event) {
  return unless $self->pg;

  my $data = $event->{data}->{object} || {};

  my $update = {
    status => $status,
    last_webhook_event => $event->{type},
    webhook_data => encode_json($event),
    updated_at => \'NOW()',
  };

  $update->{completed_at} = \'NOW()' if $status eq 'succeeded';
  $update->{error_code} = $data->{last_payment_error}->{code} if $data->{last_payment_error};
  $update->{error_message} = $data->{last_payment_error}->{message} if $data->{last_payment_error};
  $update->{payment_method_type} = $data->{payment_method_types}->[0] if $data->{payment_method_types};

  eval {
    $self->pg->db->update('stripe.payments',
      $update,
      { payment_intent_id => $payment_intent_id }
    );
  };
  warn "Failed to update Stripe payment status: $@" if $@;
}

sub _update_checkout_session ($self, $session_id, $data) {
  return unless $self->pg;

  eval {
    $self->pg->db->update('stripe.payments',
      {
        status => 'succeeded',
        payment_intent_id => $data->{payment_intent},
        stripe_customer_id => $data->{customer},
        customer_email => $data->{customer_email},
        completed_at => \'NOW()',
        updated_at => \'NOW()',
      },
      { checkout_session_id => $session_id }
    );
  };
  warn "Failed to update Stripe checkout session: $@" if $@;
}

sub _store_webhook ($self, $event) {
  return unless $self->pg;

  my $payment_intent_id = $event->{data}->{object}->{id};
  if ($event->{type} =~ /^checkout\.session/) {
    $payment_intent_id = $event->{data}->{object}->{payment_intent};
  }

  eval {
    $self->pg->db->insert('stripe.webhook_log', {
      event_id => $event->{id},
      event_type => $event->{type},
      payment_intent_id => $payment_intent_id,
      event_data => encode_json($event),
      processed => 1,
      created_at => \'NOW()',
    }, { on_conflict => 'DO NOTHING' });
  };
  warn "Failed to store Stripe webhook: $@" if $@;
}

sub _store_refund ($self, $refund, %params) {
  return unless $self->pg;

  eval {
    $self->pg->db->insert('stripe.refunds', {
      stripe_refund_id => $refund->{id},
      payment_intent_id => $refund->{payment_intent},
      amount => $refund->{amount},
      currency => uc($refund->{currency}),
      status => $refund->{status},
      reason => $params{reason},
      created_at => \'NOW()',
      updated_at => \'NOW()',
    });
  };
  warn "Failed to store Stripe refund: $@" if $@;
}

1;

=head1 CONFIGURATION

Configure in samizdat.yml under manager.stripe:

  stripe:
    cardnumber: 19
    dbtype: postgresql
    currency: SEK
    default_env: test
    webhook_secret: whsec_xxx
    env:
      test:
        publishable_key: pk_test_xxx
        secret_key: sk_test_xxx
      production:
        publishable_key: pk_live_xxx
        secret_key: sk_live_xxx

=head1 DATABASE SCHEMA

Run the schema creation:

    psql -U samizdat samizdat < schema/stripe.sql

=head1 SEE ALSO

L<Samizdat::Controller::Stripe>, L<Samizdat::Plugin::Stripe>

Stripe API Documentation: L<https://docs.stripe.com/api>

=cut
