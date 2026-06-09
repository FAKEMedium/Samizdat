package Samizdat::Controller::Customer;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Business::Tax::VAT::Validation;
use Data::Dumper;

my $scriptname = 'customers';
my $fields = [qw(customerid company firstname lastname address zip city contactemail country orgno phone1 phone2 freetext)];
push @{$fields}, qw(reference recommendedby period currency invoicetype lang trust vatno vat);
my $checkfields = [qw(newsletter active)];
my $setfields = [qw(created creator updated updater)];

sub index ($self) {
  $self->stash(scriptname => $scriptname);
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    my $title = $self->app->__('Customers');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'customer/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'customer/index', customers => [], status => 200);

  } else {
    my $authcookie = $self->cookie($self->config->{manager}->{account}->{authcookiename});
    my $session = $authcookie ? $self->app->account->session($authcookie) : undef;
    my $is_admin = 0;

    if ($session && $session->{username}) {
      my $admins = $self->config->{manager}->{account}->{admins} // {};
      my $superadmins = $self->config->{manager}->{account}->{superadmins} // {};
      $is_admin = 1 if exists $admins->{$session->{username}} || exists $superadmins->{$session->{username}};
    }

    if (!$is_admin) {
      return unless $self->access({ 'valid-user' => 1 });
      my $languageid = $session->{languages_id} // 1;
      my $customers = $self->app->customer->get_customers_for_user($session->{userid}, $languageid);
      return $self->render(json => { customers => $customers, admin => 0 });
    }

    my $searchterm = $self->param('searchterm');
    my $simple = $self->param('simple');  # For dropdowns - returns id+name only, active customers
    my $params = {};

    if ($simple && $searchterm && length($searchterm) >= 3) {
      # Simple mode for selectors - search active customers, return minimal data
      my @or_conditions = (
        firstname    => { -like => sprintf('%%%s%%', $searchterm) },
        lastname     => { -like => sprintf('%%%s%%', $searchterm) },
        contactemail => { -like => sprintf('%%%s%%', $searchterm) },
        company      => { -like => sprintf('%%%s%%', $searchterm) },
      );
      # Only search by customerid if searchterm is numeric
      if ($searchterm =~ /^\d+$/) {
        unshift @or_conditions, customerid => [ int $searchterm ];
      }
      $params->{where} = {
        -and => [
          { active => 1 },
          -or => \@or_conditions
        ]
      };
      $params->{limit} = { -limit => 20 };
      my $customers = $self->app->customer->get($params);
      # Return simplified format with formatted name
      my @simple_list = map {
        {
          customerid => $_->{customerid},
          name => sprintf('%d %s', $_->{customerid}, $self->app->customer->name($_))
        }
      } @$customers;
      return $self->render(json => { customers => \@simple_list });
    }

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
      searchterm => $searchterm,
      admin      => 1,
    };
    return $self->render(json => $formdata);
  }
}


sub update ($self, $makejson = 1) {
  # Require admin access for customer management
  return unless $self->access({ admin => 1 });

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
  my $formdata = { customer => $self->config->{manager}->{customer} };
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    # Set docpath to ensure static cache goes to /customer/edit/index.html instead of /<customerid>/edit/index.html
    $self->stash(docpath => '/customers/customer/edit/index.html');
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
      headline        => 'customer/chunks/customernavbuttons',
      scriptname      => $scriptname,
      fields          => $fields,
      checkfields     => $checkfields,
      setfields       => $setfields,
      eucountries     => $self->app->customer->eucountries,
    );
    $web->{script} .= $self->render_to_string(template => 'customer/edit/index', format => 'js', toast => $toast);
    return $self->render(web => $web, title => $title, template => 'customer/edit/index', status => 200);
  } else {
    # Require admin access for customer data
    return unless $self->access({ admin => 1 });

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
    # Set docpath to ensure static cache goes to /customer/billing/index.html instead of /<customerid>/billing/index.html
    $self->stash(docpath => '/customers/customer/billing/index.html');
    $title = $self->app->__x('Invoice customer #{customerid}', customerid => $customerid);
    $params->{where} = { customerid => $customerid };
    my $customer = $self->app->customer->get($params)->[0];
    $params->{where}->{invoiceid} = $invoiceid if $invoiceid;
    my $invoices = $self->app->renderer->helpers->{invoice} ? $self->app->invoice->get($params) : [];
    $self->stash(
      customer        => $customer,
      invoices        => $invoices,
      headline        => 'customer/chunks/customernavbuttons',
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
  # Require admin access for customer sync
  return unless $self->access({ admin => 1 });

  my $customerid = $self->param('customerid') // $self->config->{test}->{customerid};
  my $customer = $self->customer->fetch($customerid);
}


sub vatno ($self) {
  my $hvatn = Business::Tax::VAT::Validation->new();
  my $vatno = $self->param('vatno') // '';
  my $info = {};
  my $error = '';
  my $valid = 0;
  my $country = '';

  if ($vatno =~ s/^(AT|BE|BG|CY|CZ|DE|DK|EE|EL|ES|FI|FR|GB|HU|IE|IT|LU|LT|LV|MT|NL|PL|PT|RO|SE|SI|SK)(.+)/$2/) {
    $country = $1;
    if ($hvatn->check($2, $1)) {
      $info = $hvatn->information();
      $valid = 1;
    } else {
      $error = $hvatn->get_last_error;
    }
  } elsif ($vatno ne '') {
    $error = 'Invalid VAT number format. Must start with country code (e.g., SE, DE, FR).';
  }

  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept =~ /json/) {
    return $self->render(json => {
      vatno   => $vatno,
      country => $country,
      info    => $info,
      error   => $error,
      valid   => $valid,
    });
  }

  my $title = ('' eq $vatno) ? $self->app->__('VAT number lookup') : $self->app->__x('VAT lookup, {vatno}', vatno => $vatno);
  my $web = { title => $title };
  $self->render(
    title => $title,
    web => $web,
    vatno => $vatno,
    info => $info,
    error => $error,
    template => 'customer/vatno/index',
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
    subscriptions => $self->app->renderer->helpers->{invoice} ? $self->app->invoice->subscriptions($params) : [],
    customer      => $self->app->customer->get($params)->[0],
    databases     => $self->app->renderer->helpers->{database} ? $self->app->database->get($params) : [],
    sites         => $self->app->renderer->helpers->{website} ? $self->app->website->get_by_customer($customerid) : [],
    domains       => $self->app->domain->get($params),
    maildomains   => $self->app->renderer->helpers->{email} ? $self->app->email->get_domains($params) : [],
    userlogins    => $self->app->customer->userlogins($params),
  };

  $params->{where}->{dns} = 1;
  $formdata->{dnsdomains} = $self->app->domain->get($params);

  $params->{where} = { 'invoice.customerid' => $customerid, state => {'!=', 'obehandlad'} };
  $formdata->{invoices} = $self->app->renderer->helpers->{invoice} ? $self->app->invoice->get($params) : [];

  $params->{where}->{state} = 'obehandlad';
  $formdata->{invoiceitems} = $self->app->renderer->helpers->{invoice} ? $self->app->invoice->invoiceitems($params) : [];

  $formdata->{customer}->{vat} *= 100;
  return $formdata;
}

sub first ($self) {
  my $minid = $self->app->customer->neighbours(1061)->{minid};
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    $self->redirect_to(sprintf('%s%s/%s', $self->config->{manager}->{url}, 'customers', $minid));
  } else {
    # Require admin access for customer data
    return unless $self->access({ admin => 1 });
    return $self->render(json => $self->_getdata($minid));
  }}

sub newest ($self) {
  my $maxid = $self->app->customer->neighbours(1061)->{maxid};
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    $self->redirect_to(sprintf('%s%s/%s', $self->config->{manager}->{url}, 'customers', $maxid));
  } else {
    # Require admin access for customer data
    return unless $self->access({ admin => 1 });
    return $self->render(json => $self->_getdata($maxid));
  }}

sub prev ($self) {
  my $customerid = int $self->param('customerid');
  my $previd = $self->app->customer->neighbours($customerid)->{previd};
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    $self->redirect_to(sprintf('%s%s/%s', $self->config->{manager}->{url}, 'customers', $previd));
  } else {
    # Require admin access for customer data
    return unless $self->access({ admin => 1 });
    return $self->render(json => $self->_getdata($previd));
  }
}

sub next ($self) {
  my $customerid = int $self->param('customerid');
  my $nextid = $self->app->customer->neighbours($customerid)->{nextid};
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    $self->redirect_to(sprintf('%s%s/%s', $self->config->{manager}->{url}, 'customers', $nextid));
  } else {
    # Require admin access for customer data
    return unless $self->access({ admin => 1 });
    return $self->render(json => $self->_getdata($nextid));
  }
}

sub products ($self) {
  my $title = $self->app->__('Add subscription');
  my $web = {title => $title};
  my $customerid = $self->param('customerid');
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    # Set docpath to ensure static cache goes to /customer/products/index.html instead of /<customerid>/products/index.html
    $self->stash(docpath => '/customers/customer/products/index.html');
    $web->{script} .= $self->render_to_string(template => 'customer/products/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'customer/products/index', layout => 'modal');
  } else {
    # Require admin access for product data
    return unless $self->access({ admin => 1 });

    my $products = $self->app->renderer->helpers->{invoice} ? $self->app->invoice->products({ where => { }}) : [];
    return $self->render(json => { products => $products, customerid => $customerid });
  }
}

sub subscribe ($self) {
  # Require admin access for subscription management
  return unless $self->access({ admin => 1 });

  my $productid = $self->param('productid');
  my $customerid = $self->param('customerid');
}

1;