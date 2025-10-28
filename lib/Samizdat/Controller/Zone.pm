package Samizdat::Controller::Zone;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Data::Dumper;

### Zone CRUD

sub index($self) {
  my $title = $self->app->__('DNS Zones');
  my $web = { title => $title };
  if ($self->req->headers->accept =~ m{application/json}) {
    return unless $self->access({ admin => 1 });
    my $searchtern = $self->param('searchterm') // undef;
    my $zones = $self->zone->list_zones({ searchterm => $searchtern });
    $self->render(json => { zones => $zones });
  } else {
    $web->{script} .= $self->render_to_string(template => 'zone/index', format => 'js');
    $self->render(web => $web, title => $title, template => 'zone/index');
  }
}

# Helper method to determine if the request expects JSON.
sub is_json_request ($self) {
  return $self->req->headers->accept =~ m{application/json};
}

# Render a new-zone form.
sub new_zone ($self) {
  my $title = $self->app->__('New zone');
  my $web = { title => $title };
  $web->{script} .= $self->render_to_string(template => 'zone/edit/index', format => 'js');
  $self->stash(web => $web);
  return $self->render(template => 'zone/edit/index', layout => 'modal');
}


# Create a new zone.
sub create_zone ($self) {
  return unless $self->access({ admin => 1 });

  my $json = $self->req->json;
  my $zone_data = {
    name => $json->{name},
    kind => $json->{kind} // 'Master',
  };
  my $result = $self->zone->create_zone($zone_data);

  return $self->render(json => {
    success => $result->{success} ? 1 : 0,
    toast   => $result->{success}
      ? $self->app->__('Zone created successfully')
      : ($result->{error} // $self->app->__('Failed to create zone'))
  });
}


# Edit an existing zone.
sub edit_zone ($self) {
  my $zone_id = $self->stash('zone_id') // '';
  my $zone    = $self->zone->get_zone($zone_id);

  unless ($zone) {
    if ($self->is_json_request) {
      return $self->render(json => { success => 0, toast => $self->app->__('Zone not found') });
    }
    return $self->redirect_to('zone_index');
  }

  if ($self->is_json_request) {
    return unless $self->access({ admin => 1 });
    return $self->render(json => $zone);
  }

  my $title = $self->app->__('Edit zone');
  my $web = { title => $title };
  $web->{script} .= $self->render_to_string(template => 'zone/edit/index', format => 'js');
  $self->stash(web => $web);
  return $self->render(template => 'zone/edit/index', layout => 'modal');
}


# Update an existing zone.
sub update_zone ($self) {
  return unless $self->access({ admin => 1 });

  my $zone_id = $self->stash('zone_id') // '';
  my $json = $self->req->json;
  my $zone_data = {
    name => $json->{name},
    kind => $json->{kind},
  };
  my $result = $self->zone->update_zone($zone_id, $zone_data);

  return $self->render(json => {
    success => $result->{success} ? 1 : 0,
    toast   => $result->{success}
      ? $self->app->__('Zone updated successfully')
      : ($result->{error} // $self->app->__('Failed to update zone'))
  });
}


sub delete_zone($self) {
  return unless $self->access({ admin => 1 });

  my $zone_id = $self->stash('zone_id') // '';
  my $result = $self->zone->delete_zone($zone_id);

  return $self->render(json => {
    success => $result->{success} ? 1 : 0,
    toast   => $result->{success}
      ? $self->app->__('Zone deleted successfully')
      : ($result->{error} // $self->app->__('Failed to delete zone'))
  });
}


### Record CRUD (for a given zone)

sub records($self) {
  my $title = $self->app->__('Zone records');
  my $web = { title => $title };
  my $zone_id = $self->stash('zone_id');
  if ($self->req->headers->accept =~ m{application/json}) {
    return unless $self->access({ admin => 1 });
    my $rrsets = $self->zone->list_rrsets($zone_id);
    say Dumper $rrsets;
    $self->render(json => { zone_id => $zone_id, rrsets => $rrsets });
  } else {
    $web->{script} .= $self->render_to_string(template => 'zone/records/index', format => 'js');
    $self->render(web => $web, title => $title, template => 'zone/records/index');
  }
}


sub new_record($self) {
  my $zone_id = $self->stash('zone_id');
  my $title = $self->app->__('New record');
  my $web = { title => $title };
  $web->{script} .= $self->render_to_string(template => 'zone/records/edit/index', format => 'js');
  $self->stash(web => $web, zone_id => $zone_id);
  $self->render(template => 'zone/records/edit/index', layout => 'modal');
}


sub create_record($self) {
  return unless $self->access({ admin => 1 });

  my $zone_id = $self->stash('zone_id');
  my $json = $self->req->json;
  my $record_data = {
    name     => $json->{name},
    type     => $json->{type},
    content  => $json->{content},
    ttl      => $json->{ttl} || 3600,
    priority => $json->{priority} || 0,
  };
  my $result = $self->zone->create_record($zone_id, $record_data);

  return $self->render(json => {
    success => $result->{success} ? 1 : 0,
    toast   => $result->{success}
      ? $self->app->__('Record created successfully')
      : ($result->{error} // $self->app->__('Failed to create record'))
  });
}


sub edit_record($self) {
  my $zone_id = $self->stash('zone_id');
  my $record_id = $self->stash('record_id');

  if ($self->is_json_request) {
    return unless $self->access({ admin => 1 });
    my $record = $self->zone->get_record($zone_id, $record_id);
    unless ($record) {
      return $self->render(json => { success => 0, toast => $self->app->__('Record not found') });
    }
    return $self->render(json => { success => 1, record => $record });
  }

  my $title = $self->app->__('Edit record');
  my $web = { title => $title };
  $web->{script} .= $self->render_to_string(template => 'zone/records/edit/index', format => 'js');
  $self->stash(web => $web, zone_id => $zone_id);
  $self->render(template => 'zone/records/edit/index', layout => 'modal');
}


sub update_record($self) {
  return unless $self->access({ admin => 1 });

  my $zone_id = $self->stash('zone_id');
  my $record_id = $self->stash('record_id');
  my $json = $self->req->json;
  my $record_data = {
    name     => $json->{name},
    type     => $json->{type},
    content  => $json->{content},
    ttl      => $json->{ttl},
    priority => $json->{priority},
  };
  my $result = $self->zone->update_record($zone_id, $record_id, $record_data);

  return $self->render(json => {
    success => $result->{success} ? 1 : 0,
    toast   => $result->{success}
      ? $self->app->__('Record updated successfully')
      : ($result->{error} // $self->app->__('Failed to update record'))
  });
}


sub delete_record($self) {
  return unless $self->access({ admin => 1 });

  my $zone_id = $self->stash('zone_id');
  my $record_id = $self->stash('record_id');
  my $result = $self->zone->delete_record($zone_id, $record_id);

  return $self->render(json => {
    success => $result->{success} ? 1 : 0,
    toast   => $result->{success}
      ? $self->app->__('Record deleted successfully')
      : ($result->{error} // $self->app->__('Failed to delete record'))
  });
}

1;