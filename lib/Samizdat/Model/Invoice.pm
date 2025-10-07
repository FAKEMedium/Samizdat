package Samizdat::Model::Invoice;

use Mojo::Base -base, -signatures;

use Mojo::Util qw(trim);
use Mojo::JSON qw(decode_json encode_json);
use Date::Format;
use Data::Dumper;

has 'config';
has 'pg';
has 'mysql';
has 'customer';  # Customer model helper

sub get ($self, $params = {}) {
  my $db = $self->mysql->db;
  my $where = $params->{where} // {};
  my $limit = $params->{limit} // {};
  my $due = sprintf("IF((DATEDIFF(NOW(), invoicedate) > (%d + %d)) AND (state = 'fakturerad'), 1, 0) AS due",
    $self->config->{duedays} // 30,
    $self->config->{duedaysremind} // 10
  );
  my $duedate = sprintf("IF(state = 'fakturerad', DATE_FORMAT(DATE_ADD(invoicedate, INTERVAL %d DAY), '%%Y-%%m-%%d', 'CET'), 0) AS duedate",
    $self->config->{duedays} // 30
  );

  # Add subqueries for reminder information
  my $lastreminderdate = "(SELECT MAX(reminderdate) FROM invoicereminder WHERE invoicereminder.invoiceid = invoice.invoiceid) AS lastreminderdate";
  my $remindercount = "(SELECT COUNT(*) FROM invoicereminder WHERE invoicereminder.invoiceid = invoice.invoiceid) AS remindercount";

  my $invoices = $db->select('invoice', "*, $due, $duedate, $lastreminderdate, $remindercount", $where, $limit)->hashes;
  return $invoices;
}

sub nextnumber ($self) {
  my $db = $self->mysql->db;
  my $nextnumber = $db->select('invoice', "MAX(fakturanummer) AS nextnumber")->hash->{nextnumber};
  my $currentyear = (localtime(time))[5] + 1900;
  if (substr($nextnumber, 0, 4) ne $currentyear) {
    $nextnumber = $currentyear . qq!00001!;
  } else {
    $nextnumber++;
  }
  return $nextnumber;
}

sub nav ($self, $to = 'next', $invoiceid = 0, $customerid = 0, $states = undef) {
  my $db = $self->mysql->db;
  my $sign = '>';
  my $orderby = { '-asc' => 'fakturanummer' };
  if ('prev' eq $to) {
    $sign = '<';
    $orderby = { '-desc' => 'fakturanummer' };
  }

  my $where = {};
  $invoiceid = int $invoiceid;
  $where->{invoiceid} = $invoiceid if ($invoiceid);
  $where->{customerid} = $customerid if ($customerid);

  # Use provided states or default
  if ($states && @$states) {
    $where->{state} = { '=' => $states };
  } else {
    $where->{state} = { '=' => ['fakturerad','bokford','raderad'] };
  }

  my $invoice = {};
  my $results = $db->select('invoice', '*', $where);
  while (my $result = $results->hash) {
    $invoice = $result;
    my $fakturanummer = int $invoice->{fakturanummer};
    delete $where->{invoiceid};
    if ('prev' eq $to) {
      $fakturanummer--;
    } else {
      $fakturanummer++;
    }
    $where->{fakturanummer} = $fakturanummer;
    $results->finish;
    last;
  }
  # Try the adjacent invoice number first
  $results = $db->select('invoice', '*', $where);
  while (my $result = $results->hash) {
    $results->finish;
    return $result;
  }

  # Then try comparing/sorting
  if ($invoice->{fakturanummer}) {
    $where->{fakturanummer} = { $sign => $invoice->{fakturanummer} };
    $results = $db->select('invoice', '*', $where, $orderby);
    while (my $result = $results->hash) {
      $results->finish;
      return $result;
      last; # LIMIT isn't available
    }
  }

  return $invoice;
}


sub newinvoice ($self) {

}


sub products ($self, $params = {}) {
  my $db = $self->mysql->db;
  my $where = $params->{where} // {};
  my $limit = $params->{limit} // {};
  my $products = $db->select('product', '*', $where, $limit)->hashes;
  return $products;
}

sub subscriptions ($self, $params = {}) {
  my $db = $self->mysql->db;
  my $where = $params->{where} // {};
  my $limit = $params->{limit} // {};

  my $subscriptions = $db->select(['subscription', ['product', 'productid' => 'productid']],
    'product.*', $where, $limit)->hashes;
  return $subscriptions;
}

sub updatesubscription ($self, $customerid = 0, $productid = 0) {
  return 0 if (! int $customerid);
  return 0 if (! int $productid);
  my $db = $self->mysql->db;
  my $where = {customerid => $customerid, productid => $productid};
  return $db->update('subscription', {lastinvoice => \['NOW()']}, $where);
}

sub invoiceitems ($self, $params = {}) {
  my $db = $self->mysql->db;
  my $where = $params->{where} // {};
  my $limit = $params->{limit} // {};
  my $invoiceitems = {};
  $db->select(['invoiceitem', ['invoice', 'invoiceid' => 'invoiceid']], 'invoiceitem.*', $where, $limit)
    ->hashes
    ->each(
      sub($item, $num) {
        $invoiceitems->{ $item->{invoiceitemid} } = $item;
      }
    );
  return $invoiceitems;
}

sub addinvoice ($self, $customer =  {}) {
  my $customerid = 0;
  if (exists($customer->{customerid})) {
    $customerid = int $customer->{customerid};
  }
  return 0 if (!$customerid);
  my $db = $self->mysql->db;
  return $db->insert('invoice',
    {
      customerid => $customerid,
      state      => 'obehandlad',
      vat        => $customer->{vat},
      currency   => $customer->{currency},
      totalcost  => 0,
      debt       => 0
    },
    { returning => 'invoiceid' }
  )->hash->{invoiceid};
}


sub updateinvoice ($self, $invoiceid = 0, $invoicedata = {}) {
  return 0 if (! int $invoiceid);

  # Remove calculated/virtual fields that don't exist as actual columns
  delete $invoicedata->{duedate};
  delete $invoicedata->{pdfdate};
  delete $invoicedata->{due};
  delete $invoicedata->{lastreminderdate};
  delete $invoicedata->{remindercount};

  my $db = $self->mysql->db;
  my $where = {invoiceid => $invoiceid};
  return $db->update('invoice', $invoicedata, $where);
}

sub updateinvoiceitem ($self, $invoiceitemid = 0, $invoiceitem = {}) {
  return 0 if (! int $invoiceitemid);
  my $db = $self->mysql->db;
  my $where = {invoiceitemid => $invoiceitemid};
  return $db->update('invoiceitem', $invoiceitem, $where);
}

sub addinvoiceitem ($self, $invoiceitem = {}, $invoiceid = 0) {
  my $db = $self->mysql->db;
  return 0 if (!exists($invoiceitem->{customerid}) || (0 == int $invoiceitem->{customerid}));
  delete $invoiceitem->{invoiceitemid};
  if (!$invoiceid) {
    # Credited invoice items
    delete $invoiceitem->{invoiceid};
    $invoiceid = int $db->select('invoice', "invoiceid", { state => 'obehandlad', customerid => $invoiceitem->{customerid} })
      ->hash
      ->{invoiceid};
    return 0 if (!$invoiceid);
    $invoiceitem->{invoiceid} = $invoiceid;
  }
  return $db->insert('invoiceitem', $invoiceitem, {returning => 'invoiceitemid'});
}

sub payments ($self, $params = {}) {
  my $db = $self->mysql->db;
  my $where = $params->{where} // {};
  my $limit = $params->{limit} // {};
  my $invoicepayments = $db->select('invoicepayment', '*', $where, $limit)->hashes;
  return $invoicepayments;
}

sub addpayment ($self, $payment = {}) {
  my $db = $self->mysql->db;
  return 0 if (!exists($payment->{invoiceid}) || (0 == int $payment->{invoiceid}));

  # Less than 1 currency is not an allowed payment
  return 0 if (!exists($payment->{amount}) || (0 == int $payment->{amount}));

  return $db->insert('invoicepayment', $payment, {returning => 'paymentid'});
}


sub reminders ($self, $invoiceid = 0) {
  my $db = $self->mysql->db;
  $invoiceid = int $invoiceid;
  return [] if (!$invoiceid);
  my $where = { invoiceid => $invoiceid };
  my $invoicereminders = $db->select('invoicereminder', '*', $where)->hashes;
  return $invoicereminders;
}


sub addreminder ($self, $invoiceid =  0) {
  my $db = $self->mysql->db;
  $invoiceid = int $invoiceid;
  return 0 if (!$invoiceid);
  my $invoice = $self->get({ where => { invoiceid => $invoiceid }})->[0];
  return 0 if (!exists($invoice->{customerid}));
  return $db->insert('invoicereminder', {invoiceid => $invoiceid, customerid => $invoice->{customerid}}, {returning => 'reminderid'});
}


# Calculate invoice amounts (costs, VAT, rounding). Relevant fields for calculation are:
# invoiceitem has
#   -  price (without VAT)
#   -  number
#   -  include (0 = pass to new invoice,  > 0 means to include)
# invoice has
#   - totalcost (including vat, corrected for rounding off, no decimals for sek, 2 decimals for eur)
#   - vat (0 <= vat <= 1)
#   - currency (sek or eur)
sub calculate_amounts ($self, $invoiceitems, $invoice_vat, $invoice_currency) {
  my $vat = $invoice_vat // 0.25;  # Default 25% VAT (use // to allow 0% VAT)
  my $net_amount = 0.00;
  my $vatcost = 0.00;

  # Calculate cost sum (gross) and vat sum from invoice items
  # The loop is somewhat prepared for item specific VAT rates
  for my $item (values %{$invoiceitems}) {
    if ($item->{include}) {
      $net_amount += $item->{number} * $item->{price};
      $vatcost += $item->{number} * $item->{price} * $vat;
    }
  }

  # Rounding calculations based on currency
  my $diff = 0;
  my $totalcost = $vatcost + $net_amount;
  if ($invoice_currency && $invoice_currency =~ /(sek)/i) {
    # Swedish rounding rules - round to whole number
    if ($totalcost =~ /(\d+)[\.]{1}(\d+)/) {
      my $whole = $1;
      my $decimal = $2;
      if ($decimal =~ /^[5-9]/) {
        $totalcost = $whole + 1.0;
      } else {
        $totalcost = $whole;
      }
    }
  } else {
    # EUR and other currencies - keep 2 decimals
    $totalcost = sprintf("%.2f", $totalcost);
  }

  # Format diff
  $diff = sprintf("%.5f", $totalcost - $net_amount - $vatcost);
  $diff =~ s/(\.\d*?)0+$/$1/;
  $diff =~ s/\.$//;

  # Ensure amounts with exactly one decimal get a trailing zero
  $totalcost .= '0' if $totalcost =~ /^\d+\.\d$/;
  $net_amount .= '0' if $net_amount =~ /^\d+\.\d$/;
  $vatcost .= '0' if $vatcost =~ /^\d+\.\d$/;
  $diff .= '0' if $diff =~ /^\d+\.\d$/;

  return {
    totalcost => $totalcost,
    net_amount => $net_amount,
    vatcost => $vatcost,
    vat => $vat,
    vat_percent => $self->formatvat($vat),
    diff => $diff
  };
}


# Get full invoice data with customer and items
sub get_full_invoice ($self, $invoiceid) {
  my $invoice = $self->get({ where => { invoiceid => $invoiceid } })->[0];
  return undef unless $invoice;

  # Get invoice items
  my $items = $self->invoiceitems({ where => { 'invoice.invoiceid' => $invoiceid } });

  # Get reminders
  my $reminders = $self->reminders($invoiceid);

  # Get payments
  my $payments = $self->payments({ invoiceid => $invoiceid });

  return {
    invoice => $invoice,
    invoiceitems => $items,
    reminders => $reminders,
    payments => $payments
  };
}


# Generate next invoice number
sub generate_invoice_number ($self, $prefix = '') {
  my $nextnumber = $self->nextnumber();
  return $prefix . $nextnumber;
}


# Calculate due date based on invoice date
sub calculate_due_date ($self, $invoice_date = undef, $due_days = undef) {
  $invoice_date ||= time;
  $due_days ||= $self->config->{duedays} || 30;

  # If invoice_date is a string, convert to timestamp
  if ($invoice_date !~ /^\d+$/) {
    require Time::ParseDate;
    $invoice_date = Time::ParseDate::parsedate($invoice_date);
  }

  return time2str("%Y-%m-%d", $invoice_date + $due_days * 24 * 3600, 'CET');
}


# Check if invoice is overdue
sub is_overdue ($self, $invoice) {
  return 0 unless $invoice->{state} eq 'fakturerad';

  my $due_days = $self->config->{duedays} || 30;
  my $remind_days = $self->config->{duedaysremind} || 10;

  require Time::ParseDate;
  my $invoice_time = Time::ParseDate::parsedate($invoice->{invoicedate});
  my $days_elapsed = int((time - $invoice_time) / (24 * 3600));

  return $days_elapsed > ($due_days + $remind_days);
}


# Get invoice and customer data
sub get_invoice_and_customer ($self, $invoiceid, $customerid = undef) {
  # Get invoice details
  my $invoice = $self->get({ where => { invoiceid => $invoiceid } })->[0];
  return { error => 'Invoice not found', status => 404 } unless $invoice;

  # Get customer details using customer helper
  $customerid ||= $invoice->{customerid};
  my $customer = $self->customer->get({ where => { customerid => $customerid } })->[0];
  return { error => 'Customer not found', status => 404 } unless $customer;

  # Get customer name using customer helper method
  $customer->{name} = $self->customer->name($customer);

  return { invoice => $invoice, customer => $customer };
}


# Get invoice form data with related entities
sub get_invoice_formdata ($self, $invoiceid = undef, $customerid = undef, $options = {}) {
  $options //= {};
  $options->{includepayments} //= 1;
  $options->{includereminders} //= 1;

  my $args = {};

  # Determine which invoice to get
  if ($invoiceid) {
    $args->{where} = { invoiceid => $invoiceid };
    $args->{where}->{customerid} = $customerid if $customerid;
  } elsif ($customerid) {
    # Get open/unhandled invoice for customer
    $args->{where} = { state => 'obehandlad', customerid => $customerid };
  } else {
    return undef;  # Need either invoiceid or customerid
  }

  my $invoice = $self->get($args)->[0];
  return undef unless $invoice;

  $invoiceid = $invoice->{invoiceid};
  $customerid ||= $invoice->{customerid};

  # Get customer details
  my $customer = $self->customer->get({ where => { customerid => $customerid } })->[0];
  return undef unless $customer;

  $customer->{name} = $self->customer->name($customer);

  # Build formdata
  my $formdata = {
    customer     => $customer,
    invoice      => $invoice,
    invoiceitems => $self->invoiceitems({
      where => {
        'invoice.invoiceid' => $invoiceid,
        'invoice.customerid' => $customerid
      }
    }),
    payments     => [],
    reminders    => [],
  };

  # Include optional data
  if ($options->{includepayments}) {
    $formdata->{payments} = $self->payments({ where => { invoiceid => $invoiceid } });
  }

  if ($options->{includereminders}) {
    $formdata->{reminders} = $self->reminders($invoiceid);
  }

  return $formdata;
}


sub url ($self, $invoice = {}) {
  my $url = $self->config->{invoiceurl};
  my $siteurl = '';
  $url .= '/';
  if (exists($invoice->{uuid})) {
    $url .= $invoice->{uuid} . '.pdf';
  }
  $url =~ s/[\/]{1,}http\:\/\//http\:\/\//;
  if ($url =~ s/^(http\:\/\/)//) {
    $siteurl = $1;
  }
  $url =~ s/[\/]{2,}/\//g;
  return $siteurl . $url;
}


sub formatvat ($self, $vat_decimal) {
  return '0' unless defined $vat_decimal;

  my $vat_percent = $vat_decimal * 100;
  $vat_percent =~ s/[0]+$// if ($vat_percent =~ /\./);
  if ($vat_percent =~ /(\d+)[\.]{1}([\d]{1,2})$/) {
    $vat_percent = sprintf("%.2f", $vat_percent);
  }
  $vat_percent =~ s/\.$//;

  return $vat_percent;
}


1;