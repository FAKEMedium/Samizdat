package Samizdat::Model::Customer;

use Mojo::Base -base, -signatures;
use Mojo::Util qw(trim);
use Data::Dumper;

has 'app';

sub eucountries ($self) {
  return [qw(AT BE BG CY CZ DE DK EE ES FI FR EL HR HU IE IT LI LV LT LU MT NL PL PT RO SE SI SK)];
}

sub get ($self, $params = {}) {
  my $db = $self->app->mysql->db;
  my $where = $params->{where} // {};
  my $limit = $params->{limit} // {};
  my $customers = [];
  $db->select('customer', '*', $where, $limit)->hashes->each( sub($customer, $num) {
    $customer->{billingemail} = $customer->{contactemail} if ('' eq $customer->{billingemail});
    $customer->{billingcity} = $customer->{city} if ('' eq $customer->{billingcity});
    $customer->{billingzip} = $customer->{zip} if ('' eq $customer->{billingzip});
    $customer->{billingaddress} = $customer->{address} if ('' eq $customer->{billingaddress});
    $customer->{billingcountry} = $customer->{country} if ('' eq $customer->{billingcountry});
    $customer->{billinglang} = $customer->{lang} if ('' eq $customer->{billinglang});

    push @$customers, $customer;
  });
  return $customers;
}

sub name ($self, $customer) {
  my $name = trim $customer->{company};
  if ('' eq $name) {
    $name = trim(sprintf('%s %s', $customer->{firstname}, $customer->{lastname}));
  }
  $name =~ s/ {2,}/ /g;
  return $name;
}

sub add ($self, $customer) {

}

sub update ($self, $customerid = 0, $customer =  {}) {
  return 0 if (!$customerid);
  my $db = $self->app->mysql->db;
  my $where = {customerid => $customerid};
  return $db->update('customer', $customer, $where);
}

sub delete ($self, $customerid) {

}

sub archive ($self, $customerid) {

}

sub databases ($self, $params =  {}) {
  my $db = $self->app->mysql->db;
  my $where = $params->{where} // {};
  return $db->select('databases', '*', $where)->hashes;
}

sub sites ($self, $params =  {}) {
  my $db = $self->app->mysql->db;
  my $where = $params->{where} // {};
  return $db->select('Domain', '*', $where)->hashes;
}

sub userlogins ($self, $params =  {}) {
  my $db = $self->app->mysql->db;
  my $where = $params->{where} // {};
  return $db->select('snapusers', '*', $where)->hashes;
}

sub neighbours ($self, $customerid) {
  my $db = $self->app->mysql->db;
  my ($minid, $maxid) = @{$db->query(
    'SELECT MIN(customerid) AS minid, MAX(customerid) AS maxid FROM customer WHERE active = 1'
  )->array};
  my $neighbours = {
    minid => $minid,
    maxid => $maxid,
  };
  $neighbours->{nextid} = $minid;
  my $results = $db->query(
    'SELECT customerid AS nextid FROM customer WHERE active = 1 AND (customerid > ?) ORDER BY customerid ASC LIMIT 1',
    $customerid
  );
  while (my $next = $results->array) {
    $neighbours->{nextid} = $next->[0];
  }
  $neighbours->{previd} = $maxid;
  $results = $db->query(
    'SELECT customerid AS previd FROM customer WHERE active = 1 AND (customerid < ?) ORDER BY customerid DESC LIMIT 1',
    $customerid
  );
  while (my $next = $results->array) {
    $neighbours->{previd} = $next->[0];
  }
  return $neighbours;
}



1;