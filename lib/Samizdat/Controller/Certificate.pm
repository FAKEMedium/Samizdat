package Samizdat::Controller::Certificate;

use Mojo::Base 'Mojolicious::Controller', -signatures;

# Field definitions matching migration 24 schema
my $fields = [qw(customerid value fullvalue notafter keyfile certfile hash issuerid)];

sub index ($self) {
  my $accept = $self->req->headers->accept // '';

  if ($accept !~ /json/) {
    my $title = $self->app->__('Certificates');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'certificate/index', format => 'js');
    return $self->render(
      web      => $web,
      title    => $title,
      template => 'certificate/index',
      status   => 200
    );
  } else {
    return unless $self->access({ admin => 1 });

    my $customerid = $self->param('customerid');
    my $page = $self->param('page') // 1;
    my $limit = $self->param('limit') // $self->perpage;
    my $offset = ($page - 1) * $limit;

    my $params = { limit => $limit, offset => $offset };
    $params->{where} = { customerid => int($customerid) } if $customerid;

    my $certificates = $self->certificate->get($params);
    my $total = $self->certificate->count($params);

    return $self->render(json => {
      success      => 1,
      certificates => $certificates,
      pagination   => {
        page  => $page,
        limit => $limit,
        total => $total,
        pages => int(($total + $limit - 1) / $limit)
      }
    });
  }
}

sub show ($self) {
  my $id = $self->param('id');
  my $accept = $self->req->headers->accept // '';

  if ($accept !~ /json/) {
    $self->stash(docpath => '/certificates/show/index.html');
    my $title = $self->app->__('Certificate');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'certificate/show/index', format => 'js');
    return $self->render(
      web      => $web,
      title    => $title,
      template => 'certificate/show/index',
      status   => 200
    );
  } else {
    return unless $self->access({ admin => 1 });

    my $certificate = $self->certificate->find(int($id));
    if (!$certificate) {
      return $self->render(json => { success => 0, error => 'Certificate not found' }, status => 404);
    }

    return $self->render(json => { success => 1, certificate => $certificate });
  }
}

sub edit ($self) {
  my $id = $self->param('id') // 'new';
  my $accept = $self->req->headers->accept // '';

  if ($accept !~ /json/) {
    $self->stash(docpath => '/certificates/edit/index.html');
    my $title = $id eq 'new' ? $self->app->__('New Certificate') : $self->app->__('Edit Certificate');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'certificate/edit/index', format => 'js');
    return $self->render(
      web      => $web,
      title    => $title,
      template => 'certificate/edit/index',
      status   => 200
    );
  } else {
    return unless $self->access({ admin => 1 });

    if ($id eq 'new') {
      my $issuers = $self->certificate->issuers;
      return $self->render(json => { success => 1, certificate => {}, issuers => $issuers });
    }

    my $certificate = $self->certificate->find(int($id));
    if (!$certificate) {
      return $self->render(json => { success => 0, error => 'Certificate not found' }, status => 404);
    }

    my $issuers = $self->certificate->issuers;
    return $self->render(json => { success => 1, certificate => $certificate, issuers => $issuers });
  }
}

sub create ($self) {
  return unless $self->access({ admin => 1 });

  my $data = $self->req->json // $self->req->params->to_hash;

  my $certificate = $self->certificate->create($data);
  if (!$certificate) {
    return $self->render(json => { success => 0, error => 'Failed to create certificate' }, status => 500);
  }

  return $self->render(json => { success => 1, certificate => $certificate }, status => 201);
}

sub update ($self) {
  return unless $self->access({ admin => 1 });

  my $id = int($self->param('id'));
  my $data = $self->req->json // $self->req->params->to_hash;

  my $certificate = $self->certificate->update($id, $data);
  if (!$certificate) {
    return $self->render(json => { success => 0, error => 'Failed to update certificate' }, status => 500);
  }

  return $self->render(json => { success => 1, certificate => $certificate });
}

sub delete ($self) {
  return unless $self->access({ admin => 1 });

  my $id = int($self->param('id'));

  my $certificate = $self->certificate->delete($id);
  if (!$certificate) {
    return $self->render(json => { success => 0, error => 'Failed to delete certificate' }, status => 500);
  }

  return $self->render(json => { success => 1, message => 'Certificate deleted' });
}

sub expiring ($self) {
  my $accept = $self->req->headers->accept // '';

  if ($accept !~ /json/) {
    my $title = $self->app->__('Expiring Certificates');
    my $web = { title => $title };
    return $self->render(
      web      => $web,
      title    => $title,
      template => 'certificate/expiring/index',
      status   => 200
    );
  } else {
    return unless $self->access({ admin => 1 });

    my $days = $self->param('days') // 30;
    my $certificates = $self->certificate->get_expiring(int($days));

    return $self->render(json => { success => 1, certificates => $certificates, days => $days });
  }
}

sub renew ($self) {
  my $accept = $self->req->headers->accept // '';

  if ($accept !~ /json/) {
    $self->stash(docpath => '/certificates/renew/index.html');
    my $title = $self->app->__('Renew Certificate');
    my $web = { title => $title };
    return $self->render(
      web      => $web,
      title    => $title,
      template => 'certificate/renew/index',
      status   => 200
    );
  } else {
    return unless $self->access({ admin => 1 });

    my $id = int($self->param('id'));

    # TODO: Implement certificate renewal logic (e.g., ACME/Let's Encrypt)
    # This would typically:
    # 1. Generate new CSR
    # 2. Submit to CA (Let's Encrypt, etc.)
    # 3. Update certificate record with new value/fullvalue/notafter

    return $self->render(json => { success => 1, message => 'Certificate renewal initiated' });
  }
}

sub issuers ($self) {
  return unless $self->access({ admin => 1 });

  my $issuers = $self->certificate->issuers;
  return $self->render(json => { success => 1, issuers => $issuers });
}

1;
