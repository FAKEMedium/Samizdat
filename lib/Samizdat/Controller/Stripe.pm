package Samizdat::Controller::Stripe;

use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';

  if ($accept =~ /json/) {
    # Require admin access for JSON
    return unless $self->access({ admin => 1 });

    my $payments = $self->stripe->get_recent_payments(limit => 50);
    my $stats = $self->stripe->get_payment_stats();

    my $data = {
      success => 1,
      payments => $payments,
      stats => $stats,
    };

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $data, status => 200);
  }

  my $title = $self->app->__('Stripe Payments');
  my $web = { title => $title };
  $web->{script} = $self->render_to_string(template => 'stripe/index', format => 'js');

  $self->stash(web => $web);
  $self->render(template => 'stripe/index');
}

sub webhook ($self) {
  my $payload = $self->req->body;
  my $signature = $self->req->headers->header('Stripe-Signature') || '';

  unless ($payload) {
    $self->app->log->warn('Stripe webhook received without body');
    return $self->render(text => 'INVALID', status => 400);
  }

  # Verify webhook signature
  my $event = $self->stripe->verify_webhook($payload, $signature);

  unless ($event) {
    $self->app->log->error('Stripe webhook signature verification failed');
    return $self->render(text => 'INVALID SIGNATURE', status => 401);
  }

  if ($self->app->mode eq 'development') {
    $self->app->log->debug("Stripe webhook received: $event->{type}");
  }

  # Process the webhook
  my $result = $self->stripe->process_webhook($event);

  if ($result && $result->{processed}) {
    $self->app->log->info("Stripe webhook processed: $event->{type} - $result->{status}");
    return $self->render(json => { received => \1 }, status => 200);
  }
  else {
    $self->app->log->error("Stripe webhook processing failed");
    return $self->render(text => 'ERROR', status => 400);
  }
}

sub success ($self) {
  my $session_id = $self->param('session_id') || '';
  my $payment_intent = $self->param('payment_intent') || '';

  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';

  if ($accept =~ /json/) {
    my $data = { success => 1 };
    $data->{session_id} = $session_id if $session_id;
    $data->{payment_intent} = $payment_intent if $payment_intent;

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $data, status => 200);
  }

  my $title = $self->app->__('Payment Successful');
  my $web = { title => $title };
  $web->{script} = $self->render_to_string(template => 'stripe/success/index', format => 'js');

  $self->stash(web => $web);
  $self->render(template => 'stripe/success/index');
}

sub cancel ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';

  if ($accept =~ /json/) {
    my $data = { cancelled => 1 };
    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $data, status => 200);
  }

  my $title = $self->app->__('Payment Cancelled');
  my $web = { title => $title };
  $web->{script} = $self->render_to_string(template => 'stripe/cancel/index', format => 'js');

  $self->stash(web => $web);
  $self->render(template => 'stripe/cancel/index');
}

sub stripe_config ($self) {
  # Return Stripe configuration for frontend (publishable key, environment)
  my $publishable_key = $self->stripe->publishable_key;
  my $config = $self->stripe->config;

  my $data = {
    publishable_key => $publishable_key,
    currency => $config->{currency} || 'SEK',
    env => $config->{default_env} || 'test',
  };

  $self->tx->res->headers->content_type('application/json; charset=UTF-8');
  return $self->render(json => $data, status => 200);
}

sub create_payment_intent ($self) {
  my $params = $self->req->json;

  unless ($params && $params->{amount}) {
    return $self->render(json => { error => 'Amount required' }, status => 400);
  }

  my $intent = $self->stripe->create_payment_intent(
    amount => $params->{amount},
    currency => $params->{currency},
    customerid => $params->{customerid},
    customer_email => $params->{customer_email},
    description => $params->{description},
    metadata => $params->{metadata},
  );

  if ($intent && !$intent->{error}) {
    $self->app->log->info("Stripe PaymentIntent created: $intent->{payment_intent_id}");
    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $intent, status => 201);
  }
  else {
    $self->app->log->error("Failed to create Stripe PaymentIntent: " .
      ($intent->{error_message} // 'Unknown error'));
    return $self->render(json => $intent, status => $intent->{status_code} || 500);
  }
}

sub create_checkout_session ($self) {
  my $params = $self->req->json;

  unless ($params && ($params->{amount} || $params->{line_items})) {
    return $self->render(json => { error => 'Amount or line_items required' }, status => 400);
  }

  # Build URLs
  my $success_url = $params->{success_url} ||
    $self->url_for('stripe_success')->to_abs->to_string;
  my $cancel_url = $params->{cancel_url} ||
    $self->url_for('stripe_cancel')->to_abs->to_string;

  my $session = $self->stripe->create_checkout_session(
    amount => $params->{amount},
    currency => $params->{currency},
    customerid => $params->{customerid},
    customer_email => $params->{customer_email},
    description => $params->{description},
    line_items => $params->{line_items},
    metadata => $params->{metadata},
    success_url => $success_url,
    cancel_url => $cancel_url,
  );

  if ($session && !$session->{error}) {
    $self->app->log->info("Stripe Checkout Session created: $session->{session_id}");
    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $session, status => 201);
  }
  else {
    $self->app->log->error("Failed to create Stripe Checkout Session: " .
      ($session->{error_message} // 'Unknown error'));
    return $self->render(json => $session, status => $session->{status_code} || 500);
  }
}

sub get_payment ($self) {
  my $id = $self->param('id');

  unless ($id) {
    return $self->render(json => { error => 'Payment ID required' }, status => 400);
  }

  # Try local database first
  my $payment = $self->stripe->get_payment_by_intent_id($id);

  if ($payment) {
    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $payment, status => 200);
  }

  # Fall back to Stripe API
  my $remote_payment = $self->stripe->retrieve_payment_intent($id);

  if ($remote_payment && !$remote_payment->{error}) {
    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $remote_payment, status => 200);
  }

  return $self->render(json => { error => 'Payment not found' }, status => 404);
}

sub create_refund ($self) {
  my $params = $self->req->json;

  unless ($params && $params->{payment_intent_id}) {
    return $self->render(json => { error => 'payment_intent_id required' }, status => 400);
  }

  my $refund = $self->stripe->create_refund(
    payment_intent_id => $params->{payment_intent_id},
    amount => $params->{amount},
    reason => $params->{reason},
  );

  if ($refund && !$refund->{error}) {
    $self->app->log->info("Stripe refund created: $refund->{id}");
    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $refund, status => 201);
  }
  else {
    $self->app->log->error("Failed to create Stripe refund: " .
      ($refund->{error_message} // 'Unknown error'));
    return $self->render(json => $refund, status => $refund->{status_code} || 500);
  }
}

1;

=head1 NAME

Samizdat::Controller::Stripe - Stripe payment controller

=head1 DESCRIPTION

This controller handles Stripe payment integration including webhooks,
Payment Intents for embedded components, and Checkout Sessions.

=head1 METHODS

=head2 index

Displays the Stripe payments panel showing recent transactions and statistics.
Returns JSON data when Accept header is application/json, or renders HTML page.

=head2 webhook

Processes incoming webhook requests from Stripe with payment status updates.

=head2 success

Handles the return URL when a payment is successful.

=head2 cancel

Handles the return URL when a payment is cancelled.

=head2 stripe_config

Returns Stripe configuration for frontend (publishable key, currency).
Named stripe_config to avoid collision with inherited Mojolicious::Controller::config method.

=head2 create_payment_intent

Create a new PaymentIntent for use with embedded Payment Element.
Returns client_secret for frontend initialization.

=head2 create_checkout_session

Create a Stripe Checkout Session. Returns session URL for redirect.

=head2 get_payment

Get payment status by PaymentIntent ID.

=head2 create_refund

Create a refund for an existing payment.

=cut
