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
    return unless $self->access({ admin => 1 });

    my $customerid = $self->param('customerid');
    my $params = {};
    $params->{where} = { customerid => int($customerid) } if $customerid;

    my $formdata = {
      databases => $self->app->database->get($params),
    };
    return $self->render(json => $formdata);
  }
}

sub types ($self) {
  return unless $self->access({ admin => 1 });
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
    return unless $self->access({ admin => 1 });

    my $params = {};
    if ($databaseid) {
      $params->{where} = { databaseid => int($databaseid) };
    } elsif ($databasename) {
      $params->{where} = { databasename => $databasename };
      $params->{where}->{customerid} = int($customerid) if $customerid;
    }

    my $database = $self->app->database->get($params)->[0];
    return $self->render(json => { database => $database });
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