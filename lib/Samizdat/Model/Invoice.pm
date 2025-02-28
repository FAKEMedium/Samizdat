package Samizdat::Model::Invoice;

use Mojo::Base -base, -signatures;

use Mojo::Util qw(trim);
use Mojo::JSON qw(decode_json encode_json);
use Data::Dumper;

has 'app';


sub get ($self, $params = {}) {
  my $db = $self->app->mysql->db;
  my $where = $params->{where} // {};
  my $limit = $params->{limit} // {};
  my $due = sprintf("IF((DATEDIFF(NOW(), invoicedate) > (%d + %d)) AND (state = 'fakturerad'), 1, 0) AS due",
    $self->app->config->{roomservice}->{invoice}->{duedays} // 30,
    $self->app->config->{roomservice}->{invoice}->{duedaysremind} // 10
  );
  my $duedate = sprintf("IF(state = 'fakturerad', DATE_FORMAT(DATE_ADD(invoicedate, INTERVAL %d DAY), '%%Y-%%m-%%d', 'CET'), 0) AS duedate",
    $self->app->config->{roomservice}->{invoice}->{duedays} // 30
  );
  my $invoices = $db->select('invoice', "*, $due, $duedate", $where, $limit)->hashes;
  return $invoices;
}

sub nextnumber ($self) {
  my $db = $self->app->mysql->db;
  my $nextnumber = $db->select('invoice', "MAX(fakturanummer) AS nextnumber")->hash->{nextnumber};
  my $currentyear = (localtime(time))[5] + 1900;
  if (substr($nextnumber, 0, 4) ne $currentyear) {
    $nextnumber = $currentyear . qq!00001!;
  } else {
    $nextnumber++;
  }
  return $nextnumber;
}

sub nav ($self, $to = 'next', $invoiceid = 0, $customerid = 0) {
  my $db = $self->app->mysql->db;
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
  $where->{state} = { '=' => ['fakturerad','bokford','raderad'] };

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
  $where->{fakturanummer} = { $sign => $invoice->{fakturanummer} };
  $results = $db->select('invoice', '*', $where, $orderby);
  while (my $result = $results->hash) {
    $results->finish;
    return $result;
    last; # LIMIT isn't available
  }

  return $invoice;
}


sub newinvoice ($self) {

}


sub products ($self, $params = {}) {
  my $db = $self->app->mysql->db;
  my $where = $params->{where} // {};
  my $limit = $params->{limit} // {};
  my $products = $db->select('product', '*', $where, $limit)->hashes;
  return $products;
}

sub subscriptions ($self, $params = {}) {
  my $db = $self->app->mysql->db;
  my $where = $params->{where} // {};
  my $limit = $params->{limit} // {};

  my $subscriptions = $db->select(['subscription', ['product', 'productid' => 'productid']],
    'product.*', $where, $limit)->hashes;
  return $subscriptions;
}

sub updatesubscription ($self, $customerid = 0, $productid = 0) {
  return 0 if (! int $customerid);
  return 0 if (! int $productid);
  my $db = $self->app->mysql->db;
  my $where = {customerid => $customerid, productid => $productid};
  return $db->update('subscription', {lastinvoice => 'NOW()'}, $where);
}

sub invoiceitems ($self, $params = {}) {
  my $db = $self->app->mysql->db;
  my $where = $params->{where} // {};
  my $limit = $params->{limit} // {};
  my $options = {order_by => {-asc => 'invoiceitemid'}};
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
  my $db = $self->app->mysql->db;
  return $db->insert('invoice',
    {
      customerid => $customerid,
      state      => 'obehandlad',
      vat        => $customer->{vat},
      currency   => $customer->{currency},
      costsum    => 0,
      debt       => 0
    },
    { returning => 'invoiceid' }
  )->hash->{invoiceid};
}


sub updateinvoice ($self, $invoiceid = 0, $invoicedata = {}) {
  return 0 if (! int $invoiceid);
  delete $invoicedata->{duedate};
  delete $invoicedata->{pdfdate};
  delete $invoicedata->{due};

  my $db = $self->app->mysql->db;
  my $where = {invoiceid => $invoiceid};
  return $db->update('invoice', $invoicedata, $where);
}

sub updateinvoiceitem ($self, $invoiceitemid = 0, $invoiceitem = {}) {
  return 0 if (! int $invoiceitemid);
  my $db = $self->app->mysql->db;
  my $where = {invoiceitemid => $invoiceitemid};
  return $db->update('invoiceitem', $invoiceitem, $where);
}

sub addinvoiceitem ($self, $invoiceitem = {}, $invoiceid = 0) {
  my $db = $self->app->mysql->db;
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
  my $db = $self->app->mysql->db;
  my $where = $params->{where} // {};
  my $limit = $params->{limit} // {};
  my $invoicepayments = $db->select('payments', '*', $where, $limit)->hashes;
  return $invoicepayments;
}

sub addpayment ($self, $payment = {}) {
  my $db = $self->app->mysql->db;
  return 0 if (!exists($payment->{invoiceid}) || (0 == int $payment->{invoiceid}));

  # Less than 1 currency is not an allowed payment
  return 0 if (!exists($payment->{amount}) || (0 == int $payment->{amount}));

  return $db->insert('payments', $payment, {returning => 'paymentid'});
}
1;