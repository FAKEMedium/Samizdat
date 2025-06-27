package Samizdat::Controller::Fortnox;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Data::Dumper;


sub redirect ($self) {
  $self->redirect_to($self->app->config->{managerurl});
}


sub auth ($self) {
  my $state = $self->param("state") // '';
  my $code = $self->param("code") // '';
  $self->app->fortnox->cache->{state} = $state if (!$state);
  $self->app->fortnox->cache->{code} = $code if ($code);
  if ('' ne $self->app->fortnox->cache->{access}) {

  } elsif ('' ne $self->app->fortnox->cache->{refresh}) {
    $self->app->fortnox->getToken(1);
  } elsif ('' ne $self->app->fortnox->cache->{code}) {
    $self->app->fortnox->getToken(0);
  } else {
    my $redirect = $self->app->fortnox->getLogin();
    say $redirect;
    return $self->redirect_to($redirect);
  }
  $self->redirect_to(sprintf('%s', $self->app->config->{managerurl}));
}

sub customers ($self) {
  my $title = $self->app->__('Customers');
  my $web = { title => $title };
  my $customerid = int $self->stash('customerid') // 0;
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    if ($customerid) {
      $web->{script} .= $self->render_to_string(format => 'js', template => 'fortnox/manager/customers/single/index');
      return $self->render(web => $web, title => $title, template => 'fortnox/manager/customers/single/index', layout => 'modal');
    } else {
      $web->{script} .= $self->render_to_string(format => 'js', template => 'fortnox/manager/customers/index');
      return $self->render(web => $web, title => $title, template => 'fortnox/manager/customers/index');
    }
  } else {
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

sub payments ($self) {
  my $title = $self->app->__('Payments');
  my $web = { title => $title };
  my $number = int $self->stash('number') // 0;
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    if ($number) {
      $web->{script} .= $self->render_to_string(format => 'js', template => 'fortnox/manager/payments/single/index');
      return $self->render(web => $web, title => $title, template => 'fortnox/manager/payments/single/index', layout => 'modal');
    } else {
      $web->{script} .= $self->render_to_string(format => 'js', template => 'fortnox/manager/payments/index');
      return $self->render(web => $web, title => $title, template => 'fortnox/manager/payments/index');
    }
  } else {
    my $invoiceid = int $self->param('invoiceid') // 0;
    my $options = {'qp' => {'limit' => 100, page => 1}};
    if ($invoiceid) {
      $options->{qp}->{invoicenumber} = $invoiceid;
    }
    my $payment = $self->app->fortnox->getInvoicePayment($number, $options);
    my $fortnox = {
      title    => $title,
    };
    $fortnox->{payment} = $payment;
    return $self->render(json => { fortnox => $fortnox });
  }
}

sub logout ($self) {
  $self->app->fortnox->removeCache;
  $self->redirect;
}

sub _login ($self) {
  say $self->app->config->{managerurl};
  $self->redirect_to(sprintf('%s%s', $self->app->config->{managerurl}, 'fortnox/auth'));
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
  my $title = $self->app->__('Activate Samizdat Fortnox integration');
  my $web = { title => $title };
  my $formdata = {};
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    $web->{script} .= $self->render_to_string(format => 'js', template => 'fortnox/activate/index');
    return $self->render(web => $web, title => $title, formdata => $formdata, template => 'fortnox/activate/index');
  } else {
    my $config = $self->app->config->{roomservice}->{fortnox};
    return $self->render(json => { formdata => $formdata });
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
