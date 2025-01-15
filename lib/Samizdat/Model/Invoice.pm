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

  my $invoices = $db->select('invoice', "*, $due", $where, $limit)->hashes;
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
      costsum    => 0
    },
    { returning => 'invoiceid' }
  )->hash->{invoiceid};
}


sub updateinvoice ($self, $invoiceid =  0, $invoicedata = {}) {
  return 0 if (! int $invoiceid);
  delete $invoicedata->{duedate};
  delete $invoicedata->{pdfdate};
  delete $invoicedata->{due};

  my $db = $self->app->mysql->db;
  my $where = {invoiceid => $invoiceid};
  return $db->update('invoice', $invoicedata, $where);
}

sub updateinvoiceitem ($self, $invoiceitemid =  0, $invoiceitem = {}) {
  return 0 if (! int $invoiceitemid);
  my $db = $self->app->mysql->db;
  my $where = {invoiceitemid => $invoiceitemid};
  return $db->update('invoiceitem', $invoiceitem, $where);
}

sub addinvoiceitem ($self, $invoiceitem = {}) {
  my $db = $self->app->mysql->db;
  return 0 if (!exists($invoiceitem->{customerid}) || (0 == int $invoiceitem->{customerid}));
  delete $invoiceitem->{invoiceitemid};
  delete $invoiceitem->{invoiceid}; # Only one open invoice per customer
  my $invoiceid = int $db->select('invoice', "invoiceid", { state => 'obehandlad', customerid => $invoiceitem->{customerid}})
    ->hash
    ->{invoiceid};
  return 0 if (!$invoiceid);
  $invoiceitem->{invoiceid} = $invoiceid;
  return $db->insert('invoiceitem', $invoiceitem, {returning => 'invoiceitemid'});
}

sub invoicepayments ($self, $params = {}) {
  my $db = $self->app->mysql->db;
  my $where = $params->{where} // {};
  my $limit = $params->{limit} // {};
  my $invoicepayments = $db->select('invoicepayment', '*', $where, $limit)->hashes;
  return $invoicepayments;
}

1;