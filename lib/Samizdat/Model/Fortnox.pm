package Samizdat::Model::Fortnox;

use strict;
use warnings FATAL => 'all';
use Mojo::Base -base, -signatures;
use Mojo::JSON qw(decode_json);

has 'app';

sub _getAuthorizationCode ($self) {

}

sub _getToken ($self) {

}

sub _getAccessToken ($self) {

}

sub _getRefreshToken ($self) {

}

sub _revokeAccessToken ($self) {

}

sub _request ($self) {

}

sub list ($self, $what) {
  return 1;
}

sub get ($self, $what, $id) {
  return 1;
}

sub delete ($self, $what, $id) {
  return 1;
}

sub update ($self, $what, $id, $data) {
  return 1;
}

sub login ($self) {

}


sub postInvoice ($self, $customer, $invoicerows =  []) {
  my $payload = {
    Invoice => {
      'CustomerNumber' => "$customer->{customerid}",
      'InvoiceRows'    => $invoicerows,
      'InvoiceType'    => 'INVOICE',
      'Language'       => uc substr($customer->{lang}, 0, 2)
    }
  };
  my $result = $self->app->callAPI('bok', 'Invoices', 'post', 0, $payload);
}

sub getInvoice ($self, $DocumentNumber = 0, $options = {'qp' => {'limit' => 500, page => 1}}) {
  my $list = $self->app->callAPI('bok', 'Invoices', 'get', $DocumentNumber, $options);
}

sub putInvoice ($self, $DocumentNumber = 0) {
  return 0 if (!$DocumentNumber);
  my $result = $self->app->callAPI('bok', 'Invoices', 'put', $DocumentNumber);
}

sub listInvoice ($self, $where = {}, $order =  {}) {
  $self->app->mysql->db->select("systems.invoice", '*', $where, $order)->hashes;
}

sub getCustomer ($self, $CustomerNumber = 0, $options = {'qp' => {'limit' => 500, page => 1}}) {
  my $result = $self->app->callAPI('bok', 'Customers', 'get', $CustomerNumber, $options);
}

sub putCustomer ($self, $CustomerNumber, $data = {}) {
  my $result = $self->app->callAPI('bok', 'Customers', 'put', $CustomerNumber, $data);
}

sub postCustomer ($self, $data =  {}) {
  my $result = $self->app->callAPI('bok', 'Customers', 'post', 0, $data);
}

sub deleteCustomer ($self, $CustomerNumber) {
  my $result = $self->app->callAPI('bok', 'Customers', 'delete', $CustomerNumber);
}

sub putCurrency ($self, $Currency, $data = {}) {
  my $result = $self->app->callAPI('bok', 'Currencies', 'put', $Currency, $data);
}

sub getCurrency ($self, $Currency = 0, $options = {'qp' => {'limit' => 500, page => 1}}) {
  my $result = $self->app->callAPI('bok', 'Currencies', 'get', $Currency, $options);
}

sub postCurrency ($self, $data = {}) {
  my $result = $self->app->callAPI('bok', 'Currencies', 'post', 0, $data);
}

sub getAccount ($self, $Number = 0, $options = {'qp' => {'limit' => 500, page => 1}}) {
  my $result = $self->app->callAPI('bok', 'Accounts', 'get', $Number, $options);
}

sub getArticle ($self, $ArticleNumber = 0, $options = {'qp' => {'limit' => 500, page => 1}}) {
  my $result = $self->app->callAPI('bok', 'Articles', 'get', $ArticleNumber, $options);
}

sub postArticle ($self, $article) {
  my $payload = {
    Article => {
      'ArticleNumber' => $article->{number},
      'Description'   => $article->{description},
      'Type'          => 'SERVICE',
#      'SalesAccount'  => $article->{account},
#      'EUVATAccount'  => $article->{euvataccount},
#      'ExportAccount'  => $article->{exportaccount},
    }
  };
  my $result = $self->app->callAPI('bok', 'Articles', 'post', 0, $payload);
}
1;