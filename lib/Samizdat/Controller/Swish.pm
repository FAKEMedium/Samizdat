package Samizdat::Controller::Swish;

use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';

  if ($accept =~ /json/) {
    # Require admin access for JSON
    return unless $self->access({ admin => 1 });

    my $payments = $self->swish->get_recent_payments(limit => 50);
    my $stats = $self->swish->get_payment_stats();

    my $data = {
      success => 1,
      payments => $payments,
      stats => $stats,
    };

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $data, status => 200);
  }

  my $title = $self->app->__('Swish Payments');
  my $web = { title => $title };
  $web->{script} = $self->render_to_string(template => 'swish/index', format => 'js');

  $self->stash(web => $web);
  $self->render(template => 'swish/index');
}

sub callback ($self) {
  my $data = $self->req->json;
  my $source_ip = $self->tx->remote_address;

  unless ($data) {
    $self->app->log->warn('Swish callback received without JSON body');
    return $self->render(text => 'INVALID', status => 400);
  }

  if ($self->app->mode eq 'development') {
    $self->app->log->debug("Swish callback received: " . $self->dumper($data));
  }

  my $result = $self->swish->process_callback($data, $source_ip);

  if ($result && $result->{processed}) {
    $self->app->log->info("Swish callback processed: $result->{status} - $result->{instruction_id}");
    return $self->render(text => 'OK', status => 200);
  }
  else {
    $self->app->log->error("Swish callback processing failed");
    return $self->render(text => 'ERROR', status => 400);
  }
}

sub success ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';

  if ($accept =~ /json/) {
    my $data = { success => 1 };
    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $data, status => 200);
  }

  my $title = $self->app->__('Payment Successful');
  my $web = { title => $title };
  $web->{script} = $self->render_to_string(template => 'swish/success/index', format => 'js');

  $self->stash(web => $web);
  $self->render(template => 'swish/success/index');
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
  $web->{script} = $self->render_to_string(template => 'swish/cancel/index', format => 'js');

  $self->stash(web => $web);
  $self->render(template => 'swish/cancel/index');
}

sub swish_config ($self) {
  my $config = $self->swish->config;
  my $env = $config->{default_env} || 'test';
  my $env_config = $self->swish->get_env_config();

  my $data = {
    currency => $config->{currency} || 'SEK',
    env => $env,
    payee_alias => $env_config->{payee_alias},
  };

  $self->tx->res->headers->content_type('application/json; charset=UTF-8');
  return $self->render(json => $data, status => 200);
}

sub create_payment ($self) {
  my $params = $self->req->json;

  unless ($params && $params->{amount}) {
    return $self->render(json => { error => 'Amount required' }, status => 400);
  }

  # Build callback URL: request param > config > url_for fallback
  my $env_config = $self->swish->get_env_config();
  my $callback_url = $params->{callback_url} ||
    $env_config->{callback_url} ||
    $self->url_for('Swish.callback')->to_abs->to_string;

  my $payment = $self->swish->create_payment(
    amount => $params->{amount},
    customerid => $params->{customerid},
    payer_alias => $params->{payer_alias},
    message => $params->{message},
    reference => $params->{reference},
    callback_url => $callback_url,
    custom_data => $params->{custom_data},
  );

  if ($payment && !$payment->{error}) {
    $self->app->log->info("Swish payment created: $payment->{instruction_id} ($payment->{flow_type})");
    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $payment, status => 201);
  }
  else {
    $self->app->log->error("Failed to create Swish payment: " .
      ($payment->{error_message} // 'Unknown error'));
    return $self->render(json => $payment, status => $payment->{status_code} || 500);
  }
}

sub get_payment ($self) {
  my $instruction_id = $self->param('id');

  unless ($instruction_id) {
    return $self->render(json => { error => 'Payment ID required' }, status => 400);
  }

  # Try local database first
  my $payment = $self->swish->get_payment_by_instruction_id($instruction_id);

  if ($payment) {
    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $payment, status => 200);
  }

  # Fall back to Swish API
  my $remote_payment = $self->swish->get_payment($instruction_id);

  if ($remote_payment) {
    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $remote_payment, status => 200);
  }

  return $self->render(json => { error => 'Payment not found' }, status => 404);
}

sub qr ($self) {
  my $payee = $self->param('payee') || '';
  my $amount = $self->param('amount') || 0;
  my $message = $self->param('message') || '';

  my $svg = $self->swish_qr_svg(
    payee => $payee,
    amount => $amount,
    message => $message,
  );

  if ($svg) {
    $self->res->headers->content_type('image/svg+xml');
    return $self->render(text => $svg, format => 'svg');
  }
  else {
    return $self->render(text => '', status => 500);
  }
}

sub create_refund ($self) {
  my $params = $self->req->json;

  unless ($params && $params->{original_payment_reference}) {
    return $self->render(json => { error => 'Original payment reference required' }, status => 400);
  }

  unless ($params->{amount}) {
    return $self->render(json => { error => 'Amount required' }, status => 400);
  }

  my $env_config = $self->swish->get_env_config();
  my $callback_url = $params->{callback_url} ||
    $env_config->{callback_url} ||
    $self->url_for('Swish.callback')->to_abs->to_string;

  my $refund = $self->swish->create_refund(
    original_payment_reference => $params->{original_payment_reference},
    amount => $params->{amount},
    message => $params->{message},
    reference => $params->{reference},
    callback_url => $callback_url,
  );

  if ($refund && !$refund->{error}) {
    $self->app->log->info("Swish refund created: $refund->{instruction_id}");
    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $refund, status => 201);
  }
  else {
    $self->app->log->error("Failed to create Swish refund: " .
      ($refund->{error_message} // 'Unknown error'));
    return $self->render(json => $refund, status => $refund->{status_code} || 500);
  }
}

1;

=head1 NAME

Samizdat::Controller::Swish - Swish payment controller

=head1 SYNOPSIS

  # Routes are set up by the plugin
  $r->home('/swish/callback')->to('swish#callback');
  $r->home('/swish/success')->to('swish#success');
  $r->home('/swish/cancel')->to('swish#cancel');

=head1 DESCRIPTION

This controller handles Swish payment callbacks and REST API endpoints,
processing payment status updates through the model.

=head1 METHODS

=head2 index

Displays the Swish payments panel showing recent transactions and statistics.
Returns JSON data when Accept header is application/json, or renders HTML page.

=head2 callback

Processes incoming callback requests from Swish with payment status updates.

=head2 success

Handles the return URL when a payment is successful.

=head2 cancel

Handles the return URL when a payment is cancelled.

=head2 swish_config

Returns Swish configuration for frontend (currency, environment).
Named swish_config to avoid collision with inherited Mojolicious::Controller::config method.

=head2 create_payment

Create a new Swish payment request. Accepts JSON body with:
- amount (required): Amount in öre (smallest currency unit)
- customerid (optional): Link to customer.customers
- payer_alias (optional): Phone number for e-commerce flow
- message (optional): Payment message (max 50 chars)
- reference (optional): Merchant reference

=head2 get_payment

Get payment status by instruction ID.

=head2 create_refund

Create a refund for an existing payment. Accepts JSON body with:
- original_payment_reference (required): Payment reference to refund
- amount (required): Refund amount in öre
- message (optional): Refund message

=cut
