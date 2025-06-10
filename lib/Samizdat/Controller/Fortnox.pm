package Samizdat::Controller::Fortnox;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Data::Dumper;


sub redirect ($self) {
  $self->redirect_to($self->app->{config}->{managerurl});
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
#    say $redirect;
    return $self->redirect_to($redirect);
  }
  $self->redirect_to(sprintf('%s', $self->app->config->{managerurl}));
}


sub customer ($self) {
  my $customerid = int $self->param('customerid');
  my $title = $self->app->__x('Edit customer {customerid}', customerid => $customerid);
  my $customer = $self->app->fortnox->getCustomer($customerid);
  if (404 == $customer) {
    return $self->render(template => 'not_found', status => 404);
  } elsif (403 == $customer) {
    return $self->_login;
  }
  if (exists($customer->{Customer})) {
    $customer = $customer->{Customer};
    say Dumper $customer;

    $self->stash(
      fc       => $customer,
      template => 'fortnox/manager/customer'
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
  $self->app->fortnox->removeCache;
  $self->redirect;
}

sub _login ($self) {
  $self->redirect_to(sprintf('%s%s', $self->app->{config}->{managerurl}, 'fortnox/auth'));
}

sub index ($self) {
  my $title = $self->app->__('Samizdat Fortnox integration');
  my $web = { title => $title };

  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    $web->{script} .= $self->render_to_string(template => 'fortnox/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'fortnox/index');
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
    $web->{script} .= $self->render_to_string(template => 'fortnox/manager/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'fortnox/manager/index');
  } else {
    $fortnox->{archive} = $self->app->fortnox->getArchive();
    return $self->render(json => { fortnox => $fortnox });
  }
}


sub activate ($self) {
  my $title = $self->app->__('Activate Samizdat Fortnox integration');
  my $web = { title => $title };

  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    $web->{script} .= $self->render_to_string(template => 'fortnox/activate/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'fortnox/activate/index');
  }
}


sub start ($self) {
  my $title = $self->app->__('Activate Samizdat Fortnox integration');
  my $web = { title => $title };

  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    $web->{script} .= $self->render_to_string(template => 'fortnox/start/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'fortnox/start/index');
  }
}


1;
