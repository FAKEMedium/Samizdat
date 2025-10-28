package Samizdat::Controller::Example;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Data::Dumper;

# Field definitions for validation and form handling
my $fields = [ qw(title description content status category tags) ];
my $checkfields = [ qw(active featured published) ];
my $setfields = [ qw(created creator updated updater) ];


# Index action - list all examples or return JSON data
sub index($self) {
  my $accept = $self->req->headers->accept || '';

  # HTML view
  if ($accept !~ /json/) {
    my $title = $self->app->__('Examples');
    my $web = { title => $title };

    # Render JavaScript template into web->script for inclusion in layout
    $web->{script} = $self->render_to_string( template => 'example/index', format   => 'js' );

    $self->stash(
      headline => 'example/chunks/headline'
    );

    return $self->render(
      web      => $web,
      title    => $title,
      template => 'example/index',
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

    my $examples;
    if ($searchterm) {
      $examples = $self->app->example->search($searchterm, { limit  => $limit, offset => $offset });
    } else {
      $examples = $self->app->example->get({ limit  => $limit, offset => $offset });
    }

    my $total = $self->app->example->count();

    return $self->render(json => {
      examples   => $examples,
      pagination => {
        page  => $page,
        limit => $limit,
        total => $total,
        pages => int(($total + $limit - 1) / $limit)
      },
      searchterm => $searchterm
    });
  }
}


# Show action - display single example
sub show($self) {
  my $id = $self->param('id');
  my $accept = $self->req->headers->accept || '';

  if ($accept !~ /json/) {
    my $example = $self->app->example->find($id);
    if (!$example) {
      return $self->render(
        template => 'not_found',
        status   => 404
      );
    }

    my $title = $example->{title};
    my $web = { title => $title };

    $web->{script} = $self->render_to_string( template => 'example/show/index', format   => 'js' );

    return $self->render(
      web      => $web,
      title    => $title,
      template => 'example/show/index'
    );
  } else {
    # JSON API response

    return if !$self->access({ 'valid-user' => 1 });

    my $example = $self->app->example->find($id);
    if (!$example) {
      return $self->render(json => { success => 0, error => $self->app->__('Example not found') }, status => 404);
    }

    return $self->render(json => { success => 1, example => $example });
  }
}

# Edit action - show edit form or return data for editing
sub edit($self) {
  my $id = $self->param('id') || 'new';
  my $accept = $self->req->headers->accept || '';

  if ($accept !~ /json/) {
    my $example = {};
    my $title = $self->app->__('New Example');

    if ($id ne 'new') {
      $example = $self->app->example->find($id) || {};
      $title = $self->app->__('Edit Example');
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
        id    => 'example-toast',
      }
    );
    $web->{sidebar} = $self->render_to_string(template => 'example/chunks/sidebar', format => 'html');
    $web->{script} = $self->render_to_string(template => 'example/edit/index', format => 'js', toast    => $toast);

    $self->stash(
      fields      => $fields,
      checkfields => $checkfields,
      setfields   => $setfields
    );

    return $self->render(
      web      => $web,
      title    => $title,
      example  => $example,
      template => 'example/edit/index'
    );
  } else {
    # JSON API response

    return if !$self->access({ admin => 1 });

    if ($id eq 'new') {
      return $self->render(json => {
        success => 1,
        example => {
          status    => 'draft',
          active    => 0,
          featured  => 0,
          published => 0
        }
      });
    }

    my $example = $self->app->example->find($id);
    if (!$example) {
      return $self->render(json => { success => 0, error => $self->app->__('Example not found') }, status => 404);
    }

    return $self->render(json => { success => 1, example => $example });
  }
}


# Create action - handle POST to create new example
sub create($self) {
  # Require admin access for creation
  return if !$self->access({ admin => 1 });

  my $formdata = $self->_formdata();
  if (!$formdata) {
    return $self->render(json => { success => 0, error => $self->app->__('Invalid form data') }, status => 400);
  }

  # Add creator information
  $formdata->{example}->{creator} = $self->session('userid');

  my $example = $self->app->example->create($formdata->{example});
  if (!$example) {
    return $self->render(json => { success => 0, error => $self->app->__('Failed to create example') }, status => 500);
  }
  return $self->render(json => { success => 1, example => $example, message => $self->app->__('Example created successfully') });
}


# Update action - handle PUT/PATCH to update example
sub update($self) {
  # Require admin access for updates
  return if !$self->access({ admin => 1 });

  my $id = $self->param('id');
  my $formdata = $self->_formdata();
  if (!$formdata) {
    return $self->render(json => { success => 0, error => $self->app->__('Invalid form data') }, status => 400);
  }

  # Add updater information
  $formdata->{example}->{updater} = $self->session('userid');

  my $example = $self->app->example->update($id, $formdata->{example});
  if (!$example) {
    return $self->render(json => { success => 0, error => $self->app->__('Failed to update example') }, status => 500);
  }

  return $self->render(json => { success => 1, example => $example, message => $self->app->__('Example updated successfully') });
}


# Delete action - handle DELETE request
sub delete($self) {
  # Require admin access for deletion
  return if !$self->access({ admin => 1 });

  my $id = $self->param('id');

  my $example = $self->app->example->delete($id);
  if (!$example) {
    return $self->render(json => { success => 0, error => $self->app->__('Failed to delete example') }, status => 500);
  }

  return $self->render(json => { success => 1, message => $self->app->__('Example deleted successfully') });
}

# Private helper to extract and validate form data
sub _formdata($self) {
  my $result = $self->req->params->to_hash;
  my $formdata = { example => {} };

  # Extract regular fields
  for my $field (@{$fields}) {
    $formdata->{example}->{$field} = $result->{$field} if defined $result->{$field};
  }

  # Extract checkbox fields (convert to integer)
  for my $checkfield (@{$checkfields}) {
    $formdata->{example}->{$checkfield} = $result->{$checkfield} ? 1 : 0;
  }

  # Handle tags as array if comma-separated
  if ($formdata->{example}->{tags} && !ref $formdata->{example}->{tags}) {
    $formdata->{example}->{tags} = [ split /,\s*/, $formdata->{example}->{tags} ];
  }

  return $formdata;
}

1;