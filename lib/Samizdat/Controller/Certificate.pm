package Samizdat::Controller::Certificate;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Data::Dumper;

# Field definitions for validation and form handling
my $fields = [ qw(domain commonname issuer certificate privatekey chain expires_at status notes) ];
my $checkfields = [ qw(active autorenew) ];
my $setfields = [ qw(created creator updated updater) ];


# Index action - list all certificates or return JSON data
sub index($self) {
  my $accept = $self->req->headers->accept || '';

  # HTML view
  if ($accept !~ /json/) {
    my $title = $self->app->__('Certificates');
    my $web = { title => $title };

    # Render JavaScript template into web->script for inclusion in layout
    $web->{script} = $self->render_to_string(
      template => 'certificates/index',
      format   => 'js'
    );

    $self->stash(
      headline => 'certificate/chunks/headline'
    );

    return $self->render(
      web      => $web,
      title    => $title,
      template => 'certificate/index',
      status   => 200
    );
  } else {
    # JSON API response
    # Require authentication for JSON data
    return if !$self->access({ 'valid-user' => 1 });

    my $searchterm = $self->param('searchterm') || '';
    my $page = $self->param('page') || 1;
    my $limit = $self->param('limit') || $self->app->config->{pagination}->{perpage} || 10;
    my $offset = ($page - 1) * $limit;

    my $certificates;
    if ($searchterm) {
      $certificates = $self->app->certificate->search($searchterm, {
        limit  => $limit,
        offset => $offset
      });
    } else {
      $certificates = $self->app->certificate->get({
        limit  => $limit,
        offset => $offset
      });
    }

    my $total = $self->app->certificate->count();

    return $self->render(json => {
      certificates => $certificates,
      pagination   => {
        page  => $page,
        limit => $limit,
        total => $total,
        pages => int(($total + $limit - 1) / $limit)
      },
      searchterm => $searchterm
    });
  }
}


# Show action - display single certificate
sub show($self) {
  my $id = $self->param('id');
  my $accept = $self->req->headers->accept || '';

  if ($accept !~ /json/) {
    my $certificate = $self->app->certificate->find($id);
    if (!$certificate) {
      return $self->render(
        template => 'not_found',
        status   => 404
      );
    }

    my $title = $certificate->{domain};
    my $web = { title => $title };

    $web->{script} = $self->render_to_string(
      template => 'certificates/show/index',
      format   => 'js'
    );

    return $self->render(
      web         => $web,
      title       => $title,
      certificate => $certificate,
      template    => 'certificates/show/index'
    );
  } else {
    # JSON API response

    return if !$self->access({ 'valid-user' => 1 });

    my $certificate = $self->app->certificate->find($id);
    if (!$certificate) {
      return $self->render(json => { success => 0, error => $self->app->__('Certificate not found') }, status => 404);
    }

    return $self->render(json => { success => 1, certificate => $certificate });
  }
}

# Edit action - show edit form or return data for editing
sub edit($self) {
  my $id = $self->param('id') || 'new';
  my $accept = $self->req->headers->accept || '';

  if ($accept !~ /json/) {
    my $certificate = {};
    my $title = $self->app->__('New Certificate');

    if ($id ne 'new') {
      $certificate = $self->app->certificate->find($id) || {};
      $title = $self->app->__('Edit Certificate');
    }

    my $web = { title => $title };

    # Include toast notification template
    my $toast = $self->render_to_string(
      template => 'chunks/toast',
      format   => 'html',
      toast    => {
        title => $self->app->__('Updated'),
        body  => $self->app->__('Changes saved successfully.'),
        icon  => $self->app->icon('check-circle-fill', { extraclass => 'mx-2 text-success' }),
        time  => '',
        id    => 'certificate-toast',
      }
    );

    $web->{script} = $self->render_to_string(
      template => 'certificates/edit/index',
      format   => 'js',
      toast    => $toast
    );

    $self->stash(
      fields      => $fields,
      checkfields => $checkfields,
      setfields   => $setfields
    );

    return $self->render(
      web         => $web,
      title       => $title,
      certificate => $certificate,
      template    => 'certificates/edit/index'
    );
  } else {
    # JSON API response

    return if !$self->access({ admin => 1 });

    if ($id eq 'new') {
      return $self->render(json => {
        success     => 1,
        certificate => {
          status   => 'active',
          active   => 1,
          autorenew => 0
        }
      });
    }

    my $certificate = $self->app->certificate->find($id);
    if (!$certificate) {
      return $self->render(json => { success => 0, error => $self->app->__('Certificate not found') }, status => 404);
    }

    return $self->render(json => { success => 1, certificate => $certificate });
  }
}


# Create action - handle POST to create new certificate
sub create($self) {
  # Require admin access for creation
  return if !$self->access({ admin => 1 });

  my $formdata = $self->_formdata();
  if (!$formdata) {
    return $self->render(json => { success => 0, error => $self->app->__('Invalid form data') }, status => 400);
  }

  # Add creator information
  $formdata->{certificate}->{creator} = $self->session('userid');

  my $certificate = $self->app->certificate->create($formdata->{certificate});
  if (!$certificate) {
    return $self->render(json => { success => 0, error => $self->app->__('Failed to create certificate') }, status => 500);
  }
  return $self->render(json => { success => 1, certificate => $certificate, message => $self->app->__('Certificate created successfully') });
}


# Update action - handle PUT/PATCH to update certificate
sub update($self) {
  # Require admin access for updates
  return if !$self->access({ admin => 1 });

  my $id = $self->param('id');
  my $formdata = $self->_formdata();
  if (!$formdata) {
    return $self->render(json => { success => 0, error => $self->app->__('Invalid form data') }, status => 400);
  }

  # Add updater information
  $formdata->{certificate}->{updater} = $self->session('userid');

  my $certificate = $self->app->certificate->update($id, $formdata->{certificate});
  if (!$certificate) {
    return $self->render(json => { success => 0, error => $self->app->__('Failed to update certificate') }, status => 500);
  }

  return $self->render(json => { success => 1, certificate => $certificate, message => $self->app->__('Certificate updated successfully') });
}


# Delete action - handle DELETE request
sub delete($self) {
  # Require admin access for deletion
  return if !$self->access({ admin => 1 });

  my $id = $self->param('id');

  my $certificate = $self->app->certificate->delete($id);
  if (!$certificate) {
    return $self->render(json => { success => 0, error => $self->app->__('Failed to delete certificate') }, status => 500);
  }

  return $self->render(json => { success => 1, message => $self->app->__('Certificate deleted successfully') });
}

# Expiring action - show certificates expiring soon
sub expiring($self) {
  return if !$self->access({ 'valid-user' => 1 });

  my $days = $self->param('days') || 30;
  my $certificates = $self->app->certificate->get_expiring($days);

  return $self->render(json => { success => 1, certificates => $certificates });
}

# Renew action - trigger certificate renewal
sub renew($self) {
  return if !$self->access({ admin => 1 });

  my $id = $self->param('id');

  # TODO: Implement certificate renewal logic (e.g., ACME/Let's Encrypt)

  return $self->render(json => { success => 1, message => $self->app->__('Certificate renewal initiated') });
}

# Private helper to extract and validate form data
sub _formdata($self) {
  my $result = $self->req->params->to_hash;
  my $formdata = { certificate => {} };

  # Extract regular fields
  for my $field (@{$fields}) {
    $formdata->{certificate}->{$field} = $result->{$field} if defined $result->{$field};
  }

  # Extract checkbox fields (convert to integer)
  for my $checkfield (@{$checkfields}) {
    $formdata->{certificate}->{$checkfield} = $result->{$checkfield} ? 1 : 0;
  }

  return $formdata;
}

1;
