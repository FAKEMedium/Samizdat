package Samizdat::Controller::Fortnox;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::Util;
use Data::Dumper;


sub redirect ($self) {
  $self->redirect_to($self->url_for('manager_index'));
}


sub auth ($self) {
  # Initialize Fortnox session (creates 'fortnox' cookie)
  $self->session->{fortnox_active} = 1;
  $self->session(expiration => 7200);  # 2 hours
  say Dumper $self->req->params->to_hash;
  # Force cache session ID to be created now (before OAuth redirect)
  # This ensures the same session ID is used when redirected back
  unless ($self->session->{cache_session_id}) {
    my $session_id = Mojo::Util::md5_sum(time . $$ . rand());
    $self->session->{cache_session_id} = $session_id;
  }

  my $state = $self->param("state") // '';
  my $code = $self->param("code") // '';
  $self->app->fortnox->data->{state} = $state if ($state);
  $self->app->fortnox->data->{code} = $code if ($code);
  say "Fortnox auth - state: $state, code: " . ($code ? 'present' : 'none');
  say Dumper %{ $self->app->fortnox->data };

  if ('' ne $self->app->fortnox->data->{access}) {

  } elsif ('' ne $self->app->fortnox->data->{refresh}) {
    $self->app->fortnox->getToken(1);
  } elsif ('' ne $self->app->fortnox->data->{code}) {
    $self->app->fortnox->getToken(0);
  } else {
    my $redirect = $self->app->fortnox->getLogin();
    say $redirect;
    return $self->redirect_to($redirect);
  }
  $self->redirect_to($self->url_for('manager_index'));
}

sub pauth ($self) {
  # Initialize Fortnox session (creates 'fortnox' cookie)
  $self->session->{fortnox_active} = 1;
  $self->session(expiration => 7200);  # 2 hours

  # Force cache session ID to be created now (before OAuth redirect)
  # This ensures the same session ID is used when redirected back
  unless ($self->session->{cache_session_id}) {
    my $session_id = Mojo::Util::md5_sum(time . $$ . rand());
    $self->session->{cache_session_id} = $session_id;
  }

  my $fortnox = $self->app->fortnox;

  # Check if we got a code back from Fortnox
  if (my $code = $self->param('code')) {
    say "Got OAuth code from Fortnox: $code";

    # Verify state parameter
    my $state = $self->param('state');
    if ($state && $state ne 'login') {
      say "State verified: $state";
    }

    # Store code and exchange for tokens
    $fortnox->data->{code} = $code;
    $fortnox->saveCache;

    if ($fortnox->getToken) {
      say "Fortnox OAuth successful";
      say "Access token: " . $fortnox->data->{access};
      return $self->redirect_to($self->url_for('manager_index'));
    } else {
      say "Failed to exchange code for token";
      return $self->render(text => "Authentication failed: Could not get access token", status => 401);
    }
  }

  # No code, so initiate OAuth flow using Fortnox model's getLogin
  if (my $redirect_url = $fortnox->getLogin) {
    say "Redirecting to Fortnox: $redirect_url";
    return $self->redirect_to($redirect_url);
  } else {
    say "Failed to get login URL from Fortnox";
    return $self->render(text => "Authentication failed: Could not initiate OAuth", status => 500);
  }
}


sub customers ($self) {
  my $title = $self->app->__('Customers');
  my $web = { title => $title };
  my $customerid = int($self->stash('customerid') // 0);
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    if ($customerid) {
      # Override cache path for dynamic customer ID to prevent creating separate cached files
      $self->stash(docpath => '/fortnox/customers/single/index.html');
      $web->{script} .= $self->render_to_string(format => 'js', template => 'fortnox/customers/single/index');
      return $self->render(web => $web, title => $title, template => 'fortnox/customers/single/index', layout => 'modal');
    } else {
      $web->{script} .= $self->render_to_string(format => 'js', template => 'fortnox/customers/index');
      return $self->render(web => $web, title => $title, template => 'fortnox/customers/index');
    }
  } else {
    # Require admin access for JSON customer data
    return unless $self->access({ admin => 1 });

    my $customer = $self->app->fortnox->getCustomer($customerid);
    say Dumper($customer);
    if (exists($customer->{Customers})) {
      my $fortnox = {
        title => $title,
      };
      $fortnox->{customers} = $customer->{Customers};
      return $self->render(json => { fortnox => $fortnox });
    }
  }
}


sub invoices ($self) {
  # Require admin access for invoice management
  return unless $self->access({ admin => 1 });

  my $title = $self->app->__('Invoices');
  my $web = { title => $title };
  my $invoiceid = int($self->stash('invoiceid') // 0);
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    if ($invoiceid) {
      $self->stash(docpath => '/fortnox/invoices/single/index.html');
      $web->{script} .= $self->render_to_string(format => 'js', template => 'fortnox/invoices/single/index');
      return $self->render(web => $web, title => $title, template => 'fortnox/invoices/single/index');
    } else {
      $web->{script} .= $self->render_to_string(format => 'js', template => 'fortnox/invoices/index');
      return $self->render(web => $web, title => $title, template => 'fortnox/invoices/index');
    }
  } else {
    my $page = int($self->param('page') // 1);
    my $perpage = $self->app->config->{pagination}->{perpage} || 25;
    my $options = {'qp' => {'limit' => $perpage, 'page' => $page}};
    my $invoice = $self->app->fortnox->getInvoice($invoiceid, $options);
    my $fortnox = { title => $title };
    $fortnox->{invoice} = $invoice;
    $fortnox->{page} = $page;
    $fortnox->{perpage} = $perpage;
    return $self->render(json => { fortnox => $fortnox });
  }
}


sub invoicenav ($self) {
  # Require admin access for invoice navigation
  return unless $self->access({ admin => 1 });

  my $invoiceid = int($self->stash('invoiceid') // 0);
  my $to = $self->stash('to') // 'next';

  my $next_id = $self->app->fortnox->navInvoice($to, $invoiceid);

  if ($next_id) {
    return $self->redirect_to($self->url_for('fortnox_invoice', invoiceid => $next_id));
  } else {
    # Stay on current invoice if no prev/next available
    return $self->redirect_to($self->url_for('fortnox_invoice', invoiceid => $invoiceid));
  }
}


sub payments ($self) {
  # Require admin access for payment management
  return unless $self->access({ admin => 1 });

  my $title = $self->app->__('Payments');
  my $web = { title => $title };
  my $number = int($self->stash('number') // 0);
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    if ($number) {
      # Override cache path for dynamic payment number to prevent creating separate cached files
      $self->stash(docpath => '/fortnox/payments/single/index.html');
      $web->{script} .= $self->render_to_string(format => 'js', template => 'fortnox/payments/single/index');
      return $self->render(web => $web, title => $title, template => 'fortnox/payments/single/index', layout => 'modal');
    } else {
      $web->{script} .= $self->render_to_string(format => 'js', template => 'fortnox/payments/index');
      return $self->render(web => $web, title => $title, template => 'fortnox/payments/index');
    }
  } else {
    my $invoiceid = int($self->param('invoiceid') // 0);
    my $page = int($self->param('page') // 1);
    my $perpage = $self->app->config->{pagination}->{perpage} || 25;
    my $options = {'qp' => {
      'limit' => $perpage,
      'page' => $page,
      'sortby' => 'paymentdate',
      'sortorder' => 'descending',
    }};
    if ($invoiceid) {
      $options->{qp}->{invoicenumber} = $invoiceid;
    }
    my $payment = $self->app->fortnox->getInvoicePayment($number, $options);

    # Enrich payments with customer names from cached invoice data
    if ($payment && $payment->{InvoicePayments}) {
      my @invoice_numbers = map { $_->{InvoiceNumber} } @{$payment->{InvoicePayments}};
      my $customer_names = $self->app->fortnox->getInvoiceCustomerNames(\@invoice_numbers);
      for my $p (@{$payment->{InvoicePayments}}) {
        $p->{CustomerName} = $customer_names->{$p->{InvoiceNumber}} // '';
      }
    }

    my $fortnox = { title => $title };
    $fortnox->{payment} = $payment;
    $fortnox->{page} = $page;
    $fortnox->{perpage} = $perpage;
    return $self->render(json => { fortnox => $fortnox });
  }
}


sub logout ($self) {
  # Clear Fortnox cache in Redis
  $self->app->fortnox->removeCache;

  # Expire the session cookie
  $self->session(expires => 1);

  $self->redirect;
}


sub _login ($self) {
  say $self->app->config->{manager}->{url};
  $self->redirect_to($self->url_for('fortnox_auth'));
}


sub index ($self) {
  my $title = $self->app->__('Samizdat');
  my $web = { title => $title };

  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    $web->{script} .= $self->render_to_string(format => 'js');
    return $self->render(web => $web, title => $title);
  }
}


sub manager ($self) {
  my $title = $self->app->__('Fortnox panel');
  my $fortnox = {
    archive  => [],
    payments => [],
  };
  my $web = { title => $title };

  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    $web->{script} .= $self->render_to_string(format => 'js');
    return $self->render(web => $web, title => $title, template => 'fortnox/manager/index');
  } else {
    $fortnox->{archive} = $self->app->fortnox->getArchive();
    return $self->render(json => { fortnox => $fortnox });
  }
}


sub activate ($self) {
  # Require admin access for Fortnox activation
  return unless $self->access({ admin => 1 });

  my $title = $self->app->__('Activate Samizdat Fortnox integration');
  my $web = { title => $title };
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    $web->{script} .= $self->render_to_string(format => 'js', template => 'fortnox/activate/index');
    return $self->render(web => $web, title => $title, template => 'fortnox/activate/index');
  } else {
    return $self->render(json => { success => 1 });
  }
}


sub start ($self) {
  my $title = $self->app->__('Activate Samizdat Fortnox integration');
  my $web = { title => $title };

  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    $web->{script} .= $self->render_to_string(format => 'js', template => 'fortnox/start/index');
    return $self->render(web => $web, title => $title, template => 'fortnox/start/index');
  }
}


1;
