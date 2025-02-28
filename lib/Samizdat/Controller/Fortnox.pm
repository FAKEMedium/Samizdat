package Samizdat::Controller::Fortnox;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Data::Dumper;


sub __auth ($self) {
  return $self->oauth2->get_token_p('fortnox' => {state => 'login'})->then(sub {
    return unless my $provider_res = shift;
    $self->session(token => $provider_res->{access_token});
    $self->redirect_to('fortnox');
  })->catch(sub {
    $self->render('connect', error => shift);
  });
}


sub redirect ($self) {
  $self->redirect_to(sprintf('%s', $self->app->{config}->{managerurl}));
}


sub auth ($self) {
  $self->cache->{'bok'}->{'state'} = $self->param("state") if ($self->param("state"));
  $self->cache->{'bok'}->{'code'} = $self->param("code") if ($self->param("code"));

  if ('' ne $self->cache->{'bok'}->{'access'}) {

  } elsif ('' ne $self->cache->{'bok'}->{'refresh'}) {
    $self->getToken('bok', 1);
  } elsif ('' ne $self->cache->{'bok'}->{'code'}) {
    $self->getToken('bok', 0);
  } else {
    my $redirect = $self->getLogin('bok');
    say $redirect;
    return $self->redirect_to($redirect);
  }
  $self->redirect_to(sprintf('%s', $self->app->{config}->{managerurl}));
}

sub work ($self) {
  my $web = {};

  for my $resource (keys %{ $self->config->{apps}->{bok}->{resources} }) {
    say $resource;
    $web->{$resource} = $self->callAPI('bok', $resource, 'get');
  }
  $self->render(web => $web, title => 'Lista');
}


sub postinvoice ($self) {
  my $customerid = $self->param('customerid') // $self->config->{test}->{customerid};
  my $customer = $self->customer->fetch($customerid);
  my $invoicerows =  [
    {
      Description   => $self->app->__('Domain registration'),
      Price         => '180',
      ArticleNumber => '3310'
    }
  ];
  my $result = $self->invoices->post($customer, $invoicerows);

  my $web = {
    main => Dumper($result)
  };
  $self->render(web => $web, title => 'Faktura');
}


sub printpdf ($self) {
  my $data = {
    customer => '',
    invoice  => {
      items => []
    }
  };
#  my $pdf = $self->printPDF('invoice', $data);
  $self->render();
}


sub test ($self) {
  my $web = {
    main => Dumper($self->cache)
  };
  $self->render(web => $web, title => 'Dump');
}


sub listinvoices ($self) {
  my $invoices = $self->invoices->get({ state => 'fakturerad'});
  my $web = {
    main     => '',
    invoices => $invoices,
  };
  $self->render(web => $web, title => 'Faktura');
}

sub customer ($self) {
  my $customerid = int $self->param('customerid');
  my $title = $self->app->__x('Edit customer {customerid}', customerid => $customerid);
  my $customer = $self->app->fortnox->getCustomer($customerid);
  if (404 == $customer) {
    return $self->render(template => 'not_found', status => 404);
  }
  if (exists($customer->{Customer})) {
    $customer = $customer->{Customer};
    say Dumper $customer;

    $self->stash(
      fc       => $customer,
      template => 'fortnox/customer'
    );
    my $web = { title => $title };
    $self->render(
      title => $title,
      web   => $web,
    );
  } else {
    return $self->_login;
  }
}

sub logout ($self) {
  $self->app->removeCache;
  $self->redirect;
}

sub _login ($self) {
  $self->redirect_to(sprintf('%s%s', $self->app->{config}->{managerurl}, 'fortnox/auth'));

}

sub index ($self) {
  my $web = {
    main     => '',
  };
  $self->render(web => $web, title => 'Fortnox');}

1;
