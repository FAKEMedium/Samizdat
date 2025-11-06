package Samizdat::Controller::RealtimeRegister;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Data::Dumper;

sub index ($self) {
  return unless $self->access({ admin => 1 });

  my $title = $self->app->__('RealtimeRegister');
  my $web = { title => $title };

  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    $web->{sidebar} = $self->render_to_string(template => 'realtimeregister/chunks/sidebar', format => 'html');
    $web->{script} .= $self->render_to_string(format => 'js');
    return $self->render(web => $web, title => $title, headline => 'realtimeregister/chunks/headline');
  }
}

# Domain management

sub domains ($self) {
  return unless $self->access({ admin => 1 });

  my $title = $self->app->__('Domains');
  my $web = { title => $title };
  my $accept = $self->req->headers->{headers}->{accept}->[0];

  if ($accept !~ /json/) {
    $web->{sidebar} = $self->render_to_string(template => 'realtimeregister/chunks/sidebar', format => 'html');
    $web->{script} .= $self->render_to_string(format => 'js');
    return $self->render(web => $web, title => $title, headline => 'realtimeregister/chunks/headline');
  } else {
    my $env = $self->param('env') // 'production';
    my $domains = $self->app->realtimeregister->getDomains({}, $env);
    return $self->render(json => { domains => $domains });
  }
}

sub domain ($self) {
  return unless $self->access({ admin => 1 });

  my $domain_name = $self->stash('domain');
  my $title = $self->app->__('Domain: ') . $domain_name;
  my $web = { title => $title };
  my $accept = $self->req->headers->{headers}->{accept}->[0];

  if ($accept !~ /json/) {
    $web->{sidebar} = $self->render_to_string(template => 'realtimeregister/chunks/sidebar', format => 'html');
    $web->{script} .= $self->render_to_string(format => 'js');
    return $self->render(web => $web, title => $title, headline => 'realtimeregister/chunks/headline');
  } else {
    my $env = $self->param('env') // 'production';
    my $domain = $self->app->realtimeregister->getDomain($domain_name, $env);
    return $self->render(json => { domain => $domain });
  }
}

sub create_domain ($self) {
  return unless $self->access({ admin => 1 });

  my $domain_data = $self->req->json;
  my $env = $self->param('env') // 'production';

  my $result = $self->app->realtimeregister->createDomain($domain_data, $env);

  if ($result->{error}) {
    return $self->render(json => { error => $result->{error} }, status => 400);
  }

  return $self->render(json => { success => 1, domain => $result });
}

sub update_domain ($self) {
  return unless $self->access({ admin => 1 });

  my $domain_name = $self->stash('domain');
  my $domain_data = $self->req->json;
  my $env = $self->param('env') // 'production';

  my $result = $self->app->realtimeregister->updateDomain($domain_name, $domain_data, $env);

  if ($result->{error}) {
    return $self->render(json => { error => $result->{error} }, status => 400);
  }

  return $self->render(json => { success => 1, domain => $result });
}

sub delete_domain ($self) {
  return unless $self->access({ admin => 1 });

  my $domain_name = $self->stash('domain');
  my $env = $self->param('env') // 'production';

  my $result = $self->app->realtimeregister->deleteDomain($domain_name, $env);

  if ($result->{error}) {
    return $self->render(json => { error => $result->{error} }, status => 400);
  }

  return $self->render(json => { success => 1 });
}

# Contact management

sub contacts ($self) {
  return unless $self->access({ admin => 1 });

  my $title = $self->app->__('Contacts');
  my $web = { title => $title };
  my $accept = $self->req->headers->{headers}->{accept}->[0];

  if ($accept !~ /json/) {
    $web->{sidebar} = $self->render_to_string(template => 'realtimeregister/chunks/sidebar', format => 'html');
    $web->{script} .= $self->render_to_string(format => 'js');
    return $self->render(web => $web, title => $title, headline => 'realtimeregister/chunks/headline');
  } else {
    my $env = $self->param('env') // 'production';
    my $contacts = $self->app->realtimeregister->getContacts({}, $env);
    return $self->render(json => { contacts => $contacts });
  }
}

sub contact ($self) {
  return unless $self->access({ admin => 1 });

  my $contact_handle = $self->stash('handle');
  my $title = $self->app->__('Contact: ') . $contact_handle;
  my $web = { title => $title };
  my $accept = $self->req->headers->{headers}->{accept}->[0];

  if ($accept !~ /json/) {
    $web->{sidebar} = $self->render_to_string(template => 'realtimeregister/chunks/sidebar', format => 'html');
    $web->{script} .= $self->render_to_string(format => 'js');
    return $self->render(web => $web, title => $title, headline => 'realtimeregister/chunks/headline');
  } else {
    my $env = $self->param('env') // 'production';
    my $contact = $self->app->realtimeregister->getContact($contact_handle, $env);
    return $self->render(json => { contact => $contact });
  }
}

sub create_contact ($self) {
  return unless $self->access({ admin => 1 });

  my $contact_data = $self->req->json;
  my $env = $self->param('env') // 'production';

  my $result = $self->app->realtimeregister->createContact($contact_data, $env);

  if ($result->{error}) {
    return $self->render(json => { error => $result->{error} }, status => 400);
  }

  return $self->render(json => { success => 1, contact => $result });
}

sub update_contact ($self) {
  return unless $self->access({ admin => 1 });

  my $contact_handle = $self->stash('handle');
  my $contact_data = $self->req->json;
  my $env = $self->param('env') // 'production';

  my $result = $self->app->realtimeregister->updateContact($contact_handle, $contact_data, $env);

  if ($result->{error}) {
    return $self->render(json => { error => $result->{error} }, status => 400);
  }

  return $self->render(json => { success => 1, contact => $result });
}

sub delete_contact ($self) {
  return unless $self->access({ admin => 1 });

  my $contact_handle = $self->stash('handle');
  my $env = $self->param('env') // 'production';

  my $result = $self->app->realtimeregister->deleteContact($contact_handle, $env);

  if ($result->{error}) {
    return $self->render(json => { error => $result->{error} }, status => 400);
  }

  return $self->render(json => { success => 1 });
}

1;
