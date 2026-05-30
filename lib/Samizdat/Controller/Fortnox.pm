package Samizdat::Controller::Fortnox;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::Util;


sub redirect ($self) {
  $self->redirect_to($self->url_for('manager_index'));
}


# Accept only local absolute paths, so the OAuth return path can never be
# abused as an open redirect to a foreign host. redirect_to re-parses the
# string and decodes one more layer of percent escapes (notably %2F -> /), so
# we validate both the value and its decoded form: otherwise "/%2F%2Fevil.com"
# would surface as "///evil.com" (a protocol-relative redirect) in Location.
sub _local_path ($self, $path) {
  return undef unless defined($path) && length($path);
  for my $p ($path, Mojo::Util::url_unescape($path)) {
    return undef if $p =~ m{[\x00-\x1f]};  # control chars (incl. CR/LF)
    return undef unless $p =~ m{^/};       # must be a local absolute path
    return undef if $p =~ m{^/[/\\]};      # reject //host and /\host
  }
  return $path;
}

# Resolve where to send the user once Fortnox auth completes. The return path
# is remembered in the 'fortnox' session cookie, which travels with the browser
# across the whole round-trip (SameSite=Lax) and survives even when Fortnox does
# not echo our state back. The request's own 'return' param and the OAuth state
# echo are fallbacks. Falls back to the manager dashboard.
sub _auth_return ($self) {
  my $return = $self->_local_path(delete $self->session->{fortnox_return});
  $return ||= $self->_local_path($self->param('return'));
  if (!$return && ($self->param('state') // '') =~ /^return:(.+)\z/s) {
    $return = $self->_local_path($1);
  }
  return $self->redirect_to($return // $self->url_for('manager_index'));
}

# Render the JSON 401 that tells the frontend to (re)authenticate with Fortnox.
# auth_url points at our own OAuth-init route; the general 401 interceptor
# navigates there and appends its own return path, so the route stays a Fortnox
# concern and never leaks into shared frontend code.
sub _fortnox_auth_required ($self) {
  return $self->render(
    json => {
      error      => 'Fortnox authentication required',
      auth_url   => $self->url_for('fortnox_auth')->to_string,
      needs_auth => 1,
    },
    status => 401,
  );
}

sub auth ($self) {
  # Initialize Fortnox session (creates 'fortnox' cookie)
  $self->session->{fortnox_active} = 1;
  $self->session(expiration => 7200);  # 2 hours

  # Force cache session ID to be created now (before OAuth redirect)
  # This ensures the same session ID is used when redirected back
  unless ($self->session->{cache_session_id}) {
    my $session_id = Mojo::Util::md5_sum(time . $$ . rand());
    $self->session->{cache_session_id} = $session_id;
  }

  # Remember where to return after OAuth. The 'fortnox' session cookie travels
  # with the browser across the whole round-trip, so this survives even when
  # Fortnox does not echo our state parameter back.
  if (my $return = $self->_local_path($self->param('return'))) {
    $self->session->{fortnox_return} = $return;
  }

  my $fortnox = $self->app->fortnox;
  $fortnox->reload;  # sync token state for this worker
  my $code = $self->param('code') // '';
  $fortnox->data->{code} = $code if ($code);

  if ('' ne $fortnox->data->{access}) {
    # Already have an access token.
  } elsif ('' ne $fortnox->data->{refresh}) {
    $fortnox->getToken(1);
  } elsif ('' ne $fortnox->data->{code}) {
    $fortnox->getToken(0);
  } else {
    # No credentials yet: start the OAuth dance. Pass the return path in the
    # OAuth state too, as a fallback to the session cookie.
    my $oauth_state = 'login';
    if (my $return = $self->session->{fortnox_return}) {
      $oauth_state = 'return:' . $return;
    }
    return $self->redirect_to($fortnox->getLogin($oauth_state));
  }

  return $self->_auth_return;
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
      return $self->_fortnox_auth_required;
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
      return $self->_fortnox_auth_required;
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
      return $self->_fortnox_auth_required;
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
        paydate => { LIKE => '0000-00-00%' },
        state   => 'fakturerad'
      }
    });

    # Batch-fetch all needed customers in one query
    my @customer_ids = map { $_->{customerid} } @$unpaid_invoices;
    my %customer_map;
    if (@customer_ids) {
      my $customers = $self->app->customer->get({ where => { customerid => \@customer_ids } });
      %customer_map = map { $_->{customerid} => $_ } @$customers;
    }

    # Map by fakturanummer for quick lookup, include customer info
    my %unpaid_map;
    for my $inv (@$unpaid_invoices) {
      my $customer = $customer_map{$inv->{customerid}};
      $unpaid_map{$inv->{fakturanummer}} = {
        invoiceid    => $inv->{invoiceid},
        customerid   => $inv->{customerid},
        customername => $customer ? $self->app->customer->name($customer) : '',
        totalcost    => $inv->{totalcost},
        debt         => $inv->{debt},
      };
    }

    # Split payments: unprocessed (matching unpaid local invoices) and all (paginated)
    my @all_payments = reverse @{ $payment->{InvoicePayments} };
    my @unprocessed = grep { $unpaid_map{$_->{InvoiceNumber}} } @all_payments;

    # Paginate only the "all" view
    my $page = int($self->param('page') // 1);
    my $perpage = $self->app->config->{pagination}->{perpage} || 25;
    my $start = ($page - 1) * $perpage;
    my $end = $start + $perpage - 1;
    $end = $#all_payments if $end > $#all_payments;
    my @paged = $start <= $#all_payments ? @all_payments[$start..$end] : ();

    my $fortnox = { title => $title };
    $fortnox->{payment} = { InvoicePayments => \@paged };
    $fortnox->{unprocessed_payments} = \@unprocessed;
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
      return $self->_fortnox_auth_required;
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
