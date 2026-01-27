package Samizdat::Controller::RealtimeRegister;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Data::Dumper;

sub index ($self) {
  my $title = $self->app->__('Realtime Register');
  my $web = { title => $title };

  my $accept = $self->req->headers->accept || '';
  if ($accept !~ /json/) {
    $web->{sidebar} = $self->render_to_string(template => 'realtimeregister/chunks/sidebar', format => 'html');
    $web->{script} = $self->render_to_string(template => 'realtimeregister/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'realtimeregister/index', headline => 'realtimeregister/chunks/headline');
  } else {
    return unless $self->access({ admin => 1 });
    return $self->render(json => { status => 'ok' });
  }
}

# Domain management

sub domains ($self) {
  my $title = $self->app->__('Domains');
  my $web = { title => $title };
  my $accept = $self->req->headers->accept || '';

  if ($accept !~ /json/) {
    $web->{sidebar} = $self->render_to_string(template => 'realtimeregister/chunks/sidebar', format => 'html');
    $web->{script} = $self->render_to_string(template => 'realtimeregister/domains/index', format => 'js', perpage => $self->perpage);
    return $self->render(web => $web, title => $title, template => 'realtimeregister/domains/index', headline => 'realtimeregister/chunks/headline');
  } else {
    return unless $self->access({ admin => 1 });
    my $params = {};
    $params->{limit} = $self->param('limit') if $self->param('limit');
    $params->{offset} = $self->param('offset') if $self->param('offset');
    $params->{q} = $self->param('search') if $self->param('search');
    my $domains = $self->app->realtimeregister->getDomains($params);
    return $self->render(json => { domains => $domains });
  }
}


sub domain ($self) {
  my $title = $self->app->__('Domain details');
  my $web = { title => $title };
  my $accept = $self->req->headers->accept || '';

  if ($accept !~ /json/) {
    # Set docpath to ensure static cache goes to /domain/index.html instead of /<domain-name>/index.html
    $self->stash(docpath => '/realtimeregister/domains/domain/index.html');
    $web->{sidebar} = $self->render_to_string(template => 'realtimeregister/chunks/sidebar', format => 'html');
    $web->{script} = $self->render_to_string(template => 'realtimeregister/domains/domain/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'realtimeregister/domains/domain/index',
      headline => 'realtimeregister/chunks/headline', format => 'html');
  } else {
    return unless $self->access({ admin => 1 });
    my $domain_name = $self->stash('domain');
    my $domain = $self->app->realtimeregister->getDomain($domain_name);
    return $self->render(json => { domain => $domain });
  }
}


sub create_domain ($self) {
  return unless $self->access({ admin => 1 });

  my $domain_data = $self->req->json;
  my $result = $self->app->realtimeregister->createDomain($domain_data);

  if ($result->{error}) {
    return $self->render(json => { error => $result->{error} }, status => 400);
  }

  return $self->render(json => { success => 1, domain => $result });
}


sub update_domain ($self) {
  return unless $self->access({ admin => 1 });

  my $domain_name = $self->stash('domain');
  my $domain_data = $self->req->json;

  my $result = $self->app->realtimeregister->updateDomain($domain_name, $domain_data);

  if ($result->{error}) {
    return $self->render(json => { error => $result->{error} }, status => 400);
  }

  return $self->render(json => { success => 1, domain => $result });
}


sub delete_domain ($self) {
  return unless $self->access({ admin => 1 });

  my $domain_name = $self->stash('domain');
  my $result = $self->app->realtimeregister->deleteDomain($domain_name);

  if ($result->{error}) {
    return $self->render(json => { error => $result->{error} }, status => 400);
  }

  return $self->render(json => { success => 1 });
}


sub renew_domain ($self) {
  return unless $self->access({ admin => 1 });

  my $domain_name = $self->stash('domain');
  my $data = $self->req->json // {};
  my $period = $data->{period} // 1;

  my $result = $self->app->realtimeregister->renewDomain($domain_name, $period);

  if ($result->{error}) {
    return $self->render(json => { error => $result->{error} }, status => 400);
  }

  return $self->render(json => { success => 1, domain => $result });
}

# Contact management

sub contacts ($self) {
  my $title = $self->app->__('Contacts');
  my $web = { title => $title };
  my $accept = $self->req->headers->accept || '';

  if ($accept !~ /json/) {
    $web->{sidebar} = $self->render_to_string(template => 'realtimeregister/chunks/sidebar', format => 'html');
    $web->{script} = $self->render_to_string(template => 'realtimeregister/contacts/index', format => 'js', perpage => $self->perpage);
    return $self->render(web => $web, title => $title, template => 'realtimeregister/contacts/index', headline => 'realtimeregister/chunks/headline');
  } else {
    return unless $self->access({ admin => 1 });
    my $params = {};
    $params->{limit} = $self->param('limit') if $self->param('limit');
    $params->{offset} = $self->param('offset') if $self->param('offset');
    $params->{search} = $self->param('search') if $self->param('search');
    my $contacts = $self->app->realtimeregister->getContacts($params);
    return $self->render(json => { contacts => $contacts });
  }
}


sub contact ($self) {
  my $title = $self->app->__('Contact Details');
  my $web = { title => $title };
  my $accept = $self->req->headers->accept || '';

  if ($accept !~ /json/) {
    # Set docpath to ensure static cache goes to /contact/index.html instead of /<contact-handle>/index.html
    $self->stash(docpath => '/realtimeregister/contacts/contact/index.html');
    $web->{sidebar} = $self->render_to_string(template => 'realtimeregister/chunks/sidebar', format => 'html');
    $web->{script} = $self->render_to_string(template => 'realtimeregister/contacts/contact/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'realtimeregister/contacts/contact/index', headline => 'realtimeregister/chunks/headline');
  } else {
    return unless $self->access({ admin => 1 });
    my $contact_handle = $self->param('handle');
    my $contact = $self->app->realtimeregister->getContact($contact_handle);
    return $self->render(json => { contact => $contact });
  }
}


sub new_contact ($self) {
  my $title = $self->app->__('New Contact');
  my $web = { title => $title };

  $web->{script} = $self->render_to_string(template => 'realtimeregister/contacts/new/index', format => 'js');
  $self->stash(web => $web);
  return $self->render(template => 'realtimeregister/contacts/new/index', layout => 'modal', title => $title);
}


sub create_contact ($self) {
  return unless $self->access({ admin => 1 });

  my $contact_data = $self->req->json;
  my $result = $self->app->realtimeregister->createContact($contact_data);

  if ($result->{error}) {
    return $self->render(json => { error => $result->{error} }, status => 400);
  }

  return $self->render(json => { success => 1, contact => $result });
}


sub update_contact ($self) {
  return unless $self->access({ admin => 1 });

  my $contact_handle = $self->param('handle');
  my $contact_data = $self->req->json;

  my $result = $self->app->realtimeregister->updateContact($contact_handle, $contact_data);

  if ($result->{error}) {
    return $self->render(json => { error => $result->{error} }, status => 400);
  }

  return $self->render(json => { success => 1, contact => $result });
}


sub delete_contact ($self) {
  return unless $self->access({ admin => 1 });

  my $contact_handle = $self->param('handle');
  my $result = $self->app->realtimeregister->deleteContact($contact_handle);

  if ($result->{error}) {
    return $self->render(json => { error => $result->{error} }, status => 400);
  }

  return $self->render(json => { success => 1 });
}

# Financial Transactions

sub transactions ($self) {
  my $title = $self->app->__('Transactions');
  my $web = { title => $title };
  my $accept = $self->req->headers->accept || '';

  if ($accept !~ /json/) {
    $web->{sidebar} = $self->render_to_string(template => 'realtimeregister/chunks/sidebar', format => 'html');
    $web->{script} = $self->render_to_string(template => 'realtimeregister/transactions/index', format => 'js', perpage => $self->perpage);
    return $self->render(web => $web, title => $title, template => 'realtimeregister/transactions/index', headline => 'realtimeregister/chunks/headline');
  } else {
    return unless $self->access({ admin => 1 });
    my $params = {};
    $params->{limit} = $self->param('limit') if $self->param('limit');
    $params->{offset} = $self->param('offset') if $self->param('offset');
    $params->{order} = $self->param('order') // '-date';  # Default: newest first
    my $transactions = $self->app->realtimeregister->getTransactions($params);
    return $self->render(json => { transactions => $transactions });
  }
}

sub transaction ($self) {
  my $title = $self->app->__('Transaction Details');
  my $web = { title => $title };
  my $accept = $self->req->headers->accept || '';

  if ($accept !~ /json/) {
    $self->stash(docpath => '/realtimeregister/transactions/transaction/index.html');
    $web->{sidebar} = $self->render_to_string(template => 'realtimeregister/chunks/sidebar', format => 'html');
    $web->{script} = $self->render_to_string(template => 'realtimeregister/transactions/transaction/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'realtimeregister/transactions/transaction/index', headline => 'realtimeregister/chunks/headline');
  } else {
    return unless $self->access({ admin => 1 });
    my $id = $self->param('id');
    my $transaction = $self->app->realtimeregister->getTransaction($id);
    return $self->render(json => { transaction => $transaction });
  }
}

# Pricelist

sub pricelist ($self) {
  my $title = $self->app->__('Price List');
  my $web = { title => $title };
  my $accept = $self->req->headers->accept || '';
  my $rtr = $self->app->realtimeregister;

  if ($accept !~ /json/) {
    my $currencies = $rtr->currencies;
    $web->{sidebar} = $self->render_to_string(template => 'realtimeregister/chunks/sidebar', format => 'html');
    $web->{script} = $self->render_to_string(template => 'realtimeregister/pricelist/index', format => 'js',
      currencies => $currencies, default_currency => $rtr->default_currency);
    return $self->render(web => $web, title => $title, template => 'realtimeregister/pricelist/index',
      headline => 'realtimeregister/chunks/headline', currencies => $currencies);
  } else {
    return unless $self->access({ admin => 1 });
    my $params = {};
    $params->{currency} = $self->param('currency') if $self->param('currency');
    my $pricelist = $rtr->getPricelist($params);
    return $self->render(json => { pricelist => $pricelist });
  }
}

1;
