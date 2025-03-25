package Samizdat::Controller::Customer;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Business::Tax::VAT::Validation;
use Data::Dumper;

my $scriptname = 'customers';
my $fields = [qw(customerid company firstname lastname address zip city contactemail country orgno phone1 phone2 freetext)];
push @{$fields}, qw(reference recommendedby period currency invoicetype lang trust vatno vat);
my $checkfields = [qw(snapbackonly newsletter moss)];
my $setfields = [qw(created creator updated updater)];

sub index ($self) {
  $self->stash(scriptname => $scriptname);
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    my $title = $self->app->__('Customers');
    my $web = { title => $title };
    $web->{docpath} = sprintf('%s%s/index.html', $self->config->{managerurl}, $scriptname);
    $web->{script} .= $self->render_to_string(template => 'customer/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'customer/index', customers => [], status => 200);

  } else {
    my $searchterm = $self->param('searchterm');
    my $params = {};
    if ('moss' eq $searchterm) {
      $params->{where} = { moss => 1 };
    } elsif ('blocked' eq $searchterm) {
      $params->{where} = { trust => 'blocked' };
    } elsif ('' ne $searchterm) {
      $params->{where} = [
        customerid   => [ int $searchterm ],
        firstname    => { -like => sprintf('%%%s%%', $searchterm) },
        lastname     => { -like => sprintf('%%%s%%', $searchterm) },
        contactemail => { -like => sprintf('%%%s%%', $searchterm) },
        billingemail => { -like => sprintf('%%%s%%', $searchterm) },
        phone1       => { -like => sprintf('%%%s%%', $searchterm) },
        phone2       => { -like => sprintf('%%%s%%', $searchterm) },
        company      => { -like => sprintf('%%%s%%', $searchterm) },
      ];
    }
    my $formdata = {
      customers  => $self->app->customer->get($params),
      searchterm => $searchterm
    };
    return $self->render(json => $formdata);
  }
}


sub update ($self, $makejson = 1) {
  my $formdata = $self->_formdata() || return 0;
  my $customerid = $self->param('customerid') // 0;

  if ($customerid) {
    $self->app->customer->update($customerid, $formdata->{customer});
    $formdata = $self->_getdata($customerid);
  }
  if ($makejson) {
    return $self->render(json => $formdata);
  } else {
    return $formdata;
  }
}


sub edit ($self) {
  # Fill in some default values
  my $formdata = { customer => $self->config->{roomservice}->{customer} };
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    my $title = $self->app->__('New customer');
    my $web = { title => $title };
    my $toast = $self->render_to_string(
      template => 'chunks/toast',
      format => 'html',
      toast => {
        title  => $self->app->__('Updated customer'),
        body   => $self->app->__('Modifications were saved.'),
        icon   => $self->app->icon('info-circle-fill', { extraclass => 'mx-2 text-primary' }),
        'time' => '',
        id     => 'customer-toast',
      }
    );
    $self->stash(
      headlinebuttons => 'customer/chunks/customernavbuttons',
      scriptname      => $scriptname,
      fields          => $fields,
      checkfields     => $checkfields,
      setfields       => $setfields,
      eucountries     => $self->app->customer->eucountries,
    );
    $web->{docpath} = sprintf('%s%s/edit.html', $self->config->{managerurl}, $scriptname);
    $web->{script} .= $self->render_to_string(template => 'customer/edit', format => 'js', toast => $toast);
    return $self->render(web => $web, title => $title, template => 'customer/edit', status => 200);
  } else {
    my $customerid = int $self->param('customerid');
    if ($customerid) {
      $formdata->{customer}->{customerid} = $customerid;
      $formdata = $self->_getdata($customerid);
    }
    return $self->render(json => $formdata);
  }
}


sub billing ($self) {
  my $customerid = int $self->param('customerid');
  my $invoiceid = int $self->param('invoiceid');

  my $params = {};
  my $title = $self->app->__('Customers');
  if ($customerid) {
    $title = $self->app->__x('Invoice customer #{customerid}', customerid => $customerid);
    $params->{where} = { customerid => $customerid };
    my $customer = $self->app->customer->get($params)->[0];
    $params->{where}->{invoiceid} = $invoiceid if $invoiceid;
    my $invoices = $self->app->invoice->get($params);
    $self->stash(
      customer        => $customer,
      invoices        => $invoices,
      headlinebuttons => 'customer/chunks/customernavbuttons',
      neighbours      => $self->app->customer->neighbours($customerid),
      template        => 'customer/billing',
    );
  } else {
    $self->stash(
      customers => $self->app->customer->get($params),
      template  => 'customer/index',
    );
  }
  my $web = { title => $title };
  $self->render(
    title => $title,
    web => $web,
  );
}

sub sync ($self) {
  my $customerid = $self->param('customerid') // $self->config->{test}->{customerid};
  my $customer = $self->customer->fetch($customerid);
}


sub vatno ($self) {
  my $hvatn = Business::Tax::VAT::Validation->new();
  my $vatno = $self->param('vatno') // '';
  my $title = ('' eq $vatno) ? $self->app->__('VAT number lookup') : $self->app->__x('VAT lookup, {vatno}', vatno => $vatno);
  my $web = { title => $title };
  my $info = {};
  my $error = '';
  if ($vatno =~ s/(AT|BE|BG|CY|CZ|DE|DK|EE|EL|ES|FI|FR|GB|HU|IE|IT|LU|LT|LV|MT|NL|PL|PT|RO|SE|SI|SK)(.+)/$2/) {
    if ($hvatn->check($2, $1)){
      $info = $hvatn->information();
    } else {
      $error = $hvatn->get_last_error;
    }
  }
  $self->render(
    title => $title,
    web => $web,
    vatno => $vatno,
    info => $info,
    error => $error,
    template => 'customer/vatno',
    scriptname => 'vatno'
  );
}


sub _formdata ($self) {
  my $customerid = int $self->param('customerid') || return 0;
  my $formdata = {
    customer     => { customerid => $customerid },
  };
  my $result = $self->req->params->to_hash;
  for my $field (@{$fields}) {
      $formdata->{customer}->{$field} = $result->{$field};
  }
  for my $checkfield (@{$checkfields}) {
    $formdata->{customer}->{$checkfield} = int $result->{$checkfield};
  }
  $formdata->{customer}->{vat} /= 100;
  return $formdata;
}


sub _getdata ($self, $customerid) {
  my $params = {
    where => { customerid => $customerid }
  };

  my $formdata = {
    subscriptions => $self->app->invoice->subscriptions($params),
    customer      => $self->app->customer->get($params)->[0],
    databases     => $self->app->customer->databases($params),
    sites         => $self->app->customer->sites($params),
    domains       => $self->app->domain->get($params),
    maildomains   => $self->app->domain->maildomains($params),
    userlogins    => $self->app->customer->userlogins($params),
  };

  $params->{where}->{dns} = 1;
  $formdata->{dnsdomains} = $self->app->domain->get($params);

  $params->{where} = { 'invoice.customerid' => $customerid, state => {'!=', 'obehandlad'} };
  $formdata->{invoices} = $self->app->invoice->get($params);

  $params->{where}->{state} = 'obehandlad';
  $formdata->{invoiceitems} = $self->app->invoice->invoiceitems($params);

  $formdata->{customer}->{vat} *= 100;
  return $formdata;
}

sub first ($self) {
  my $minid = $self->app->customer->neighbours(1061)->{minid};
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    $self->redirect_to(sprintf('%s%s/%s', $self->config->{managerurl}, 'customers', $minid));
  } else {
    return $self->render(json => $self->_getdata($minid));
  }}

sub newest ($self) {
  my $maxid = $self->app->customer->neighbours(1061)->{maxid};
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    $self->redirect_to(sprintf('%s%s/%s', $self->config->{managerurl}, 'customers', $maxid));
  } else {
    return $self->render(json => $self->_getdata($maxid));
  }}

sub prev ($self) {
  my $customerid = int $self->param('customerid');
  my $previd = $self->app->customer->neighbours($customerid)->{previd};
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    $self->redirect_to(sprintf('%s%s/%s', $self->config->{managerurl}, 'customers', $previd));
  } else {
    return $self->render(json => $self->_getdata($previd));
  }
}

sub next ($self) {
  my $customerid = int $self->param('customerid');
  my $nextid = $self->app->customer->neighbours($customerid)->{nextid};
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    $self->redirect_to(sprintf('%s%s/%s', $self->config->{managerurl}, 'customers', $nextid));
  } else {
    return $self->render(json => $self->_getdata($nextid));
  }
}

sub products ($self) {
  my $title = $self->app->__('Add subscription');
  my $web = {title => $title};
  my $customerid = $self->param('customerid');
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    $web->{script} .= $self->app->indent($self->render_to_string(template => 'customer/products', format => 'js'), 6);
    return $self->render(web => $web, title => $title, template => 'customer/products', layout => 'modal');
  } else {
    my $products = $self->app->invoice->products({ where => { }});
    return $self->render(json => { products => $products, customerid => $customerid });
  }
}

sub subscribe ($self) {
  my $productid = $self->param('productid');
  my $customerid = $self->param('customerid');
}

1;