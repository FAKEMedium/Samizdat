package Samizdat::Controller::Invoice;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::Util qw(decode encode b64_encode);
use UUID qw(uuid);
use Date::Format;
use MIME::Lite;
use Mojo::Home;
use Data::Dumper;

my $scriptname = 'roomservice/invoices';
my $fields = [qw(articlenumber include invoiceitemtext number price)];


sub index ($self) {
  $self->stash(scriptname => $scriptname);
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    my $title = $self->app->__('Invoices');
    my $web = { title => $title };
    my $toast = $self->render_to_string(
      template => 'chunks/toast',
      format => 'html',
      toast => {
        title  => $self->app->__('Updated invoice'),
        body   => $self->app->__('Changed status.'),
        icon   => $self->app->icon('info-circle-fill', { extraclass => 'mx-2 text-primary' }),
        'time' => '',
        id     => 'customer-toast',
      }
    );
    $web->{script} .= $self->render_to_string(template => 'invoice/index', format => 'js', toast => $toast);
    return $self->render(web => $web, title => $title, template => 'invoice/index', invoices => [], cache => 1);
  } else {
    my $customerid = int $self->param('customerid');
    my $customer = {};
    my $options = {};
    if ($customerid) {
      $options->{where}->{customerid} = $customerid;
      $customer = $self->app->customer->get($options)->[0];
      $customer->{customerid} = $customerid;
    }
    my $searchterm = int $self->param('searchterm');
    $options->{where}->{fakturanummer} = $searchterm if ($searchterm);
    $options->{where}->{state} = [];
    my $paid = int $self->param('paid');
    my $unpaid = int $self->param('unpaid');
    my $destroyed = int $self->param('destroyed');

    push @{ $options->{where}->{state} }, 'bokford' if ($paid);
    push @{ $options->{where}->{state} }, 'fakturerad' if ($unpaid);
    push @{ $options->{where}->{state} }, 'raderad' if ($destroyed);
    push @{ $options->{where}->{state} }, 'krediterad' if ($destroyed);

    $options->{where}->{state} = {'!=', 'obehandlad'} if (! scalar @{ $options->{where}->{state} });
    $options->{where}->{invoicedate} = {'>', '2017'};

    my $invoices = $self->app->invoice->get($options);
    my $formdata = {
      customer   => $customer,
      invoices   => $invoices,
      paid       => $paid,
      unpaid     => $unpaid,
      destroyed  => $destroyed,
      searchterm => $searchterm,
    };
    return $self->render(json => $formdata);
  }
}


sub create ($self) {
  my $formdata = $self->update(0);
  delete $formdata->{invoiceitems}->{extra};
  my $lang = 'en';
  if ($formdata->{customer}->{lang} =~ /^(.+)_(.+)$/) {
    $lang = $1;
  }
  $self->app->language($lang);

  my $customerid = $formdata->{customer}->{customerid};
  my $costsum = 0;
  for my $invoiceitemid (keys %{$formdata->{invoiceitems}}) {
    if (
      (0 == $formdata->{invoiceitems}->{$invoiceitemid}->{articlenumber}) ||
      (0 == $formdata->{invoiceitems}->{$invoiceitemid}->{number}) ||
      ('' eq $formdata->{invoiceitems}->{$invoiceitemid}->{invoiceitemtext}) ||
      ('' eq $formdata->{invoiceitems}->{$invoiceitemid}->{price})
    ) {
      return $self->render(json => { error => $self->app->__('Fill the form correctly!')});
    }
    if (0 == $formdata->{invoiceitems}->{$invoiceitemid}->{include}) {
      delete $formdata->{invoiceitems}->{$invoiceitemid};
    } else {
      $formdata->{invoiceitems}->{$invoiceitemid}->{invoiceitemtext} =~ s/--/\-\-/;
      $self->_texescape(\$formdata->{invoiceitems}->{$invoiceitemid}->{invoiceitemtext});
      $costsum += $formdata->{invoiceitems}->{$invoiceitemid}->{number} * $formdata->{invoiceitems}->{$invoiceitemid}->{price};
    }
  }

  my $vat = $formdata->{customer}->{vat};
  $vat *= 100;
  $vat =~ s/[0]+$// if ($vat =~ /\./);
  if ($vat =~ /(\d+)[\.]{1}([\d]{1,2})$/) {
    $vat = sprintf("%.2f", $vat);
  }
  $vat =~ s/\.$//;
  $formdata->{vat} = $vat;

  my $vatcost = $formdata->{customer}->{vat} * $costsum;
  my $totalcost = $costsum + $vatcost;
  my $rounded = $totalcost;
  my $diff = 0;
  if ($formdata->{customer}->{currency} =~ /sek/i) {
    if ($totalcost =~ /(\d+)[\.]{1}(\d+)/) {
      $rounded = $1;
      $diff = $2;
      if ($diff =~ /^[5-9]/) {
        $rounded = $rounded + 1.0;
      }
    }
  } else {
    $rounded = sprintf("%.2f", $totalcost);
  }

  $diff = sprintf("%.5f", $rounded - $totalcost);
  $diff =~ s/[0]+$// if ($diff =~ /\./);;
  if ($diff =~ /(\d+)[\.]{1}([\d]{1,2})$/) {
    $diff = sprintf("%.2f", $diff);
  }
  $diff =~ s/\.$//;
  $costsum =~ s/[0]+$// if ($costsum =~ /\./);
  if ($costsum =~ /(\d+)[\.]{1}([\d]{1,2})$/) {
    $costsum = sprintf("%.2f", $costsum);
  }
  $formdata->{invoice}->{invoicedate} = sprintf('%4d-%02d-%02d',
    (localtime(time))[5] + 1900,
    (localtime(time))[4] + 1,
    (localtime(time))[3]
  );
  my $duedate = time2str("%Y-%m-%d", time + $self->app->config->{roomservice}->{invoice}->{duedays}*24*3600, 'CET');
  $formdata->{invoice}->{duedate} = $duedate;
  $formdata->{invoice}->{pdfdate} = time2str("%Y%m%d%H%M%S", time, 'CET');
  $formdata->{invoice}->{costsum} = $costsum;
  $formdata->{invoice}->{rounded} = $rounded;
  $formdata->{invoice}->{diff} = $diff;
  $formdata->{invoice}->{vatcost} = $vatcost;

  my $nextnumber = $self->app->invoice->nextnumber;
  $formdata->{invoice}->{fakturanummer} = $nextnumber;
  my $uuid = sprintf('%s_%s_%s',
    $nextnumber,
    $formdata->{customer}->{customerid},
    uuid()
  );
  $formdata->{invoice}->{uuid} = $uuid;
  $formdata->{invoice}->{title} = $self->app->__x('Invoice {number}', number => $nextnumber);

  # Prepare customer data
  for my $field ('firstname', 'lastname', 'company', 'address', 'city') {
    $self->_texescape(\$formdata->{customer}->{$field});
  }
  if ('SE' eq uc $formdata->{customer}->{country}) {
    $formdata->{customer}->{zip} =~ s/\s+//g;
    $formdata->{customer}->{zip} = sprintf('%s\ %s',
      substr($formdata->{customer}->{zip}, 0, 3),
      substr($formdata->{customer}->{zip}, 3, 2)
    );
    $formdata->{customer}->{city} ='\ ' . $formdata->{customer}->{city};
  }

  $self->stash(formdata => $formdata);

  my $tex = $self->render_to_string(format => 'tex', layout => 'invoice', template => 'invoice/print');
  $tex = encode 'UTF-8', $tex;
  if ($self->render(data => $self->app->printinvoice($tex, $formdata), format => 'pdf')) {
    $self->res->headers->header('Content-Disposition' =>
      sprintf('inline; filename="%s_%s.pdf"', 'Rymdweb', $formdata->{invoice}->{uuid})
    );
    $self->res->headers->content_type('application/pdf');
    my $invoicedata = {
      invoice      => $self->app->invoice->get({
        where => { invoiceid => $formdata->{invoice}->{invoiceid}, customerid => $customerid }
      })->[0],
      invoiceitems => $self->app->invoice->invoiceitems({
        where => { 'invoice.invoiceid' => $formdata->{invoice}->{invoiceid}, 'invoice.customerid' => $customerid }
      }),
      customer     => $formdata->{customer}
    };
    $invoicedata->{invoice}->{invoicedate} = $formdata->{invoice}->{invoicedate};
    $invoicedata->{invoice}->{state} = 'fakturerad';
    $invoicedata->{invoice}->{uuid} = $uuid;
    $invoicedata->{invoice}->{fakturanummer} = $nextnumber;
    $invoicedata->{invoice}->{costsum} = $formdata->{invoice}->{rounded};
    delete $invoicedata->{invoice}->{rounded};
    delete $invoicedata->{invoice}->{diff};
    delete $invoicedata->{invoice}->{vatcost};
    delete $invoicedata->{invoice}->{paydate};
    delete $invoicedata->{invoice}->{dontremind};
    delete $invoicedata->{invoice}->{title};
    delete $invoicedata->{invoice}->{bookingdate};
    delete $invoicedata->{invoice}->{rev};
    delete $invoicedata->{invoice}->{kreditfakturaavser};

#    say Dumper $formdata->{invoice};
    $self->app->invoice->updateinvoice($invoicedata->{invoice}->{invoiceid}, $invoicedata->{invoice});
    my $newinvoiceid = $self->app->invoice->addinvoice($formdata->{customer});

    for my $invoiceitemid (keys %{ $invoicedata->{invoiceitems} }) {
      my $invoiceitem = $invoicedata->{invoiceitems}->{$invoiceitemid};
      if (!$invoiceitem->{include}) {
        # Move unincluded invoice items to the newly created open invoice
        $self->app->invoice->updateinvoiceitem($invoiceitemid, {invoiceid => $newinvoiceid});
      } else {
        # If item is a subscription, update the last invoicedate of the subscription
        $self->app->invoice->updatesubscription($customerid, $invoiceitem->{productid});
      }
    }
    $invoicedata->{invoice}->{duedate} = $duedate;

    my $anyrepo = Mojo::Home->new();
    my $svg = $anyrepo->child('src/public/' . $self->config->{logotype})->slurp;
    $svg = b64_encode($svg);
    $svg =~ s/[\r\n\s]+//g;
    chomp $svg;
    $invoicedata->{svglogotype} = $svg;
    $invoicedata->{vat} = $vat;

    my $alternative = MIME::Lite->new(Type => 'multipart/alternative');

    my $htmldata = $self->render_mail(template => 'invoice/createhtml', invoicedata => $invoicedata);
    $alternative->attach(Data => $htmldata, Type => 'text/html; charset=UTF-8');

    my $txtdata = $self->render_mail(template => 'invoice/createtxt', invoicedata => $invoicedata);
    $alternative->attach(Data => $txtdata, Type => 'text/plain; charset=UTF-8');

    my $mail = MIME::Lite->new(
      From         => $self->config->{mail}->{from},
      Bcc          => $self->{config}->{test}->{invoice} ? undef : $self->config->{mail}->{from},
      To           => $self->{config}->{test}->{invoice} ? $self->config->{mail}->{to} : $invoicedata->{customer}->{billingemail},
      Organization => Encode::encode("MIME-Q", Encode::decode("UTF-8", "Rymdweb AB")),
      Subject      => Encode::encode("MIME-Q", Encode::decode("UTF-8",
        $self->app->__x('Invoice {fakturanummer}', fakturanummer => $invoicedata->{invoice}->{fakturanummer}))),
      Type         => 'multipart/mixed',
      'X-Mailer'   => "Rymdwebs faktureringssystem",
    );
    $mail->attach($alternative);
    $mail->attach(
      Path        => sprintf('%s/%s.pdf', $self->config->{roomservice}->{invoice}->{invoicedir}, $invoicedata->{invoice}->{uuid}),
      Filename    => sprintf('%s.pdf', $invoicedata->{invoice}->{uuid}),
      Type        => 'application/pdf',
      Disposition => 'attachment'
    );
    say $mail->send($self->config->{mail}->{how}, @{ $self->config->{mail}->{howargs} });

    return 1;
  } else {

  }
}


sub update ($self, $makejson = 1) {
  my $formdata = $self->_formdata() || return 0;
  $self->app->customer->update($formdata->{invoice}->{customerid}, $formdata->{customer});

  for my $invoiceitemid (keys %{$formdata->{invoiceitems}}) {
    $self->app->invoice->updateinvoiceitem($invoiceitemid, $formdata->{invoiceitems}->{$invoiceitemid}) if ($invoiceitemid =~ /^[\d]+$/);
  }
  my $extra = $formdata->{invoiceitems}->{extra};
  $extra->{customerid} = $formdata->{customer}->{customerid};
  $extra->{invoiceid} = $formdata->{invoice}->{invoiceid};
#  say Dumper $extra;
  if ((int $extra->{number} > 0) && ('' ne $extra->{invoiceitemtext}) && ($extra->{price} > 0.0)) {
    $self->app->invoice->addinvoiceitem($extra);
  }

  $formdata->{customer} = $self->app->customer->get({
    where => { customerid => $formdata->{invoice}->{customerid} } }
  )->[0];
  $formdata->{invoice} = $self->app->invoice->get({
    where => { customerid => $formdata->{invoice}->{customerid}, invoiceid => $formdata->{invoice}->{invoiceid} }
  })->[0];
  $formdata->{invoiceitems} = $self->app->invoice->invoiceitems({
    where => {'invoice.invoiceid' => $formdata->{invoice}->{invoiceid}} }
  );
  $formdata->{invoiceitems}->{extra} = {
    invoiceitemid   => 'extra',
    invoiceid       => $formdata->{invoice}->{invoiceid},
    invoiceitemtext => '',
    price           => '',
    vat             => $formdata->{customer}->{vat},
    customerid      => $formdata->{invoice}->{customerid},
    number          => '',
    include         => 1,
    articlenumber   => '',
  };

  if ($makejson) {
    return $self->render(json => $formdata);
  } else {
    return $formdata;
  }
}


sub edit ($self) {
  my $title = $self->app->__('Open invoice');
  my $web = {title => $title};
  my $toast = $self->render_to_string(
    template => 'chunks/toast',
    format => 'html',
    toast => {
      title  => $self->app->__('Updated invoice'),
      body   => $self->app->__('Modifications were saved.'),
      icon   => $self->app->icon('info-circle-fill', { extraclass => 'mx-2 text-primary' }),
      'time' => '',
      id     => 'invoice-toast',
    }
  );
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    $web->{script} .= $self->render_to_string(template => 'invoice/edit', format => 'js', toast => $toast);
    return $self->render(web => $web, title => $title, template => 'invoice/edit', headlinebuttons => 'editlinks');
  } else {
    my $formdata = $self->_getdata();
    $formdata->{invoiceitems}->{extra} = {
      invoiceitemid   => 'extra',
      invoiceid       => $formdata->{invoice}->{invoiceid},
      invoiceitemtext => '',
      price           => '',
      vat             => $formdata->{customer}->{vat},
      customerid      => $formdata->{customer}->{customerid},
      number          => '',
      include         => 1,
      articlenumber   => '',
    };
    return $self->render(json => $formdata);
  }
}


sub handle ($self) {
  my $title = $self->app->__('Open invoice');
  my $web = {title => $title};
  my $toast = $self->render_to_string(
    template => 'chunks/toast',
    format => 'html',
    toast => {
      title  => $self->app->__('Handled invoice'),
      body   => $self->app->__('Modifications were saved.'),
      icon   => $self->app->icon('info-circle-fill', { extraclass => 'mx-2 text-primary' }),
      'time' => '',
      id     => 'invoice-toast',
    }
  );
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    $web->{script} .= $self->render_to_string(template => 'invoice/handle', format => 'js', toast => $toast);
    return $self->render(web => $web, title => $title, template => 'invoice/handle', headlinebuttons => 'editlinks');
  } else {
    my $formdata = $self->_getdata();
    return $self->render(json => $formdata);
  }
}


sub open ($self) {
  my $title = $self->app->__('Open invoices');
  my $web = {title => $title};
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    $web->{script} .= $self->render_to_string(template => 'invoice/open', format => 'js');
    return $self->render(web => $web, title => $title, template => 'invoice/open');
  } else {
    my $invoiceitems = $self->app->invoice->invoiceitems({ where => { 'invoice.state' => { '=', 'obehandlad' } } });
    my $customers = {};
    for my $invoiceitemid (keys %{$invoiceitems}) {
      my $invoiceitem = $invoiceitems->{$invoiceitemid};
      my $customerid = delete $invoiceitem->{customerid};
      my $invoiceid = delete $invoiceitem->{invoiceid};
      delete $invoiceitem->{invoiceitemid};
      if (!exists($customers->{$customerid})) {
        my $customer = $self->app->customer->get({where => { customerid => $customerid }})->[0];
        $customer->{name} = $self->app->customer->name($customer);
        $customers->{$customerid} = $customer;
      }
      $customers->{$customerid}->{invoices}->{$invoiceid}->{invoiceitems}->{$invoiceitemid} = $invoiceitem;
    };
    return $self->render(json => { customers => $customers });
  }
}

sub _texescape ($self, $text) {
  $$text =~ s/(\&|\$|\%|\#|\_)/\\$1/g;
}

sub _formdata ($self) {
  my $invoiceid = int $self->param('invoiceid') || return 0;
  my $customerid = int $self->param('customerid') || return 0;
  my $formdata = {
    invoice      => { invoiceid  => $invoiceid, customerid => $customerid, costsum => 0 },
    invoiceitems => {},
    customer     => { customerid => $customerid },
    articles     => $self->_articles(),
  };
  my $result = $self->req->params->to_hash;
  my $regexp = join '|', @$fields;
  $regexp = qr/($regexp)_(.+)/;
  for my $key (keys %$result) {
    if ($key =~ $regexp) {
      $formdata->{invoiceitems}->{$2}->{$1} = $result->{$key};
    }
    if ($key =~ /^(billing(email|address|zip|country))$/) {
      $formdata->{customer}->{$key} = $result->{$key};
    }
  }
  # Unchecked checkboxes need extra handling
  for my $invoiceitemid (keys %{$formdata->{invoiceitems}}) {
    $formdata->{invoiceitems}->{$invoiceitemid}->{price} =~ s/\,/./;
    $formdata->{invoiceitems}->{$invoiceitemid}->{number} =~ s/\,/./;
    if (!exists($formdata->{invoiceitems}->{$invoiceitemid}->{include})) {
      $formdata->{invoiceitems}->{$invoiceitemid}->{include} = 0;
    }
  }
  return $formdata;
}


sub _getdata ($self) {
  my $customerid = int $self->param('customerid') || return 0;
  my $invoiceid = int $self->param('invoiceid');
  if (!$invoiceid) {
    $invoiceid = $self->app->invoice->get({
      where => {
        state => { '=', 'obehandlad' },
        customerid => $customerid
      }
    })->[0]->{invoiceid};
  }
  my $formdata = {
    customer      => $self->app->customer->get({where => { customerid => $customerid }})->[0],
    invoice       => $self->app->invoice->get({where => { invoiceid => $invoiceid, customerid => $customerid }})->[0],
    invoiceitems  => $self->app->invoice->invoiceitems({where => { 'invoice.invoiceid' => $invoiceid, 'invoice.customerid' => $customerid }}),
    articles      => $self->_articles(),
  };
  return $formdata;
}


sub _articles ($self) {
  my $articles = $self->app->fortnox->getArticle();
  if (exists $articles->{Articles}) {
    $articles = $articles->{Articles};
  } else {
    $articles = {};
  }
  return $articles;
}


1;