package Samizdat::Model::Nets;

use Mojo::Base -base, -signatures;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::URL;
use Net::IP;

has 'config';
has 'redis';
has 'pg';
has 'ua' => sub {
  my $ua = Mojo::UserAgent->new;
  $ua->max_redirects(5);
  $ua->request_timeout(30);
  return $ua;
};

=head1 NAME

Samizdat::Model::Nets - Nets Easy Checkout integration model

=head1 SYNOPSIS

    my $nets = $c->nets;

    # Create a payment
    my $payment = $nets->create_payment(
      amount => 10000,           # 100.00 SEK (in øre)
      currency => 'SEK',
      reference => 'ORDER-123',
      items => [
        { name => 'Product A', quantity => 1, unit_price => 10000 }
      ],
      return_url => 'https://example.com/nets/success',
      webhook_url => 'https://example.com/nets/webhook'
    );

    # Get payment status
    my $status = $nets->get_payment($payment_id);

    # Charge a payment
    my $charged = $nets->charge_payment($payment_id, amount => 10000);

    # Refund a payment
    my $refund = $nets->refund_payment($payment_id, amount => 5000);

=head1 DESCRIPTION

This model provides Nets Easy Checkout integration functionality using the REST API v1.

=head1 METHODS

=head2 get_env_config

Get the current environment configuration (test or production).

    my $env_config = $nets->get_env_config();

Returns a hashref with api, api_key, checkoutjs, and webhook config.

=cut

sub get_env_config ($self) {
  my $config = $self->config;
  my $env = $config->{default_env} || 'test';

  return $config->{env}->{$env};
}

=head2 create_payment

Create a new payment session with Nets Easy Checkout.

    my $payment = $nets->create_payment(
      amount => 10000,               # Required: amount in smallest unit (øre)
      currency => 'SEK',             # Optional: defaults to SEK
      reference => 'ORDER-123',      # Optional: merchant reference
      items => \@items,              # Required: array of order items
      customer => \%customer,        # Optional: customer info
      return_url => $url,            # Required: where to redirect after payment
      webhook_url => $url,           # Optional: webhook notification URL
      custom_data => \%data          # Optional: custom merchant data
    );

Returns hashref with payment_id, checkout_url, etc., or undef on failure.

=cut

sub create_payment ($self, %params) {
  my $env_config = $self->get_env_config();
  my $api_url = $env_config->{api};
  my $api_key = $env_config->{api_key};

  # Required parameters
  my $amount = $params{amount} or die "amount is required";
  my $items = $params{items} or die "items array is required";
  my $return_url = $params{return_url} or die "return_url is required";

  # Optional parameters with defaults
  my $currency = $params{currency} || $self->config->{currency} || 'SEK';
  my $reference = $params{reference} || sprintf('NETS-%d', time());

  # Build order payload
  my $order = {
    items => $items,
    amount => $amount,
    currency => $currency,
    reference => $reference
  };

  # Build checkout configuration
  my $checkout = {
    url => $return_url,
    termsUrl => $params{terms_url} || $return_url,
    integrationType => 'HostedPaymentPage',  # or 'EmbeddedCheckout'
  };

  # Add merchant terms URL if provided
  if ($params{merchant_terms_url}) {
    $checkout->{merchantTermsUrl} = $params{merchant_terms_url};
  }

  # Build full payment request
  my $payload = {
    order => $order,
    checkout => $checkout
  };

  # Add webhook notifications if URL provided
  if (my $webhook_url = $params{webhook_url}) {
    $payload->{notifications} = {
      webhooks => [
        {
          eventName => 'payment.created',
          url => $webhook_url,
          authorization => $api_key
        },
        {
          eventName => 'payment.reservation.created',
          url => $webhook_url,
          authorization => $api_key
        },
        {
          eventName => 'payment.charge.created',
          url => $webhook_url,
          authorization => $api_key
        },
        {
          eventName => 'payment.refund.initiated',
          url => $webhook_url,
          authorization => $api_key
        }
      ]
    };
  }

  # Make API request
  my $tx = $self->ua->post(
    "${api_url}v1/payments" => {
      'Content-Type' => 'application/json',
      'Authorization' => $api_key
    } => json => $payload
  );

  unless ($tx->res->is_success) {
    warn "Nets API error: " . $tx->res->body;
    return undef;
  }

  my $response = $tx->res->json;
  my $payment_id = $response->{paymentId};
  my $checkout_url = $response->{hostedPaymentPageUrl};

  # Save to database
  eval {
    $self->pg->db->query(
      'INSERT INTO nets.payments (payment_id, checkout_url, amount, currency, reference, status, order_items, custom_data, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())',
      $payment_id,
      $checkout_url,
      $amount,
      $currency,
      $reference,
      'created',
      encode_json($items),
      $params{custom_data} ? encode_json($params{custom_data}) : undef
    );
  };

  if ($@) {
    warn "Failed to save payment to database: $@";
  }

  return {
    payment_id => $payment_id,
    checkout_url => $checkout_url,
    amount => $amount,
    currency => $currency,
    reference => $reference
  };
}

=head2 get_payment

Retrieve payment details from Nets API.

    my $payment = $nets->get_payment($payment_id);

Returns payment details hashref or undef on failure.

=cut

sub get_payment ($self, $payment_id) {
  my $env_config = $self->get_env_config();
  my $api_url = $env_config->{api};
  my $api_key = $env_config->{api_key};

  my $tx = $self->ua->get(
    "${api_url}v1/payments/${payment_id}" => {
      'Authorization' => $api_key
    }
  );

  unless ($tx->res->is_success) {
    warn "Nets API error: " . $tx->res->body;
    return undef;
  }

  return $tx->res->json;
}

=head2 charge_payment

Charge a reserved payment.

    my $result = $nets->charge_payment($payment_id, amount => 10000);

Returns charge details or undef on failure.

=cut

sub charge_payment ($self, $payment_id, %params) {
  my $env_config = $self->get_env_config();
  my $api_url = $env_config->{api};
  my $api_key = $env_config->{api_key};

  my $amount = $params{amount} or die "amount is required";

  my $payload = {
    amount => $amount
  };

  my $tx = $self->ua->post(
    "${api_url}v1/payments/${payment_id}/charges" => {
      'Content-Type' => 'application/json',
      'Authorization' => $api_key
    } => json => $payload
  );

  unless ($tx->res->is_success) {
    warn "Nets API error: " . $tx->res->body;
    return undef;
  }

  my $response = $tx->res->json;

  # Update database
  eval {
    $self->pg->db->query(
      'UPDATE nets.payments SET status = ?, charged_amount = ?, charged_at = NOW(), updated_at = NOW()
       WHERE payment_id = ?',
      'charged',
      $amount,
      $payment_id
    );
  };

  if ($@) {
    warn "Failed to update payment in database: $@";
  }

  return $response;
}

=head2 refund_payment

Refund a charged payment (full or partial).

    my $refund = $nets->refund_payment($payment_id, amount => 5000, reason => 'Customer request');

Returns refund details or undef on failure.

=cut

sub refund_payment ($self, $payment_id, %params) {
  my $env_config = $self->get_env_config();
  my $api_url = $env_config->{api};
  my $api_key = $env_config->{api_key};

  my $amount = $params{amount} or die "amount is required";
  my $reason = $params{reason} || 'Refund';

  my $payload = {
    amount => $amount
  };

  my $tx = $self->ua->post(
    "${api_url}v1/payments/${payment_id}/refunds" => {
      'Content-Type' => 'application/json',
      'Authorization' => $api_key
    } => json => $payload
  );

  unless ($tx->res->is_success) {
    warn "Nets API error: " . $tx->res->body;
    return undef;
  }

  my $response = $tx->res->json;
  my $refund_id = $response->{refundId};

  # Save refund to database
  eval {
    $self->pg->db->query(
      'INSERT INTO nets.refunds (payment_id, refund_id, amount, reason, status, created_at)
       VALUES (?, ?, ?, ?, ?, NOW())',
      $payment_id,
      $refund_id,
      $amount,
      $reason,
      'completed'
    );

    # Update payment refunded amount
    $self->pg->db->query(
      'UPDATE nets.payments SET refunded_amount = refunded_amount + ?, updated_at = NOW()
       WHERE payment_id = ?',
      $amount,
      $payment_id
    );
  };

  if ($@) {
    warn "Failed to save refund to database: $@";
  }

  return {
    refund_id => $refund_id,
    amount => $amount,
    payment_id => $payment_id
  };
}

=head2 verify_webhook_ip

Verify that a webhook request comes from Nets servers.

    my $is_valid = $nets->verify_webhook_ip($ip_address);

Returns true if IP is from Nets webhook origin CIDR range.

=cut

sub verify_webhook_ip ($self, $ip_address) {
  my $env_config = $self->get_env_config();
  my $allowed_cidr = $env_config->{webhook}->{origin};

  return 0 unless $allowed_cidr && $ip_address;

  eval {
    my $ip = Net::IP->new($ip_address);
    my $range = Net::IP->new($allowed_cidr);

    if ($ip && $range) {
      return $ip->overlaps($range) != $Net::IP::IP_NO_OVERLAP;
    }
  };

  if ($@) {
    warn "IP verification error: $@";
    return 0;
  }

  return 0;
}

=head2 process_webhook

Process incoming webhook notification from Nets.

    my $result = $nets->process_webhook($payload, $source_ip);

Logs webhook, verifies IP, updates payment status, and returns processing result.

=cut

sub process_webhook ($self, $payload, $source_ip) {
  my $event_type = $payload->{event} || $payload->{eventName} || 'unknown';
  my $payment_id = $payload->{data}->{paymentId} || $payload->{paymentId};

  # Verify source IP
  my $verified = $self->verify_webhook_ip($source_ip);

  # Log webhook
  my $log_id;
  eval {
    my $result = $self->pg->db->query(
      'INSERT INTO nets.webhook_log (payment_id, event_type, event_data, source_ip, verified, created_at)
       VALUES (?, ?, ?, ?, ?, NOW())
       RETURNING id',
      $payment_id,
      $event_type,
      encode_json($payload),
      $source_ip,
      $verified
    );
    $log_id = $result->hash->{id};
  };

  if ($@) {
    warn "Failed to log webhook: $@";
    return { success => 0, error => "Failed to log webhook" };
  }

  unless ($verified) {
    warn "Webhook from unverified IP: $source_ip";
    return { success => 0, error => "Unverified source IP" };
  }

  # Process different event types
  my $processing_result = eval {
    if ($event_type =~ /payment\.charge\.created/i || $event_type =~ /reservation\.created/i) {
      # Payment was charged
      $self->pg->db->query(
        'UPDATE nets.payments
         SET status = ?, webhook_data = ?, updated_at = NOW(),
             events = events || ?::jsonb
         WHERE payment_id = ?',
        'charged',
        encode_json($payload),
        encode_json([{event => $event_type, timestamp => time()}]),
        $payment_id
      );
      return 1;
    }
    elsif ($event_type =~ /payment\.created/i) {
      # Payment session created
      $self->pg->db->query(
        'UPDATE nets.payments
         SET webhook_data = ?, updated_at = NOW(),
             events = events || ?::jsonb
         WHERE payment_id = ?',
        encode_json($payload),
        encode_json([{event => $event_type, timestamp => time()}]),
        $payment_id
      );
      return 1;
    }
    elsif ($event_type =~ /refund/i) {
      # Refund event
      $self->pg->db->query(
        'UPDATE nets.payments
         SET webhook_data = ?, updated_at = NOW(),
             events = events || ?::jsonb
         WHERE payment_id = ?',
        encode_json($payload),
        encode_json([{event => $event_type, timestamp => time()}]),
        $payment_id
      );
      return 1;
    }

    # Other events - just log
    return 1;
  };

  # Update webhook log with processing status
  if ($processing_result) {
    $self->pg->db->query(
      'UPDATE nets.webhook_log SET processed = true WHERE id = ?',
      $log_id
    );
    return { success => 1, event_type => $event_type };
  }
  else {
    my $error = $@ || 'Unknown processing error';
    $self->pg->db->query(
      'UPDATE nets.webhook_log SET processed = false, processing_error = ? WHERE id = ?',
      $error,
      $log_id
    );
    return { success => 0, error => $error };
  }
}

=head2 get_payment_from_db

Get payment record from database.

    my $payment = $nets->get_payment_from_db($payment_id);

=cut

sub get_payment_from_db ($self, $payment_id) {
  return $self->pg->db->query(
    'SELECT * FROM nets.payments WHERE payment_id = ?',
    $payment_id
  )->hash;
}

=head2 get_recent_payments

Get recent payments from database.

    my $payments = $nets->get_recent_payments(limit => 50);

=cut

sub get_recent_payments ($self, %params) {
  my $limit = $params{limit} || 50;
  my $offset = $params{offset} || 0;

  return $self->pg->db->query(
    'SELECT * FROM nets.payments ORDER BY created_at DESC LIMIT ? OFFSET ?',
    $limit,
    $offset
  )->hashes->to_array;
}

=head2 get_payment_statistics

Get payment statistics (total, charged, refunded amounts).

    my $stats = $nets->get_payment_statistics();

=cut

sub get_payment_statistics ($self) {
  return $self->pg->db->query(
    'SELECT
       COUNT(*) as total_payments,
       COUNT(CASE WHEN status = ? THEN 1 END) as charged_payments,
       COALESCE(SUM(charged_amount), 0) as total_charged,
       COALESCE(SUM(refunded_amount), 0) as total_refunded,
       COALESCE(SUM(charged_amount) - SUM(refunded_amount), 0) as net_amount
     FROM nets.payments',
    'charged'
  )->hash;
}

1;

=head1 SEE ALSO

L<Samizdat::Controller::Nets>, L<Samizdat::Plugin::Nets>

=head1 AUTHOR

Samizdat Development Team

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024

=cut
