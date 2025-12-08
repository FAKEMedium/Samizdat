package Samizdat::Model::Swish;

use Mojo::Base -base, -signatures;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::URL;
use Data::UUID;

has 'config';
has 'redis';
has 'pg';
has 'ua';
has '_uuid_gen' => sub { Data::UUID->new };

=head1 NAME

Samizdat::Model::Swish - Swish mobile payment integration model

=head1 SYNOPSIS

    my $swish = $c->swish;

    # Create e-commerce payment (phone number provided)
    my $payment = $swish->create_payment(
      amount => 10000,  # 100.00 SEK in öre
      customerid => $customerid,  # Optional: link to customer
      payer_alias => '46701234567',
      message => 'Order #123',
      reference => 'ORDER-123',
      callback_url => 'https://example.com/swish/callback',
    );

    # Create m-commerce payment (QR code / app link)
    my $payment = $swish->create_payment(
      amount => 10000,
      message => 'Order #123',
      reference => 'ORDER-123',
      callback_url => 'https://example.com/swish/callback',
    );

=head1 DESCRIPTION

This model provides Swish mobile payment integration using mTLS certificates.
Supports both e-commerce (phone number) and m-commerce (QR/app) flows.

=head1 METHODS

=cut

sub _build_ua ($self) {
  return $self->ua if $self->ua;

  my $env_config = $self->get_env_config();
  my $cert_config = $env_config->{cert} || {};

  my $ua = Mojo::UserAgent->new;
  $ua->max_redirects(0);
  $ua->request_timeout(30);

  # Configure mTLS client certificates from environment config
  if ($cert_config->{client_cert} && $cert_config->{client_key}) {
    $ua->cert($cert_config->{client_cert});
    $ua->key($cert_config->{client_key});

    if ($cert_config->{ca_cert}) {
      $ua->ca($cert_config->{ca_cert});
    }
  }

  $self->ua($ua);
  return $ua;
}

=head2 get_env_config

Get the current environment configuration (test or production).

    my $env_config = $swish->get_env_config();

Returns a hashref with api URL for the current environment.

=cut

sub get_env_config ($self) {
  my $config = $self->config;
  my $env = $config->{default_env} || 'test';

  return $config->{env}->{$env};
}

=head2 generate_instruction_id

Generate a UUID for payment instruction ID.

    my $uuid = $swish->generate_instruction_id();

=cut

sub generate_instruction_id ($self) {
  return uc($self->_uuid_gen->create_str());
}

=head2 create_payment

Create a Swish payment request.

E-commerce flow (payer_alias provided):
  - Payer receives push notification in Swish app
  - Opens app and confirms payment

M-commerce flow (no payer_alias):
  - Returns payment_request_token
  - Use token to generate QR code or app link

    my $payment = $swish->create_payment(
      amount => 10000,              # Required: amount in öre
      message => 'Order #123',      # Optional: max 50 chars
      reference => 'ORDER-123',     # Optional: merchant reference
      payer_alias => '46701234567', # Optional: for e-commerce
      callback_url => $url,         # Required: callback URL
    );

Returns hashref with payment details or undef on failure.

=cut

sub create_payment ($self, %params) {
  my $ua = $self->_build_ua();
  my $env_config = $self->get_env_config();
  my $api_url = $env_config->{api};

  # Generate instruction ID
  my $instruction_id = $params{instruction_id} || $self->generate_instruction_id();

  # Required fields
  my $amount = $params{amount} or die "amount is required";
  my $callback_url = $params{callback_url} or die "callback_url is required";

  # Payee alias from environment config
  my $payee_alias = $env_config->{payee_alias}
    or die "payee_alias not configured for environment";

  # Determine flow type
  my $flow_type = $params{payer_alias} ? 'ecommerce' : 'mcommerce';

  # Build payment request body
  my $body = {
    payeePaymentReference => $params{reference} || $instruction_id,
    callbackUrl => $callback_url,
    payeeAlias => $payee_alias,
    amount => sprintf("%.2f", $amount / 100),  # Convert öre to SEK
    currency => $self->config->{currency} || 'SEK',
  };

  # Add message if provided (max 50 chars)
  if ($params{message}) {
    $body->{message} = substr($params{message}, 0, 50);
  }

  # Add payer alias for e-commerce
  if ($params{payer_alias}) {
    $body->{payerAlias} = $params{payer_alias};
  }

  # Swish uses PUT to create payment requests
  my $url = "$api_url/paymentrequests/$instruction_id";

  my $tx = $ua->put(
    $url => {
      'Content-Type' => 'application/json'
    } => json => $body
  );

  my $result = $tx->result;

  if ($result->code == 201) {
    # Payment created successfully
    my $location = $result->headers->location;
    my $token = $result->headers->header('PaymentRequestToken');

    my $payment = {
      instruction_id => $instruction_id,
      flow_type => $flow_type,
      amount => $amount,
      status => 'CREATED',
      payee_alias => $payee_alias,
      payee_payment_reference => $body->{payeePaymentReference},
      callback_url => $callback_url,
      location => $location,
    };

    # Add token for m-commerce flow
    if ($token) {
      $payment->{payment_request_token} = $token;
      # Generate Swish app URL
      $payment->{swish_url} = "swish://paymentrequest?token=$token&callbackurl=" .
        Mojo::URL->new($callback_url)->to_abs;
    }

    # Store in database
    $self->_store_payment($payment, %params);

    return $payment;
  }
  else {
    # Handle error response
    my $error = eval { $result->json } || {};
    warn "Swish payment creation failed: " . $result->code . " - " .
      ($error->{errorCode} // $result->message);

    return {
      error => 1,
      status_code => $result->code,
      error_code => $error->{errorCode},
      error_message => $error->{errorMessage} // $result->message,
      additional_info => $error->{additionalInformation},
    };
  }
}

=head2 get_payment

Get payment details by instruction ID.

    my $payment = $swish->get_payment($instruction_id);

=cut

sub get_payment ($self, $instruction_id) {
  my $ua = $self->_build_ua();
  my $env_config = $self->get_env_config();
  my $api_url = $env_config->{api};

  my $tx = $ua->get("$api_url/paymentrequests/$instruction_id");

  if ($tx->result->is_success) {
    return $tx->result->json;
  }
  else {
    warn "Failed to get Swish payment: " . $tx->result->message;
    return undef;
  }
}

=head2 create_refund

Create a Swish refund request.

    my $refund = $swish->create_refund(
      original_payment_reference => 'ABC123',  # Required
      amount => 5000,                          # Required: amount in öre
      message => 'Refund for order',           # Optional
      reference => 'REFUND-123',               # Optional
      callback_url => $url,                    # Required
    );

=cut

sub create_refund ($self, %params) {
  my $ua = $self->_build_ua();
  my $env_config = $self->get_env_config();
  my $api_url = $env_config->{api};

  my $instruction_id = $params{instruction_id} || $self->generate_instruction_id();

  # Required fields
  my $original_ref = $params{original_payment_reference}
    or die "original_payment_reference is required";
  my $amount = $params{amount} or die "amount is required";
  my $callback_url = $params{callback_url} or die "callback_url is required";

  # Payer alias (merchant) from environment config
  my $payer_alias = $env_config->{payee_alias}
    or die "payee_alias not configured for environment";

  my $body = {
    originalPaymentReference => $original_ref,
    callbackUrl => $callback_url,
    payerAlias => $payer_alias,
    amount => sprintf("%.2f", $amount / 100),
    currency => $self->config->{currency} || 'SEK',
  };

  if ($params{message}) {
    $body->{message} = substr($params{message}, 0, 50);
  }

  if ($params{reference}) {
    $body->{payerPaymentReference} = $params{reference};
  }

  my $tx = $ua->put(
    "$api_url/refunds/$instruction_id" => {
      'Content-Type' => 'application/json'
    } => json => $body
  );

  my $result = $tx->result;

  if ($result->code == 201) {
    my $refund = {
      instruction_id => $instruction_id,
      original_payment_reference => $original_ref,
      amount => $amount,
      status => 'CREATED',
      payer_alias => $payer_alias,
    };

    $self->_store_refund($refund, %params);

    return $refund;
  }
  else {
    my $error = eval { $result->json } || {};
    warn "Swish refund creation failed: " . $result->code;

    return {
      error => 1,
      status_code => $result->code,
      error_code => $error->{errorCode},
      error_message => $error->{errorMessage} // $result->message,
    };
  }
}

=head2 process_callback

Process a Swish callback notification.

    my $result = $swish->process_callback($data, $source_ip);

=cut

sub process_callback ($self, $data, $source_ip = undef) {
  return unless $data;

  my $instruction_id = $data->{instructionUUID} || $data->{id};
  my $status = $data->{status};
  my $payment_reference = $data->{paymentReference};

  # Log callback
  $self->_log_callback($instruction_id, $status, $data, $source_ip);

  # Update payment status
  if ($instruction_id && $status) {
    $self->_update_payment_status($instruction_id, $data);
  }

  return {
    instruction_id => $instruction_id,
    status => $status,
    payment_reference => $payment_reference,
    processed => 1,
  };
}

=head2 get_recent_payments

Get recent payments from database.

    my $payments = $swish->get_recent_payments(limit => 50);

=cut

sub get_recent_payments ($self, %params) {
  return [] unless $self->pg;

  my $limit = $params{limit} || 50;
  my $offset = $params{offset} || 0;

  my $results = $self->pg->db->query(
    'SELECT * FROM swish.payments
     ORDER BY created_at DESC
     LIMIT ? OFFSET ?',
    $limit, $offset
  )->hashes->to_array;

  return $results;
}

=head2 get_payment_by_instruction_id

Get payment from database by instruction ID.

    my $payment = $swish->get_payment_by_instruction_id($instruction_id);

=cut

sub get_payment_by_instruction_id ($self, $instruction_id) {
  return unless $self->pg;

  return $self->pg->db->select(
    'swish.payments',
    '*',
    { instruction_id => $instruction_id }
  )->hash;
}

=head2 get_payments_by_customer

Get payments for a specific customer.

    my $payments = $swish->get_payments_by_customer($customerid, limit => 50);

=cut

sub get_payments_by_customer ($self, $customerid, %params) {
  return [] unless $self->pg && $customerid;

  my $limit = $params{limit} || 50;
  my $offset = $params{offset} || 0;

  return $self->pg->db->query(
    'SELECT * FROM swish.payments
     WHERE customerid = ?
     ORDER BY created_at DESC
     LIMIT ? OFFSET ?',
    $customerid, $limit, $offset
  )->hashes->to_array;
}

=head2 get_payment_stats

Get payment statistics.

    my $stats = $swish->get_payment_stats();

=cut

sub get_payment_stats ($self) {
  return {} unless $self->pg;

  my $stats = {};

  # Get paid payments stats
  my $paid = $self->pg->db->query(
    'SELECT COUNT(*) as count, COALESCE(SUM(amount), 0) as total
     FROM swish.payments WHERE status = ?',
    'PAID'
  )->hash;
  $stats->{count_paid} = $paid->{count} || 0;
  $stats->{total_paid} = $paid->{total} || 0;

  # Get pending payments stats
  my $pending = $self->pg->db->query(
    'SELECT COUNT(*) as count, COALESCE(SUM(amount), 0) as total
     FROM swish.payments WHERE status = ?',
    'CREATED'
  )->hash;
  $stats->{count_pending} = $pending->{count} || 0;
  $stats->{total_pending} = $pending->{total} || 0;

  # Get declined stats
  my $declined = $self->pg->db->query(
    'SELECT COUNT(*) as count, COALESCE(SUM(amount), 0) as total
     FROM swish.payments WHERE status = ?',
    'DECLINED'
  )->hash;
  $stats->{count_declined} = $declined->{count} || 0;
  $stats->{total_declined} = $declined->{total} || 0;

  # Get error stats
  my $error = $self->pg->db->query(
    'SELECT COUNT(*) as count, COALESCE(SUM(amount), 0) as total
     FROM swish.payments WHERE status = ?',
    'ERROR'
  )->hash;
  $stats->{count_error} = $error->{count} || 0;
  $stats->{total_error} = $error->{total} || 0;

  return $stats;
}

# Private methods

sub _store_payment ($self, $payment, %params) {
  return unless $self->pg;

  eval {
    $self->pg->db->insert('swish.payments', {
      customerid => $params{customerid},
      instruction_id => $payment->{instruction_id},
      amount => $payment->{amount},
      currency => $self->config->{currency} || 'SEK',
      message => $params{message},
      status => $payment->{status},
      payee_alias => $payment->{payee_alias},
      payee_payment_reference => $payment->{payee_payment_reference},
      payer_alias => $params{payer_alias},
      flow_type => $payment->{flow_type},
      payment_request_token => $payment->{payment_request_token},
      callback_url => $payment->{callback_url},
      custom_data => $params{custom_data} ? encode_json($params{custom_data}) : undef,
    });
  };

  if ($@) {
    warn "Failed to store Swish payment: $@";
  }
}

sub _store_refund ($self, $refund, %params) {
  return unless $self->pg;

  eval {
    $self->pg->db->insert('swish.refunds', {
      instruction_id => $refund->{instruction_id},
      original_payment_reference => $refund->{original_payment_reference},
      amount => $refund->{amount},
      currency => $self->config->{currency} || 'SEK',
      message => $params{message},
      status => $refund->{status},
      payer_alias => $refund->{payer_alias},
      payer_payment_reference => $params{reference},
      callback_url => $params{callback_url},
    });
  };

  if ($@) {
    warn "Failed to store Swish refund: $@";
  }
}

sub _log_callback ($self, $instruction_id, $event_type, $data, $source_ip) {
  return unless $self->pg;

  eval {
    $self->pg->db->insert('swish.callback_log', {
      instruction_id => $instruction_id,
      event_type => $event_type,
      event_data => encode_json($data),
      source_ip => $source_ip,
      processed => 0,
    });
  };

  if ($@) {
    warn "Failed to log Swish callback: $@";
  }
}

sub _update_payment_status ($self, $instruction_id, $data) {
  return unless $self->pg;

  my $update = {
    status => $data->{status},
    updated_at => \'NOW()',
    callback_data => encode_json($data),
  };

  if ($data->{paymentReference}) {
    $update->{payment_reference} = $data->{paymentReference};
  }

  if ($data->{payerAlias}) {
    $update->{payer_alias} = $data->{payerAlias};
  }

  if ($data->{payerName}) {
    $update->{payer_name} = $data->{payerName};
  }

  if ($data->{errorCode}) {
    $update->{error_code} = $data->{errorCode};
    $update->{error_message} = $data->{errorMessage};
  }

  if ($data->{status} eq 'PAID') {
    $update->{paid_at} = $data->{datePaid} || \'NOW()';
  }

  eval {
    $self->pg->db->update(
      'swish.payments',
      $update,
      { instruction_id => $instruction_id }
    );

    # Mark callback as processed
    $self->pg->db->update(
      'swish.callback_log',
      { processed => 1 },
      { instruction_id => $instruction_id, processed => 0 }
    );
  };

  if ($@) {
    warn "Failed to update Swish payment status: $@";
  }
}

1;

=head1 CONFIGURATION

The Swish model requires configuration in samizdat.yml:

    swish:
      cardnumber: 18
      dbtype: postgresql
      currency: SEK
      default_env: test  # or production
      env:
        test:
          api: https://mss.cpc.getswish.net/swish-cpcapi/api/v2
          payee_alias: '1234679304'
          cert:
            client_cert: src/swish/Swish_Merchant_TestCertificate_1234679304.pem
            client_key: src/swish/Swish_Merchant_TestCertificate_1234679304.key
            ca_cert: src/swish/Swish_TLS_RootCA.pem
        production:
          api: https://cpc.getswish.net/swish-cpcapi/api/v2
          payee_alias: 'YOUR_SWISH_NUMBER'
          cert:
            client_cert: /path/to/production_client.pem
            client_key: /path/to/production_client.key
            ca_cert: /path/to/production_ca.pem

=head1 GETTING CERTIFICATES

Test certificates are available from:
https://developer.swish.nu/documentation/getting-started/swish-commerce-api

Production certificates must be ordered from Swish Certificate Management.

=head1 SEE ALSO

L<Samizdat::Controller::Swish>, L<Samizdat::Plugin::Swish>

=head1 AUTHOR

Samizdat Development Team

=cut
