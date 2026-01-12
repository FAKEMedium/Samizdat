package Samizdat::Controller::PayPal;

use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';

  if ($accept =~ /json/) {
    # Require admin access for JSON
    return unless $self->access({ admin => 1 });

    # Return JSON data for the panel
    my $payments = $self->paypal->get_recent_payments(limit => 50);
    my $stats = $self->paypal->get_payment_stats();

    my $data = {
      success => 1,
      payments => $payments,
      stats => $stats,
    };

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $data, status => 200);
  }

  # Render HTML page
  my $title = $self->app->__('PayPal Payments');
  my $web = { title => $title };
  $web->{script} = $self->render_to_string(template => 'paypal/index', format => 'js');

  $self->stash(web => $web);
  $self->render(template => 'paypal/index');
}

sub ipn ($self) {
  my $tx = $self->tx;

  # Verify IPN with PayPal
  unless ($self->paypal->verify_ipn($tx)) {
    $self->app->log->warn('Invalid PayPal IPN notification');
    return $self->render(text => 'INVALID', status => 401);
  }

  # Get IPN parameters
  my $params = $self->req->params->to_hash;

  # Debug logging in development
  if ($self->app->mode eq 'development') {
    $self->app->log->debug("PayPal IPN received: " . $self->dumper($params));
  }

  # Process IPN through model
  my $result = $self->paypal->process_ipn($params);

  if ($result->{success}) {
    $self->app->log->info("PayPal IPN processed: $result->{status} - $result->{txn_id} - action: $result->{action}");

    # Store event for audit trail
    $self->paypal->store_ipn_event($params);

    # Return success to PayPal
    return $self->render(text => 'OK', status => 200);
  } else {
    $self->app->log->error("PayPal IPN processing failed: $result->{error}");
    return $self->render(text => 'ERROR', status => 400);
  }
}


sub success ($self) {
  # Handle successful payment return
  my $txn_id = $self->param('tx') || '';
  my $item_number = $self->param('item_number') || '';
  my $amount = $self->param('amt') || '';

  $self->app->log->info("PayPal payment success: $txn_id");

  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';
  if ($accept =~ /json/) {
    my $data = {
      success => 1,
      txn_id => $txn_id,
      item_number => $item_number,
      amount => $amount,
    };
    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $data, status => 200);
  }

  my $title = $self->app->__('Payment Successful');
  my $web = { title => $title };
  $web->{script} = $self->render_to_string(template => 'paypal/success/index', format => 'js');

  $self->stash(web => $web);
  $self->render(template => 'paypal/success/index');
}


sub cancel ($self) {
  # Handle cancelled payment return
  $self->app->log->info("PayPal payment cancelled");

  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';
  if ($accept =~ /json/) {
    my $data = {
      cancelled => 1,
    };
    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $data, status => 200);
  }

  my $title = $self->app->__('Payment Cancelled');
  my $web = { title => $title };
  $web->{script} = $self->render_to_string(template => 'paypal/cancel/index', format => 'js');

  $self->stash(web => $web);
  $self->render(template => 'paypal/cancel/index');
}

sub paypal_config ($self) {
  # Return PayPal configuration for frontend (client ID, environment)
  # Named paypal_config to avoid collision with inherited Mojolicious::Controller::config method
  my $env_config = $self->paypal->get_env_config();
  my $config_data = $self->paypal->config;

  my $data = {
    client_id => $env_config->{client_id},
    currency => $config_data->{currency} || 'USD',
    env => $config_data->{default_env} || 'sandbox',
  };

  $self->tx->res->headers->content_type('application/json; charset=UTF-8');
  return $self->render(json => $data, status => 200);
}

sub create_order ($self) {
  # Create a PayPal order via REST API
  my $params = $self->req->json;

  unless ($params && $params->{amount}) {
    return $self->render(json => { error => 'Amount required' }, status => 400);
  }

  my $order = $self->paypal->create_order(
    amount => $params->{amount},
    currency => $params->{currency},
    description => $params->{description} || 'Payment',
    return_url => $self->url_for('paypal_success')->to_abs,
    cancel_url => $self->url_for('paypal_cancel')->to_abs,
  );

  if ($order) {
    $self->app->log->info("PayPal order created: $order->{id}");
    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $order, status => 200);
  } else {
    $self->app->log->error("Failed to create PayPal order");
    return $self->render(json => { error => 'Failed to create order' }, status => 500);
  }
}

sub capture_order ($self) {
  # Capture a PayPal order
  my $order_id = $self->param('id');

  unless ($order_id) {
    return $self->render(json => { error => 'Order ID required' }, status => 400);
  }

  my $result = $self->paypal->capture_order($order_id);

  if ($result) {
    $self->app->log->info("PayPal order captured: $order_id");

    # Log to database
    if ($result->{purchase_units} && $result->{purchase_units}->[0]) {
      my $capture = $result->{purchase_units}->[0]->{payments}->{captures}->[0];
      if ($capture) {
        eval {
          $self->paypal->pg->db->insert('paypal.ipn_log', {
            txn_id => $capture->{id},
            txn_type => 'web_accept',
            payment_status => $capture->{status},
            payer_email => $result->{payer}->{email_address} || '',
            receiver_email => '',
            amount => $capture->{amount}->{value},
            currency => $capture->{amount}->{currency_code},
            item_number => '',
            custom => '',
            raw_data => Mojo::JSON::encode_json($result),
            created_at => \'NOW()',
          });
        };
      }
    }

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $result, status => 200);
  } else {
    $self->app->log->error("Failed to capture PayPal order: $order_id");
    return $self->render(json => { error => 'Failed to capture order' }, status => 500);
  }
}

sub transactions ($self) {
  # Fetch live transactions from PayPal Transaction Search API
  return unless $self->access({ admin => 1 });

  my $start_date = $self->param('start_date');
  my $end_date = $self->param('end_date');

  my $result = $self->paypal->fetch_transactions(
    start_date => $start_date,
    end_date => $end_date,
  );

  if ($result->{error}) {
    return $self->render(json => { success => 0, error => $result->{error} }, status => 500);
  }

  $self->tx->res->headers->content_type('application/json; charset=UTF-8');
  return $self->render(json => {
    success => 1,
    transactions => $result->{transactions},
    total_items => $result->{total_items},
    total_pages => $result->{total_pages},
  }, status => 200);
}

1;

=head1 NAME

Samizdat::Controller::PayPal - PayPal IPN and payment controller

=head1 SYNOPSIS

  # Routes are set up by the plugin
  $r->home('/paypal/ipn')->to('pay_pal#ipn');
  $r->home('/paypal/success')->to('pay_pal#success');
  $r->home('/paypal/cancel')->to('pay_pal#cancel');

=head1 DESCRIPTION

This controller handles PayPal Instant Payment Notifications (IPN) and payment
return URLs, verifying IPNs and processing payment status updates through the model.

=head1 METHODS

=head2 index

Displays the PayPal payments panel showing recent transactions and statistics.
Returns JSON data when Accept header is application/json, or renders HTML page.

=head2 ipn

Processes incoming IPN requests from PayPal, verifying the notification
and updating payment status accordingly.

=head2 success

Handles the return URL when a payment is successful.

=head2 cancel

Handles the return URL when a payment is cancelled.

=cut
