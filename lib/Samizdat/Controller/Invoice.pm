package Samizdat::Controller::Invoice;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::Util qw(decode encode b64_encode);
use Encode qw(decode_utf8 is_utf8);
use UUID qw(uuid);
use Date::Format;
use MIME::Lite;
use Mojo::Home;
use Data::Dumper;

my $fields = [qw(articlenumber include invoiceitemtext number price)];

# invoice states are (names will change)
# fakturerad - issued but not payed
# bokford - issued and full payment received
# obehandlad - open invoice
# krediterad, raderad - credit and credited invoice

sub index ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    my $title = $self->app->__('Invoices');
    my $web = { title => $title };
    my $toast = $self->render_to_string(
      template => 'chunks/toast',
      format => 'html',
      toast => {
        title  => $self->app->__('Updated invoice'),
        body   => $self->app->__('Changed status.'),
        icon   => $self->app->icon('info-circle-fill', { extraclass => 'mx-2 text-primary' }),
        'time' => '',
        id     => 'customer-toast',
      }
    );
    $web->{script} .= $self->render_to_string(template => 'invoice/chunks/paymentmodal', format => 'js');
    $web->{script} .= $self->render_to_string(template => 'invoice/index', format => 'js', toast => $toast);
    return $self->render(web => $web, title => $title, template => 'invoice/index', invoices => [], cache => 1);
  } else {
    # Check access: admin or valid-user
    my $authcookie = $self->cookie($self->config->{manager}->{account}->{authcookiename});
    my $session = $authcookie ? $self->app->account->session($authcookie) : undef;
    my $is_admin = 0;

    if ($session && $session->{username}) {
      my $admins = $self->config->{manager}->{account}->{admins} // {};
      my $superadmins = $self->config->{manager}->{account}->{superadmins} // {};
      $is_admin = 1 if exists $admins->{$session->{username}} || exists $superadmins->{$session->{username}};
    }

    my $customerid = int($self->param('customerid') // 0);
    my $customer = {};
    my $options = {};

    if (!$is_admin) {
      # Non-admin: require valid-user and filter to own customer
      return unless $self->access({ 'valid-user' => 1 });
      my $user_customerid = $self->app->customer->get_customerid_for_user($session->{userid});
      return $self->render(json => { invoices => [], customer => {}, admin => 0 }) unless $user_customerid;
      $customerid = $user_customerid;
    }

    if ($customerid) {
      $options->{where}->{customerid} = $customerid;
      $customer = $self->app->customer->get($options)->[0];
      $customer->{customerid} = $customerid;
    }

    # Get existing filter from cookie
    my $filter_cookie = $self->cookie('invoicefilter');
    my $filter = {};
    if ($filter_cookie) {
      eval {$filter = decode_json($filter_cookie);};
    }

    # Get parameters from form or cookie defaults
    my ($searchterm, $paid, $unpaid, $destroyed);
    my $action = $self->param('action') // '';
    if ($action =~ /^search$/i) {
      $paid = int $self->param('paid');
      $unpaid = int $self->param('unpaid');
      $destroyed = int $self->param('destroyed');
      $self->param('searchterm');
    } else {
      $searchterm = $filter->{searchterm} // '';
      $paid = $filter->{paid} // 0;
      $destroyed = $filter->{destroyed} // 0;
      $unpaid = $filter->{unpaid} // 1;
    }

    # Apply parameters
    $options->{where}->{invoicedate} = { '>' => '2017' };
    my @states;

    # Search by invoice number if numeric
    if ($searchterm =~ /^\d+$/) {
      $options->{where}->{fakturanummer} = $searchterm;
    }

    # Always apply state filters (checkboxes are "among these")
    if ($paid) {
      push @states, 'bokford';
    }
    if ($unpaid) {
      push @states, 'fakturerad';
    }
    if ($destroyed) {
      push @states, 'raderad';
      push @states, 'krediterad';
    }

    # Apply state filter
    if (@states) {
      $options->{where}->{state} = { '-in' => \@states };
    } else {
      # Default: exclude 'obehandlad' if no state filters selected
      $options->{where}->{state} = { '!=' => 'obehandlad' };
    }

    my $invoices = $self->app->invoice->get($options);

    # Get unique customer IDs from invoices
    my %customer_ids = map { $_->{customerid} => 1 } grep { $_->{customerid} } @$invoices;

    # Fetch all customers at once if there are any
    my %customer_names;
    if (keys %customer_ids) {
      # Is this query ok or should we make a join query?
      my $customers = $self->app->customer->get({
        where => { customerid => { '=' => [keys %customer_ids] } }
      });

      # Build lookup hash of customer names
      foreach my $cust (@$customers) {
        $customer_names{$cust->{customerid}} = $self->app->customer->name($cust);
      }
    }

    # Add customer names to invoices
    foreach my $invoice (@$invoices) {
      if ($invoice->{customerid} && exists $customer_names{$invoice->{customerid}}) {
        $invoice->{customername} = $customer_names{$invoice->{customerid}};
      }
    }

    my $formdata = {
      customer   => $customer,
      invoices   => $invoices,
      paid       => $paid,
      unpaid     => $unpaid,
      destroyed  => $destroyed,
      searchterm => $searchterm,
      admin      => $is_admin ? 1 : 0,
    };

    # Update filter and save to cookie
    $filter = { searchterm => $searchterm, paid => $paid, unpaid => $unpaid, destroyed => $destroyed };

    # Set session cookie with JSON data
    $self->cookie(invoicefilter => encode_json($filter), {
      path     => '/',
      httponly => 0,
      secure   => 1,
      samesite => 'Strict'
      # No expires = session cookie
    });

    return $self->render(json => $formdata);
  }
}


sub creditinvoice ($self) {
  $self->create(1);
}


sub create ($self, $credit = 0) {
  # Require admin access for invoice management
  return unless $self->access({ admin => 1 });

  my $customerid = int($self->stash('customerid') // 0);
  my $invoiceid = int($self->stash('invoiceid') // 0);

  # Get customer to determine billing language
  my $customer = $self->app->customer->get({ where => { customerid => $customerid } })->[0];
  my $lang = $customer->{billinglang} || $customer->{lang} || $self->config->{locale}->{default_language} || 'sv';
  $lang =~ s/_[A-Z]{2}$// if $lang;
  $self->app->language($lang);

  # For regular invoices, get and validate form data
  if (!$credit) {
    my $formdata = $self->update(0);
    delete $formdata->{invoiceitems}->{extra};

    # Update IDs from formdata (may differ from stash values)
    $customerid = $formdata->{customer}->{customerid};
    $invoiceid = $formdata->{invoice}->{invoiceid};

    # Validate invoice items
    for my $invoiceitemid (keys %{$formdata->{invoiceitems}}) {
      my $item = $formdata->{invoiceitems}->{$invoiceitemid};
      if (!$item->{articlenumber} || !$item->{number} || !$item->{invoiceitemtext} || !defined($item->{price})) {
        return $self->render(json => { error => $self->app->__('Fill the form correctly!') });
      }
    }
  }

  # Process the invoice (credit or regular)
  my $result = $self->process_invoice(
    $credit ? 0 : $invoiceid,
    $customerid,
    {
      create => 1,
      credit => $credit ? 1 : 0,
      $credit ? (original_invoiceid => $invoiceid) : (handle_unincluded => 1)
    }
  );

  if ($result->{error}) {
    my $type = $credit ? 'credit invoice' : 'invoice';
    $self->app->log->error("Cannot create $type - " . $result->{error});

    # If Fortnox needs re-authentication, return auth URL for client-side redirect
    if ($result->{needs_auth} && $result->{auth_url}) {
      my $auth_url = $result->{auth_url};
      $auth_url =~ s/\s+$//;  # Remove trailing whitespace/newline
      return $self->render(json => { error => $result->{error}, auth_url => $auth_url, needs_auth => 1 }, status => 401);
    }

    return $self->render(json => { error => $result->{error} }, status => $result->{status} || 500);
  }

  # Fortnox integration is handled automatically in process_invoice helper

  # Prepare invoice data for email
  my $invoicedata = {
    invoice => $result->{invoice},
    customer => $result->{customer},
    vat => $result->{formdata}->{vat}
  };

  # Send invoice email (plugin handles snailmail logic for BCC to accountant)
  my $email_result = $self->send_invoice_email($invoicedata, { action => $credit ? 'credit' : 'send' });

  if (!$email_result->{success}) {
    $self->app->log->error("Failed to send invoice email: " . ($email_result->{error} || $self->app->__('Unknown error')));
    # Continue anyway - invoice was created successfully, just email failed
  }

  if ($credit) {
    return $self->redirect_to($self->url_for('invoice_customer_handle',
      customerid => $result->{invoice}->{customerid}, invoiceid => $result->{invoice}->{invoiceid}
    ));
  }

  # Return PDF
  if (!$result->{pdf}) {
    $self->app->log->error("PDF generation failed for invoice " . $result->{invoice}->{fakturanummer});
    return $self->render(json => { error => 'PDF generation failed' }, status => 500);
  }

  $self->res->headers->content_type('application/pdf');
  $self->res->headers->header('Content-Disposition' =>
    sprintf('inline; filename="%s.pdf"', $result->{invoice}->{uuid})
  );
  # Add custom header to trigger print dialog on client side for snailmail
  $self->res->headers->header('X-Print-Dialog' => 'true') if ($result->{customer}->{invoicetype} // '') eq 'snailmail';
  return $self->render(data => $result->{pdf});
}


sub update ($self, $makejson = 1) {
  # Require admin access for invoice management
  return unless $self->access({ admin => 1 });

  my $formdata = $self->_formdata() || return 0;
  $self->app->customer->update($formdata->{invoice}->{customerid}, $formdata->{customer});

  for my $invoiceitemid (keys %{$formdata->{invoiceitems}}) {
    if ($invoiceitemid =~ /^[\d]+$/) {
      # Ensure include field is numeric (0 or 1)
      $formdata->{invoiceitems}->{$invoiceitemid}->{include} = int($formdata->{invoiceitems}->{$invoiceitemid}->{include} || 0);
      $self->app->invoice->updateinvoiceitem($invoiceitemid, $formdata->{invoiceitems}->{$invoiceitemid});
    }
  }
  my $extra = $formdata->{invoiceitems}->{extra};
  $extra->{customerid} = $formdata->{customer}->{customerid};
  $extra->{invoiceid} = $formdata->{invoice}->{invoiceid};

  if ((int($extra->{number} || 0) > 0) && ('' ne ($extra->{invoiceitemtext} // '')) && (($extra->{price} || 0) > 0.0)) {
    $self->app->invoice->addinvoiceitem($extra);
  }

  $formdata->{customer} = $self->app->customer->get({
    where => { customerid => $formdata->{invoice}->{customerid} } }
  )->[0];
  $formdata->{invoice} = $self->app->invoice->get({
    where => { customerid => $formdata->{invoice}->{customerid}, invoiceid => $formdata->{invoice}->{invoiceid} }
  })->[0];
  $formdata->{invoiceitems} = $self->app->invoice->invoiceitems({
    where => {'invoice.invoiceid' => $formdata->{invoice}->{invoiceid}} }
  );
  $formdata->{invoiceitems}->{extra} = {
    invoiceitemid   => 'extra',
    invoiceid       => $formdata->{invoice}->{invoiceid},
    invoiceitemtext => '',
    price           => '',
    vat             => $formdata->{invoice}->{vat},
    customerid      => $formdata->{invoice}->{customerid},
    number          => '',
    include         => 1,
    articlenumber   => '',
  };

  if ($makejson) {
    return $self->render(json => $formdata);
  } else {
    return $formdata;
  }
}


# Simple update for individual invoice fields (e.g., payment date from list view)
sub updateSimple ($self) {
  return unless $self->access({ admin => 1 });

  my $invoiceid = $self->stash('invoiceid');
  return $self->render(json => { error => 'Missing invoice ID' }, status => 400) unless $invoiceid;

  my $data = $self->req->json // {};

  # Only allow specific fields to be updated via this endpoint
  my %allowed = map { $_ => 1 } qw(paydate state);
  my %update_data;
  for my $field (keys %$data) {
    if ($allowed{$field}) {
      $update_data{$field} = $data->{$field};
    }
  }

  return $self->render(json => { error => 'No valid fields to update' }, status => 400) unless %update_data;

  # If paydate is set and state is 'fakturerad', also mark as paid
  if (exists $update_data{paydate} && $update_data{paydate}) {
    my $invoice = $self->app->invoice->get({ where => { invoiceid => $invoiceid } })->[0];
    if ($invoice && $invoice->{state} eq 'fakturerad') {
      $update_data{state} = 'bokford';
    }
  }

  my $result = $self->app->invoice->updateinvoice($invoiceid, \%update_data);

  if ($result) {
    return $self->render(json => { success => 1, invoiceid => $invoiceid });
  } else {
    return $self->render(json => { error => 'Failed to update invoice' }, status => 500);
  }
}


# Render payment modal HTML chunk
sub paymentModal ($self) {
  return unless $self->access({ admin => 1 });
  return $self->render(template => 'invoice/chunks/paymentmodal', format => 'html', layout => undef);
}


sub edit ($self) {
  my $title = $self->app->__('Open invoice');
  my $web = {title => $title};
  my $toast = $self->render_to_string(
    template => 'chunks/toast',
    format => 'html',
    toast => {
      title  => $self->app->__('Updated invoice'),
      body   => $self->app->__('Modifications were saved.'),
      icon   => $self->app->icon('info-circle-fill', { extraclass => 'mx-2 text-primary' }),
      'time' => '',
      id     => 'invoice-toast',
    }
  );
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    # Override cache path to match template structure and share cache between /invoices/ and /customers/:customerid/invoices/ routes
    $self->stash(docpath => '/invoices/open/edit/index.html');
    $web->{script} .= $self->render_to_string(template => 'invoice/open/edit/index', format => 'js', toast => $toast);
    return $self->render(web => $web, title => $title, template => 'invoice/open/edit/index', headline => 'invoice/chunks/editlinks');
  } else {
    # Require admin access for JSON invoice data
    return unless $self->access({ admin => 1 });

    my $customerid = int($self->stash('customerid') // 0);
    my $invoiceid = int($self->stash('invoiceid') // 0);

    # If no invoiceid, get the open invoice for this customer
    if (!$invoiceid && $customerid) {
      my $invoice = $self->app->invoice->get({
        where => { customerid => $customerid, state => 'obehandlad' }
      })->[0];
      $invoiceid = $invoice->{invoiceid} if $invoice;
    }

    # Get form data from model
    my $formdata = $self->app->invoice->get_invoice_formdata($invoiceid, $customerid);
    return $self->render(json => { error => 'Invoice not found' }) unless $formdata;

    # Add articles from Fortnox
    $formdata->{articles} = $self->_articles();

    # Pass any Fortnox errors to the frontend
    if (my $error = $self->stash('fortnox_error')) {
      $formdata->{fortnox_error} = $error;
    }

    $formdata->{invoiceitems}->{extra} = {
      invoiceitemid   => 'extra',
      invoiceid       => $formdata->{invoice}->{invoiceid},
      invoiceitemtext => '',
      price           => '',
      vat             => $formdata->{customer}->{vat},
      customerid      => $formdata->{customer}->{customerid},
      number          => '',
      include         => 1,
      articlenumber   => '',
    };
    return $self->render(json => $formdata);
  }
}


sub handle ($self) {
  # Require admin access for invoice handling
  return unless $self->access({ admin => 1 });

  my $title = $self->app->__x('Invoice');
  my $web = {title => $title};
  my $toast = $self->render_to_string(
    template => 'chunks/toast',
    format => 'html',
    toast => {
      title  => $self->app->__('Handled invoice'),
      body   => $self->app->__('Modifications were saved.'),
      icon   => $self->app->icon('info-circle-fill', { extraclass => 'mx-2 text-primary' }),
      'time' => '',
      id     => 'invoice-toast',
    }
  );
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    # Override cache path to match template structure and share cache between /invoices/ and /customers/:customerid/invoices/ routes
    $self->stash(docpath => '/invoices/handle/index.html');
    $web->{script} .= $self->render_to_string(template => 'invoice/chunks/paymentmodal', format => 'js');
    $web->{script} .= $self->render_to_string(template => 'invoice/handle/index', format => 'js', toast => $toast);
    return $self->render(web => $web, title => $title, template => 'invoice/handle/index', headline => 'invoice/chunks/handlelinks');
  } else {
    # Require admin access for JSON invoice data
    return unless $self->access({ admin => 1 });

    my $customerid = int($self->stash('customerid') // 0);
    my $invoiceid = int($self->stash('invoiceid') // 0);

    # Get form data from model
    my $formdata = $self->app->invoice->get_invoice_formdata($invoiceid, $customerid);
    return $self->render(json => { error => 'Invoice not found' }) unless $formdata;

    return $self->render(json => $formdata);
  }
}


sub nav ($self) {
  my $invoiceid = int($self->stash('invoiceid') // 0);
  my $customerid = int($self->stash('customerid') // 0);
  my $to = $self->stash('to');
  $self->stash(percustomer => $customerid);

  # Get filter from cookie
  my $filter_cookie = $self->cookie('invoicefilter');
  my $filter = {};
  if ($filter_cookie) {
    eval { $filter = decode_json($filter_cookie); };
  }

  # Build state filter based on cookie
  my @states = ();
  push @states, 'bokford' if $filter->{paid};
  push @states, 'fakturerad' if $filter->{unpaid};
  push @states, 'raderad', 'krediterad' if $filter->{destroyed};

  # Default to showing non-draft invoices if no filter specified
  @states = ('fakturerad', 'bokford', 'raderad') unless @states;

  my $invoice = $self->app->invoice->nav($to, $invoiceid, $customerid, \@states);
  if ($invoice->{invoiceid}) {
    $self->stash(invoiceid => $invoice->{invoiceid});
  }

  # Return JSON with invoice data
  return unless $self->access({ admin => 1 });

  my $nav_invoiceid = $invoice->{invoiceid};
  return $self->render(json => { error => 'No invoice found' }, status => 404) unless $nav_invoiceid;

  my $nav_invoice = $self->app->invoice->get({ where => { invoiceid => $nav_invoiceid } })->[0];
  return $self->render(json => { error => 'Invoice not found' }, status => 404) unless $nav_invoice;

  my $customer = $self->app->customer->get({ where => { customerid => $nav_invoice->{customerid} } })->[0];
  $customer->{name} = $self->app->customer->name($customer) if $customer;

  my $invoiceitems = $self->app->invoice->invoiceitems({ where => { 'invoice.invoiceid' => $nav_invoiceid } });

  return $self->render(json => {
    invoice => $nav_invoice,
    customer => $customer,
    invoiceitems => $invoiceitems
  });
}


# List open (unhandled) invoices
sub open ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    my $title = $self->app->__('Open invoices');
    my $web = {title => $title};
    $web->{script} .= $self->render_to_string(template => 'invoice/open/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'invoice/open/index');
  } else {
    return unless $self->access({ admin => 1 });

    my $invoiceitems = $self->app->invoice->invoiceitems({ where => { 'invoice.state' => { '=', 'obehandlad' } } });
    my $customers = {};
    for my $invoiceitemid (keys %{$invoiceitems}) {
      my $invoiceitem = $invoiceitems->{$invoiceitemid};
      my $customerid = delete $invoiceitem->{customerid};
      my $invoiceid = delete $invoiceitem->{invoiceid};
      delete $invoiceitem->{invoiceitemid};
      if (!exists($customers->{$customerid})) {
        my $customer = $self->app->customer->get({where => { customerid => $customerid }})->[0];
        $customer->{name} = $self->app->customer->name($customer);
        $customers->{$customerid} = $customer;
      }
      $customers->{$customerid}->{invoices}->{$invoiceid}->{invoiceitems}->{$invoiceitemid} = $invoiceitem;
    };
    return $self->render(json => { customers => $customers });
  }
}


# Mark a payment for an invoice
sub payment ($self) {
  # Require admin access for payment management
  return unless $self->access({ admin => 1 });

  my $title = $self->app->__('Mark payment');
  my $web = {title => $title};
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  my $invoiceid = int $self->stash('invoiceid') // 0;
  if ($accept !~ /json/) {
    # Override cache path to match template structure and share cache between /invoices/ and /customers/:customerid/invoices/ routes
    $self->stash(docpath => '/invoices/payment/index.html');
    $web->{script} .= $self->render_to_string(template => 'invoice/payment', format => 'js');
    return $self->render(template => 'invoice/payment', layout => 'modal', web => $web, title => $title);
  } else {
    # Require admin access for payment data
    return unless $self->access({ admin => 1 });
    my $invoice = {};
    my $customer = {};
    if ($invoice = $self->app->invoice->get({ where => { invoiceid => $invoiceid, state => 'fakturerad' } })->[0]) {
      my $customerid = $invoice->{customerid} // 0;
      if ($customer) {
        $customer = $self->app->customer->get({ where => { customerid => $customerid } })->[0];
        $customer->{name} = $self->app->customer->name($customer);
      }
      return $self->render(json => { });
    }
  }
}


# Send a reminder for an invoice
sub remind ($self) {
  # Require admin access
  return unless $self->access({ admin => 1 });

  my $invoiceid = int $self->stash('invoiceid') // 0;
  my $customerid = int $self->stash('customerid') // 0;

  unless ($invoiceid) {
    return $self->render(json => { error => $self->app->__('Invalid invoice ID') }, status => 400);
  }

  my $accept = $self->req->headers->{headers}->{accept}->[0] // '';

  # Handle POST request - send the reminder
  if ($self->req->method eq 'POST') {
    # Determine reminder type from request parameters
    my $reminder_type = $self->param('type') || 'mild';
    # Get invoice and customer data
    my $data = $self->app->invoice->get_invoice_and_customer($invoiceid, $customerid);
    if ($data->{error}) {
      return $self->render(json => { error => $data->{error} }, status => $data->{status});
    }

    my $invoice = $data->{invoice};
    my $customer = $data->{customer};

    # Set language based on customer billing language
    $customer->{billinglang} =~ s/_[A-Z]{2}$// if $customer->{billinglang};
    $self->language($customer->{billinglang} || $self->app->config->{locale}->{default_language} || 'sv');

    # Check if invoice is in correct state for reminders
    if ($invoice->{state} ne 'fakturerad') {
      return $self->render(json => { error => $self->app->__('Invoice must be in fakturerad state to send reminders') }, status => 400);
    }

    # Get invoice items for the email
    my $invoiceitems = $self->app->invoice->invoiceitems({
      where => { 'invoice.invoiceid' => $invoiceid }
    });

    # Calculate amounts
    my $amounts = $self->app->invoice->calculate_amounts(
      $invoiceitems,
      $customer->{vat},
      $customer->{currency}
    );

    # Prepare invoice data for email
    my $invoicedata = {
      invoice => $invoice,
      customer => $customer,
      invoiceitems => $invoiceitems,
      vat => $amounts->{vat_percent}
    };

    # Get reminder count for tracking
    my $reminders = $self->app->invoice->reminders($invoiceid);
    my $reminder_count = scalar(@$reminders);

    # Get custom message from form (Markdown) and convert to HTML
    my $custom_message = $self->param('mailmessage') || '';
    if ($custom_message) {
      # Convert Markdown to HTML using pandoc
      eval {
        require IPC::Open2;
        my $pid = IPC::Open2::open2(my $out, my $in, 'pandoc', '-f', 'markdown', '-t', 'html');
        binmode($in, ':encoding(UTF-8)');
        binmode($out, ':encoding(UTF-8)');
        print $in $custom_message;
        close $in;
        $custom_message = do { local $/; <$out> };
        waitpid($pid, 0);
      };
    }

    # Send reminder email using the plugin helper
    my $action = $reminder_type eq 'tough' ? 'reminder_tough' : 'reminder_mild';
    my $email_result = $self->send_invoice_email($invoicedata, {
      action => $action,
      message => $custom_message
    });

    if (!$email_result->{success}) {
      return $self->render(json => { error => $email_result->{error} || $self->app->__('Failed to send reminder') }, status => 500);
    }

    # Add reminder record to database
    $self->app->invoice->addreminder($invoiceid);

    # Return success for JSON requests
    if ($accept =~ /json/) {
      return $self->render(json => {
        success => 1,
        message => $self->app->__x('{reminder_type} reminder sent successfully', reminder_type => $reminder_type),
        type => $reminder_type,
        count => $reminder_count + 1
      });
    }

    # Redirect back to invoice for HTML requests
    return $self->redirect_to($self->url_for('invoice_customer_handle',
      customerid => $customerid, invoiceid => $invoiceid
    ));
  }

  # GET request - show the reminder form
  if ($accept !~ /json/) {
    # Override cache path to match template structure and share cache between /invoices/ and /customers/:customerid/invoices/ routes
    $self->stash(docpath => '/invoices/remind/index.html');

    # Get reminder count to show in UI
    my $reminders = $self->app->invoice->reminders($invoiceid);
    my $reminder_count = scalar(@$reminders);

    my $title = $self->app->__('Send reminder');
    my $web = {title => $title};

    # Get invoice data for display
    my $data = $self->app->invoice->get_invoice_and_customer($invoiceid, $customerid);
    if ($data->{error}) {
      return $self->render(text => $data->{error}, status => $data->{status});
    }

    # Set language based on customer billing language
    my $customer = $data->{customer};
    $customer->{billinglang} =~ s/_[A-Z]{2}$// if $customer->{billinglang};
    $self->language($customer->{billinglang} || $self->app->config->{locale}->{default_language} || 'sv');

    # Render default messages for JavaScript (just the message content)
    my $invoicedata = {
      invoice => $data->{invoice},
      customer => $data->{customer}
    };

    # Render markdown templates - ensure proper UTF-8 character strings
    my $mild_message = $self->render_to_string(
      template => 'invoice/remind/mild',
      invoicedata => $invoicedata,
      format => 'md'
    );
    my $tough_message = $self->render_to_string(
      template => 'invoice/remind/tough',
      invoicedata => $invoicedata,
      format => 'md'
    );

    $web->{script} = $self->render_to_string(
      template => 'invoice/remind/index',
      format => 'js',
      mild_message => $mild_message,
      tough_message => $tough_message,
    );

    return $self->render(
      template => 'invoice/remind/index',
      layout => 'modal',
      web => $web,
      title => $title,
      reminder_count => $reminder_count,
      invoice => $data->{invoice},
      customer => $data->{customer}
    );
  }

  return $self->render(json => { error => $self->app->__('Invalid request') }, status => 400);
}


# Resend an invoice email (no rendering of PDF)
sub resend ($self) {
  # Require admin access for invoice operations
  return unless $self->access({ admin => 1 });

  my $invoiceid = int $self->stash('invoiceid') // $self->param('invoiceid') // 0;

  unless ($invoiceid) {
    return $self->render(json => { error => $self->app->__('Invalid invoice ID') }, status => 400);
  }

  # Return HTML template if not JSON request
  my $accept = $self->req->headers->{headers}->{accept}->[0] // '';
  if ($accept !~ /json/) {
    my $title = $self->app->__('Resend invoice');
    my $web = { title => $title };
    $web->{script} = $self->render_to_string(template => 'invoice/resend/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'invoice/resend/index');
  }

  # Get invoice and customer data from model
  my $invoicedata = $self->app->invoice->get_invoice_and_customer($invoiceid);
  if ($invoicedata->{error}) {
    return $self->render(json => { error => $invoicedata->{error} }, status => $invoicedata->{status});
  }
  my $invoice = $invoicedata->{invoice};
  my $customer = $invoicedata->{customer};


  # Calculate all invoice amounts using model method
  my $invoiceitems = $self->app->invoice->invoiceitems({ where => { 'invoice.invoiceid' => $invoiceid } });
  my $amounts = $self->invoice->calculate_amounts(
    $invoiceitems,
    $invoice->{vat},
    $invoice->{currency}
  );

  # Update invoice with calculated amounts
  $invoice->{net_amount} = $amounts->{net_amount};
  $invoice->{vatcost} = $amounts->{vatcost};
  $invoice->{totalcost} = $amounts->{totalcost};
  $invoice->{diff} = $amounts->{diff};

  # Set language based on customer billing language preference
  my $lang = $customer->{billinglang} || $customer->{lang} || $self->config->{locale}->{default_language} || 'sv';
  $self->app->language($lang);


  # Add formatted VAT percentage for email template
  my $vat_decimal = $invoice->{vat} // $customer->{vat};
  $invoicedata->{vat} = $self->app->invoice->formatvat($vat_decimal) if defined $vat_decimal;

  # Send the invoice email using the plugin helper
  my $email_result = $self->send_invoice_email($invoicedata, { action => 'resend' });

  if (!$email_result->{success}) {
    return $self->render(json => {success => 0, error => $email_result->{error} || $self->app->__('Failed to resend invoice email')}, status => 500);
  }

  # Update last sent timestamp
  eval {
#    $self->app->invoice->updateinvoice($invoiceid, { lastsentdate => \'NOW()' });
  };

#  $self->app->log->info("Resent invoice $invoiceid to customer " . $customer->{customerid});

  return $self->render(json => {
    success => 1,
    message => 'Invoice resent successfully',
    invoiceid => $invoiceid,
    customerid => $customer->{customerid},
    customer => $customer->{name}
  });
}


sub reprint ($self) {
  # Require admin access for invoice operations
  return unless $self->access({ admin => 1 });

  my $invoiceid = int $self->stash('invoiceid') // 0;
  my $customerid = int $self->stash('customerid') // 0;

  unless ($invoiceid) {
    return $self->render(json => { error => $self->app->__('Invalid invoice ID') }, status => 400);
  }

  # Return HTML template if not JSON request
  my $accept = $self->req->headers->{headers}->{accept}->[0] // '';
  if ($accept !~ /json/) {
    my $title = $self->app->__('Reprint invoice');
    my $web = { title => $title };
    $web->{script} = $self->render_to_string(template => 'invoice/reprint/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'invoice/reprint/index');
  }

  # Process invoice (fetches data, generates PDF)
  my $result = $self->process_invoice($invoiceid, $customerid);

  if ($result->{error}) {
    $self->app->log->error("Cannot reprint invoice $invoiceid - " . $result->{error});
    return $self->render(json => {
      success => 0,
      error => $result->{error}
    }, status => $result->{status} || 500);
  }

  if ($result->{pdf}) {
    $self->app->log->info("Successfully reprinted invoice $invoiceid (UUID: " . $result->{invoice}->{uuid} . ")");
    return $self->render(json => {
      success => 1,
      message => 'Invoice reprinted successfully',
      invoiceid => $invoiceid,
      customerid => $result->{customer}->{customerid},
      customer => $result->{customer}->{name},
      uuid => $result->{invoice}->{uuid}
    });
  } else {
    $self->app->log->error("Failed to regenerate PDF for invoice $invoiceid");
    return $self->render(json => {success => 0, error => $self->app->__('Failed to regenerate invoice PDF')}, status => 500);
  }
}


sub _formdata ($self) {
  my $invoiceid = int $self->param('invoiceid') || return 0;
  my $customerid = int $self->param('customerid') || return 0;
  my $formdata = {
    invoice      => { invoiceid  => $invoiceid, customerid => $customerid, totalcost => 0 },
    invoiceitems => {},
    customer     => { customerid => $customerid },
    articles     => $self->_articles(),
  };
  my $result = $self->req->params->to_hash;
  my $regexp = join '|', @$fields;
  $regexp = qr/($regexp)_(.+)/;
  for my $key (keys %$result) {
    if ($key =~ $regexp) {
      $formdata->{invoiceitems}->{$2}->{$1} = $result->{$key};
    }
    if ($key =~ /^(billing(email|address|zip|country|lang))$/) {
      $formdata->{customer}->{$key} = $result->{$key};
    }
  }
  # Unchecked checkboxes need extra handling
  for my $invoiceitemid (keys %{$formdata->{invoiceitems}}) {
    $formdata->{invoiceitems}->{$invoiceitemid}->{price} =~ s/\,/./;
    $formdata->{invoiceitems}->{$invoiceitemid}->{number} =~ s/\,/./;
    if (!exists($formdata->{invoiceitems}->{$invoiceitemid}->{include})) {
      $formdata->{invoiceitems}->{$invoiceitemid}->{include} = 0;
    }
  }
  return $formdata;
}


sub _articles ($self) {
  # Check if Fortnox plugin is loaded
  if (!$self->app->fortnox) {
    return [];
  }

  my $articles = $self->app->fortnox->getArticle();

  # Ensure we have a valid response
  if (!defined $articles) {
    return [];
  }

  # Check for API errors
  if (ref($articles) eq 'HASH' && exists($articles->{error}) && $articles->{error}) {
    # Store error in stash for display to user
    $self->stash(fortnox_error => $articles->{message} // 'Failed to fetch articles from Fortnox');
    return [];
  }

  if (ref($articles) eq 'HASH' && exists $articles->{Articles}) {
    $articles = $articles->{Articles};
  } else {
    $articles = [];
  }

  # Ensure we always return an array ref
  return ref($articles) eq 'ARRAY' ? $articles : [];
}


1;