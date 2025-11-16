package Samizdat::Controller::Nets;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::JSON qw(encode_json decode_json);

=head1 NAME

Samizdat::Controller::Nets - Nets Easy Checkout controller

=head1 DESCRIPTION

Handles all Nets payment requests including:
- Payment creation and checkout
- Webhook notifications
- Success/cancel return pages
- Payment status queries
- Refunds (admin only)

=cut

sub index ($self) {
  my $title = $self->app->__('Nets Payments');
  my $web = { title => $title };

  $self->stash(title => $title, web => $web);
  $self->render(template => 'nets/index');
}

=head2 checkout

Create a new payment and redirect to Nets hosted checkout page.

POST /nets/checkout

Required JSON parameters:
  - amount: Amount in smallest currency unit (øre for SEK)
  - items: Array of order items
  - reference: Merchant reference (optional)
  - return_url: Where to return after payment (optional, defaults to /nets/success)

=cut

sub checkout ($self) {
  my $params = $self->req->json || $self->req->params->to_hash;

  my $amount = $params->{amount};
  my $items = $params->{items};
  my $reference = $params->{reference};
  my $currency = $params->{currency} || 'SEK';

  unless ($amount && $items) {
    return $self->render(
      json => { error => $self->app->__('Amount and items are required') },
      status => 400
    );
  }

  # Parse items if it's a JSON string
  if (ref($items) ne 'ARRAY') {
    eval { $items = decode_json($items); };
    if ($@) {
      return $self->render(
        json => { error => $self->app->__('Invalid items format') },
        status => 400
      );
    }
  }

  # Build return and webhook URLs
  my $base_url = $self->req->url->base->to_string;
  my $return_url = $params->{return_url} || $self->url_for('nets_success')->to_abs;
  my $webhook_url = $self->url_for('nets_webhook')->to_abs;

  # Create payment
  my $payment = eval {
    $self->nets->create_payment(
      amount => $amount,
      currency => $currency,
      reference => $reference,
      items => $items,
      return_url => $return_url,
      webhook_url => $webhook_url,
      custom_data => $params->{custom_data}
    );
  };

  if ($@ || !$payment) {
    $self->app->log->error("Failed to create Nets payment: $@");
    return $self->render(
      json => { error => $self->app->__('Failed to create payment') },
      status => 500
    );
  }

  # Return payment details (for AJAX) or redirect (for form submission)
  if ($self->req->headers->accept =~ /json/) {
    return $self->render(
      json => {
        success => 1,
        payment_id => $payment->{payment_id},
        checkout_url => $payment->{checkout_url}
      }
    );
  }
  else {
    return $self->redirect_to($payment->{checkout_url});
  }
}

=head2 success

Success return page after payment completion.

GET /nets/success?paymentId=xxx

=cut

sub success ($self) {
  my $payment_id = $self->param('paymentId');

  unless ($payment_id) {
    return $self->render(
      text => $self->app->__('Missing payment ID'),
      status => 400
    );
  }

  # Get payment details from database
  my $payment = $self->nets->get_payment_from_db($payment_id);

  unless ($payment) {
    return $self->render(
      text => $self->app->__('Payment not found'),
      status => 404
    );
  }

  # Also fetch latest status from Nets API
  my $nets_payment = $self->nets->get_payment($payment_id);

  my $title = $self->app->__('Payment Successful');
  my $web = { title => $title };
  $web->{script} = $self->render_to_string(template => 'nets/success', format => 'js');

  $self->stash(
    title => $title,
    web => $web,
    payment => $payment,
    nets_payment => $nets_payment
  );
  $self->render(template => 'nets/success');
}

=head2 cancel

Cancel/failure return page.

GET /nets/cancel?paymentId=xxx

=cut

sub cancel ($self) {
  my $payment_id = $self->param('paymentId');

  my $title = $self->app->__('Payment Cancelled');
  my $web = { title => $title };

  $self->stash(
    title => $title,
    web => $web,
    payment_id => $payment_id
  );
  $self->render(template => 'nets/cancel');
}

=head2 webhook

Webhook endpoint for Nets payment notifications.

POST /nets/webhook

Accepts payment event notifications from Nets servers.
Verifies source IP and processes payment status updates.

=cut

sub webhook ($self) {
  my $payload = $self->req->json;

  unless ($payload) {
    $self->app->log->error("Nets webhook: No JSON payload");
    return $self->render(json => { error => 'No payload' }, status => 400);
  }

  # Get source IP
  my $source_ip = $self->tx->remote_address;
  if (my $forwarded = $self->req->headers->header('X-Forwarded-For')) {
    # Take first IP if comma-separated
    ($source_ip) = split /\s*,\s*/, $forwarded;
  }

  # Process webhook
  my $result = $self->nets->process_webhook($payload, $source_ip);

  if ($result->{success}) {
    $self->app->log->info("Nets webhook processed: " . ($result->{event_type} || 'unknown'));
    return $self->render(json => { success => 1 }, status => 200);
  }
  else {
    $self->app->log->error("Nets webhook processing failed: " . ($result->{error} || 'unknown'));
    return $self->render(json => { error => $result->{error} }, status => 400);
  }
}

=head2 status

Get payment status (JSON endpoint).

GET /nets/payment/:payment_id/status

=cut

sub status ($self) {
  my $payment_id = $self->param('payment_id');

  my $payment = $self->nets->get_payment_from_db($payment_id);

  unless ($payment) {
    return $self->render(
      json => { error => $self->app->__('Payment not found') },
      status => 404
    );
  }

  return $self->render(json => {
    success => 1,
    payment_id => $payment->{payment_id},
    status => $payment->{status},
    amount => $payment->{amount},
    currency => $payment->{currency},
    reference => $payment->{reference},
    charged_amount => $payment->{charged_amount},
    refunded_amount => $payment->{refunded_amount}
  });
}

=head2 refund

Create a refund for a payment (admin only).

POST /nets/payment/:payment_id/refund

JSON parameters:
  - amount: Refund amount in smallest currency unit
  - reason: Reason for refund (optional)

=cut

sub refund ($self) {
  # Require admin access
  return unless $self->access({ admin => 1 });

  my $payment_id = $self->param('payment_id');
  my $params = $self->req->json;

  my $amount = $params->{amount};
  my $reason = $params->{reason} || 'Refund requested';

  unless ($amount) {
    return $self->render(
      json => { error => $self->app->__('Amount is required') },
      status => 400
    );
  }

  # Get payment to verify it exists and is charged
  my $payment = $self->nets->get_payment_from_db($payment_id);

  unless ($payment) {
    return $self->render(
      json => { error => $self->app->__('Payment not found') },
      status => 404
    );
  }

  unless ($payment->{status} eq 'charged') {
    return $self->render(
      json => { error => $self->app->__('Payment must be charged before refund') },
      status => 400
    );
  }

  # Check refund amount doesn't exceed available
  my $available_for_refund = $payment->{charged_amount} - ($payment->{refunded_amount} || 0);
  if ($amount > $available_for_refund) {
    return $self->render(
      json => { error => $self->app->__('Refund amount exceeds available amount') },
      status => 400
    );
  }

  # Process refund
  my $refund = eval {
    $self->nets->refund_payment($payment_id, amount => $amount, reason => $reason);
  };

  if ($@ || !$refund) {
    $self->app->log->error("Failed to refund Nets payment: $@");
    return $self->render(
      json => { error => $self->app->__('Failed to process refund') },
      status => 500
    );
  }

  return $self->render(json => {
    success => 1,
    refund_id => $refund->{refund_id},
    amount => $refund->{amount},
    payment_id => $payment_id
  });
}

=head2 list_payments

List recent payments (admin only).

GET /nets/payments?limit=50&offset=0

=cut

sub list_payments ($self) {
  # Require admin access for JSON
  if ($self->req->headers->accept =~ /json/) {
    return unless $self->access({ admin => 1 });
  }

  my $limit = $self->param('limit') || 50;
  my $offset = $self->param('offset') || 0;

  my $payments = $self->nets->get_recent_payments(limit => $limit, offset => $offset);
  my $stats = $self->nets->get_payment_statistics();

  if ($self->req->headers->accept =~ /json/) {
    return $self->render(json => {
      success => 1,
      payments => $payments,
      statistics => $stats
    });
  }

  # Render HTML page for manager
  my $title = $self->app->__('Nets Payments');
  my $web = { title => $title };
  $web->{script} = $self->render_to_string(template => 'nets/payments', format => 'js');

  $self->stash(
    title => $title,
    web => $web,
    payments => $payments,
    statistics => $stats
  );
  $self->render(template => 'nets/payments');
}

1;

=head1 SEE ALSO

L<Samizdat::Model::Nets>, L<Samizdat::Plugin::Nets>

=cut
