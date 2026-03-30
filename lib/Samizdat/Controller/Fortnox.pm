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
  my $customerid = $self->stash('customerid') // '';
  my $accept = $self->req->headers->accept // '';

  if ($accept !~ /json/) {
    if ($customerid) {
      # Override cache path for dynamic customer ID to prevent creating separate cached files
      $self->stash(docpath => '/fortnox/customers/customer/index.html');
      $web->{script} = $self->render_to_string(format => 'js', template => 'fortnox/customers/customer/index');
      return $self->render(web => $web, title => $title, template => 'fortnox/customers/customer/index');
    } else {
      $web->{script} = $self->render_to_string(format => 'js', template => 'fortnox/customers/index');
      return $self->render(web => $web, title => $title, template => 'fortnox/customers/index');
    }
  } else {
    # Require admin access for JSON customer data
    return unless $self->access({ admin => 1 });

    my $result = $self->app->fortnox->getCustomer($customerid);

    # Check if result is auth URL (string) instead of data (hash)
    if (!ref($result)) {
      my $auth_url = $result;
      $auth_url =~ s/\s+$//;
      return $self->render(json => { error => 'Fortnox authentication required', auth_url => $auth_url, needs_auth => 1 }, status => 401);
    }

    my $fortnox = { title => $title };

    if ($customerid && exists($result->{Customer})) {
      # Single customer
      $fortnox->{customer} = $result->{Customer};
    } elsif (exists($result->{Customers})) {
      # Customer list
      $fortnox->{customers} = $result->{Customers};
    }

    return $self->render(json => { fortnox => $fortnox });
  }
}


sub customernav ($self) {
  # Require admin access for customer navigation
  return unless $self->access({ admin => 1 });

  my $customerid = $self->stash('customerid') // '';
  my $to = $self->stash('to') // 'next';

  my $next_id = $self->app->fortnox->navCustomer($to, $customerid);

  if ($next_id) {
    return $self->redirect_to($self->url_for('fortnox_customer', customerid => $next_id));
  } else {
    # Stay on current customer if no prev/next available
    return $self->redirect_to($self->url_for('fortnox_customer', customerid => $customerid));
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
      $self->stash(docpath => '/fortnox/invoices/invoice/index.html');
      $web->{script} .= $self->render_to_string(format => 'js', template => 'fortnox/invoices/invoice/index');
      return $self->render(web => $web, title => $title, template => 'fortnox/invoices/invoice/index');
    } else {
      $web->{script} .= $self->render_to_string(format => 'js', template => 'fortnox/invoices/index');
      return $self->render(web => $web, title => $title, template => 'fortnox/invoices/index');
    }
  } else {
    my $page = int($self->param('page') // 1);
    my $perpage = $self->app->config->{pagination}->{perpage} || 25;
    my $options = {'qp' => {
      'limit' => $perpage,
      'page' => $page,
      'sortby' => 'documentnumber',
      'sortorder' => 'descending'
    }};
    my $invoice = $self->app->fortnox->getInvoice($invoiceid, $options);

    # Check if result is auth URL (string) instead of data (hash)
    if (!ref($invoice)) {
      my $auth_url = $invoice;
      $auth_url =~ s/\s+$//;
      return $self->render(json => { error => 'Fortnox authentication required', auth_url => $auth_url, needs_auth => 1 }, status => 401);
    }

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
  my $title = $self->app->__('Payments');
  my $web = { title => $title };
  my $number = int($self->stash('number') // 0);
  my $accept = $self->req->headers->accept // '';
  if ($accept !~ /json/) {
    if ($number) {
      # Override cache path for dynamic payment number to prevent creating separate cached files
      $self->stash(docpath => '/fortnox/payments/payment/index.html');
      $web->{script} .= $self->render_to_string(format => 'js', template => 'fortnox/payments/payment/index');
      return $self->render(web => $web, title => $title, template => 'fortnox/payments/payment/index', layout => 'modal');
    } else {
      $web->{script} .= $self->render_to_string(format => 'js', template => 'fortnox/payments/index');
      return $self->render(web => $web, title => $title, template => 'fortnox/payments/index');
    }
  } else {
    # Require admin access for JSON data
    return unless $self->access({ admin => 1 });

    # Refresh cache only if requested via ?refresh=1 parameter
    if ($self->param('refresh')) {
      $self->app->fortnox->updateCache('InvoicePayments');
    }
    my $payment = $self->app->fortnox->getInvoicePayment($number);

    # Check if result is auth URL (string) instead of data (hash)
    if (!ref($payment)) {
      my $auth_url = $payment;
      $auth_url =~ s/\s+$//;
      return $self->render(json => { error => 'Fortnox authentication required', auth_url => $auth_url, needs_auth => 1 }, status => 401);
    }

    # Return early if Fortnox API failed (no point querying local invoices)
    if (!$payment || $payment->{error} || !exists $payment->{InvoicePayments}) {
      return $self->render(json => {
        error => $payment->{error} // 'Failed to fetch payments from Fortnox'
      }, status => 502);
    }

    # Get local invoices with remaining debt for comparison
    # Customer name comes from local database, not Fortnox API
    my $unpaid_invoices = $self->app->invoice->get({
      where => {
        debt  => { '>' => 0 },
        state => 'fakturerad'
      }
    });
    # Map by fakturanummer for quick lookup, include customer info
    my %unpaid_map;
    for my $inv (@$unpaid_invoices) {
      my $customer = $self->app->customer->get({ where => { customerid => $inv->{customerid} } })->[0];
      $unpaid_map{$inv->{fakturanummer}} = {
        invoiceid    => $inv->{invoiceid},
        customerid   => $inv->{customerid},
        customername => $customer ? $self->app->customer->name($customer) : '',
        totalcost    => $inv->{totalcost},
        debt         => $inv->{debt},
      };
    }

    # Paginate the payment list (latest first)
    my $page = int($self->param('page') // 1);
    my $perpage = $self->app->config->{pagination}->{perpage} || 25;
    my @all_payments = reverse @{ $payment->{InvoicePayments} };
    my $start = ($page - 1) * $perpage;
    my $end = $start + $perpage - 1;
    $end = $#all_payments if $end > $#all_payments;
    my @paged = $start <= $#all_payments ? @all_payments[$start..$end] : ();

    my $fortnox = { title => $title };
    $fortnox->{payment} = { InvoicePayments => \@paged };
    $fortnox->{unpaid_invoices} = \%unpaid_map;
    $fortnox->{perpage} = $perpage;
    return $self->render(json => { fortnox => $fortnox });
  }
}


sub process_payments ($self) {
  # Require admin access
  return unless $self->access({ admin => 1 });

  my $data = $self->req->json;
  my $payments = $data->{payments} // [];
  my $processed = 0;
  my $current_user = $self->session->{user} // $self->session->{username} // 'fortnox';

  for my $payment (@$payments) {
    my $invoice_number = $payment->{invoiceNumber};
    my $paydate = $payment->{date};  # Date from Fortnox (bank date)
    my $amount = $payment->{amount} + 0;  # Ensure numeric

    next unless $invoice_number && $paydate && $amount > 0;

    # Find local invoice by fakturanummer
    my $invoices = $self->app->invoice->get({
      where => { fakturanummer => $invoice_number }
    });

    if (@$invoices) {
      my $invoice = $invoices->[0];

      # Add payment record to invoicepayment table
      $self->app->invoice->addpayment({
        invoiceid  => $invoice->{invoiceid},
        customerid => $invoice->{customerid},
        paydate    => $paydate,
        amount     => $amount,
        updater    => $current_user
      });

      # Calculate new debt
      my $new_debt = ($invoice->{debt} || $invoice->{totalcost}) - $amount;
      $new_debt = 0 if $new_debt < 0;

      # Check if remaining debt is within acceptable exchange rate difference
      my $totalcost = $invoice->{totalcost} || 1;
      my $payment_diff_pct = $self->app->config->{manager}->{invoice}->{paymentdifference} // 1;
      my $max_diff = $totalcost * ($payment_diff_pct / 100);
      my $is_fully_paid = ($new_debt <= $max_diff);

      # Update invoice
      my $update = {
        debt    => $is_fully_paid ? 0 : $new_debt,
        updated => \['NOW()'],
      };

      # When fully paid: set paydate, state, and bookingdate
      if ($is_fully_paid) {
        $update->{paydate}     = $paydate;  # Date from Fortnox (bank date)
        $update->{state}       = 'bokford';
        $update->{bookingdate} = \['NOW()'];
      }

      $self->app->invoice->updateinvoice($invoice->{invoiceid}, $update);

      $processed++;
    }
  }

  return $self->render(json => { success => 1, processed => $processed });
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
    my $archive = $self->app->fortnox->getArchive();

    # Check if result is auth URL (string) instead of data (hash)
    if (!ref($archive)) {
      my $auth_url = $archive;
      $auth_url =~ s/\s+$//;
      return $self->render(json => { error => 'Fortnox authentication required', auth_url => $auth_url, needs_auth => 1 }, status => 401);
    }

    $fortnox->{archive} = $archive;
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
