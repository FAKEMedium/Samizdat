package Samizdat::Controller::PowerDNS;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Data::Dumper;

# Simple auth check – assumes a "current_user" helper exists.
sub check_auth($self) {
  return 1 if $self->current_user;
  $self->flash(error => 'Please log in to access that page');
  $self->redirect_to('login');
  return undef;
}

### Zone CRUD

sub index($self) {
  my $title = $self->app->__('DNS Zones');
  my $web = { title => $title };
  my $zones = $self->powerdns_api->list_zones;
  if ($self->req->headers->accept =~ m{application/json}) {
    $self->render(json => { zones => $zones });
  } else {
    $web->{script} .= $self->render_to_string(template => 'powerdns/index', format => 'js');
    $self->stash(web => $web);
    $self->render(template => 'powerdns/index');
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
  return $self->render(json => { zone => {} }) if $self->is_json_request;
  return $self->render(template => 'powerdns/form');
}

# Create a new zone.
sub create_zone ($self) {
  my $title = $self->app->__('New zone');
  my $web = { title => $title };
  my $zone_data = {
    name => $self->param('name'),
    kind => $self->param('kind') // 'Master',
  };
  my $result = $self->powerdns_api->create_zone($zone_data);

  if ($self->is_json_request) {
    return $self->render(json => {
      success => $result->{success} ? 1 : 0,
      toast   => $result->{success} ? 'Zone created successfully'
        : ($result->{error} // 'Failed to create zone'),
    });
  }

  if ($result->{success}) {
    return $self->redirect_to('powerdns_index');
  } else {
    $self->stash(toast => $result->{error} // 'Failed to create zone');
    return $self->render(template => 'powerdns/form');
  }
}

# Edit an existing zone.
sub edit_zone ($self) {
  my $zone_id = $self->param('id');
  my $zone    = $self->powerdns_api->get_zone($zone_id);

  unless ($zone) {
    if ($self->is_json_request) {
      return $self->render(json => { success => 0, toast => 'Zone not found' });
    }
    return $self->redirect_to('powerdns_index');
  }

  return $self->render(json => $zone) if $self->is_json_request;
  return $self->render(template => 'powerdns/form');
}

# Update an existing zone.
sub update_zone ($self) {
  my $zone_id   = $self->param('id');
  my $zone_data = {
    name => $self->param('name'),
    kind => $self->param('kind'),
  };
  my $result = $self->powerdns_api->update_zone($zone_id, $zone_data);

  if ($self->is_json_request) {
    return $self->render(json => {
      success => $result->{success} ? 1 : 0,
      toast   => $result->{success} ? 'Zone updated successfully'
        : ($result->{error} // 'Failed to update zone'),
    });
  }

  if ($result->{success}) {
    $self->stash(toast => 'Zone updated successfully');
    return $self->redirect_to('powerdns_index');
  }
  else {
    $self->stash(toast => $result->{error} // 'Failed to update zone');
    return $self->render(template => 'powerdns/form');
  }
}

sub delete_zone($self) {
  my $zone_id = $self->stash('id');
  my $result = $self->powerdns_api->delete_zone($zone_id);
  $self->flash(message => $result->{success} ? 'Zone deleted successfully' : ($result->{error} // 'Failed to delete zone'));
  $self->redirect_to('powerdns_index');
}

### Record CRUD (for a given zone)

sub list_records($self) {
  my $title = $self->app->__('Zone records');
  my $web = { title => $title };
  my $zone_id = $self->stash('zone_id');
  my $rrsets = $self->powerdns_api->list_rrsets($zone_id);
  say Dumper $rrsets;
  if ($self->req->headers->accept =~ m{application/json}) {
    $self->render(json => { zone_id => $zone_id, rrsets => $rrsets });
  } else {
    $web->{script} .= $self->render_to_string(template => 'powerdns/records', format => 'js');
    $self->stash(web => $web);
    $self->render(template => 'powerdns/records');
  }
}

sub new_record($self) {
  my $zone_id = $self->stash('zone_id');
  $self->stash(record => {}, zone_id => $zone_id);
  $self->render(template => 'powerdns/record_form');
}

sub create_record($self) {
  my $zone_id = $self->stash('zone_id');
  my $record_data = {
    name     => $self->param('name'),
    type     => $self->param('type'),
    content  => $self->param('content'),
    ttl      => $self->param('ttl') || 3600,
    priority => $self->param('priority') || 0,
  };
  my $result = $self->powerdns_api->create_record($zone_id, $record_data);
  if ($result->{success}) {
    $self->flash(message => 'Record created successfully');
    return $self->redirect_to('powerdns_records', zone_id => $zone_id);
  }
  $self->flash(error => $result->{error} // 'Failed to create record');
  $self->stash(record => $record_data, zone_id => $zone_id);
  $self->render(template => 'powerdns/record_form');
}

sub edit_record($self) {
  my $zone_id = $self->stash('zone_id');
  my $record_id = $self->stash('record_id');
  my $record = $self->powerdns_api->get_record($zone_id, $record_id);
  unless ($record) {
    $self->flash(error => 'Record not found');
    return $self->redirect_to('powerdns_records', zone_id => $zone_id);
  }
  $self->stash(record => $record, zone_id => $zone_id);
  $self->render(template => 'powerdns/record_form');
}

sub update_record($self) {
  my $zone_id = $self->stash('zone_id');
  my $record_id = $self->stash('record_id');
  my $record_data = {
    name     => $self->param('name'),
    type     => $self->param('type'),
    content  => $self->param('content'),
    ttl      => $self->param('ttl'),
    priority => $self->param('priority'),
  };
  my $result = $self->powerdns_api->update_record($zone_id, $record_id, $record_data);
  if ($result->{success}) {
    $self->flash(message => 'Record updated successfully');
    return $self->redirect_to('powerdns_records', zone_id => $zone_id);
  }
  $self->flash(error => $result->{error} // 'Failed to update record');
  $self->stash(record => $record_data, zone_id => $zone_id);
  $self->render(template => 'powerdns/record_form');
}

sub delete_record($self) {
  my $zone_id = $self->stash('zone_id');
  my $record_id = $self->stash('record_id');
  my $result = $self->powerdns_api->delete_record($zone_id, $record_id);
  $self->flash(message => $result->{success} ? 'Record deleted successfully' : ($result->{error} // 'Failed to delete record'));
  $self->redirect_to('powerdns_records', zone_id => $zone_id);
}

1;