package Samizdat::Controller::Database;

use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    my $title = $self->app->__('Databases');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'database/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'database/index', databases => [], status => 200);
  } else {
    my $authcookie = $self->cookie($self->config->{manager}->{account}->{authcookiename});
    my $session = $authcookie ? $self->app->account->session($authcookie) : undef;
    my $is_admin = 0;

    if ($session && $session->{username}) {
      my $admins = $self->config->{manager}->{account}->{admins} // {};
      my $superadmins = $self->config->{manager}->{account}->{superadmins} // {};
      $is_admin = 1 if exists $admins->{$session->{username}} || exists $superadmins->{$session->{username}};
    }

    my $customerid = int($self->param('customerid') // 0);

    if (!$is_admin) {
      return unless $self->access({ 'valid-user' => 1 });
      my $user_customerid = $self->app->customer->get_customerid_for_user($session->{userid}, $session->{username});
      return $self->render(json => { databases => [], admin => 0 }) unless $user_customerid;
      $customerid = $user_customerid;
    }

    my $params = {};
    $params->{where} = { customerid => $customerid } if $customerid;

    my $formdata = {
      databases => $self->app->database->get($params),
      admin     => $is_admin ? 1 : 0,
    };
    return $self->render(json => $formdata);
  }
}

sub types ($self) {
  return unless $self->access({ 'valid-user' => 1 });
  return $self->render(json => { types => $self->app->database->get_types });
}

sub get ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  my $databaseid = $self->param('databaseid');
  my $databasename = $self->param('databasename');
  my $customerid = $self->param('customerid');

  if ($accept !~ /json/) {
    $self->stash(docpath => '/databases/database/index.html');
    my $title = $self->app->__('Database');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'database/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'database/index', status => 200);
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
      my $user_customerid = $self->app->customer->get_customerid_for_user($session->{userid}, $session->{username});
      return $self->render(json => { error => 'Database not found' }, status => 404) unless $user_customerid;
      $customerid = $user_customerid;
    }

    my $params = {};
    if ($databaseid) {
      $params->{where} = { databaseid => int($databaseid) };
      $params->{where}->{customerid} = $customerid if $customerid && !$is_admin;
    } elsif ($databasename) {
      $params->{where} = { databasename => $databasename };
      $params->{where}->{customerid} = int($customerid) if $customerid;
    }

    my $database = $self->app->database->get($params)->[0];
    return $self->render(json => { database => $database, admin => $is_admin ? 1 : 0 });
  }
}

sub add ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  my $customerid = $self->param('customerid');

  if ($accept !~ /json/) {
    $self->stash(docpath => '/databases/edit/index.html');
    my $title = $self->app->__('New Database');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'database/edit/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'database/edit/index', status => 200);
  } else {
    return unless $self->access({ admin => 1 });

    my $formdata = {
      database   => { customerid => $customerid ? int($customerid) : undef },
      types      => $self->app->database->get_types,
      customerid => $customerid ? int($customerid) : undef,
    };
    return $self->render(json => $formdata);
  }
}

sub edit ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  my $databaseid = $self->param('databaseid');
  my $databasename = $self->param('databasename');
  my $customerid = $self->param('customerid');

  if ($accept !~ /json/) {
    $self->stash(docpath => '/databases/edit/index.html');
    my $title = $self->app->__('Edit Database');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'database/edit/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'database/edit/index', status => 200);
  } else {
    return unless $self->access({ admin => 1 });

    my $params = {};
    if ($databaseid) {
      $params->{where} = { databaseid => int($databaseid) };
    } elsif ($databasename) {
      $params->{where} = { databasename => $databasename };
      $params->{where}->{customerid} = int($customerid) if $customerid;
    }

    my $database = $self->app->database->get($params)->[0];
    my $formdata = {
      database   => $database,
      types      => $self->app->database->get_types,
      customerid => $database->{customerid},
    };
    return $self->render(json => $formdata);
  }
}

sub create ($self) {
  return unless $self->access({ admin => 1 });

  my $data = $self->req->json // {};
  $data->{creator} = $self->session('user') // '';
  $data->{updater} = $data->{creator};
  $data->{databasetypeid} //= 1;  # Default to mariadb

  my $databaseid = $self->app->database->create($data);
  my $database = $self->app->database->get({ where => { databaseid => $databaseid } })->[0];
  return $self->render(json => { database => $database }, status => 201);
}

sub update ($self) {
  return unless $self->access({ admin => 1 });

  my $databaseid = int($self->param('databaseid'));
  my $data = $self->req->json // {};
  $data->{updater} = $self->session('user') // '';

  $self->app->database->update($databaseid, $data);
  my $database = $self->app->database->get({ where => { databaseid => $databaseid } })->[0];
  return $self->render(json => { database => $database });
}

sub delete ($self) {
  return unless $self->access({ admin => 1 });

  my $databaseid = int($self->param('databaseid'));
  $self->app->database->delete($databaseid);
  return $self->render(json => { success => 1 });
}

1;