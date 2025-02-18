package Samizdat::Controller::PowerDNS;
use Mojo::Base 'Mojolicious::Controller', -signatures;

# Simple auth check – assumes a current_user helper exists.
sub check_auth ($self, $c) {
  return 1 if $c->current_user;
  $c->flash(error => 'Please log in to access that page');
  $c->redirect_to('login');
  return undef;
}

### Zone CRUD

sub index ($self, $c) {
  my $zones = $c->powerdns_api->list_zones;
  if ($c->req->headers->accept =~ m{application/json}) {
    $c->render(json => { zones => $zones });
  } else {
    $c->stash(zones => $zones);
    $c->render(template => 'powerdns/index');
  }
}

sub new_zone ($self, $c) {
  $c->stash(zone => {});
  $c->render(template => 'powerdns/form');
}

sub create_zone ($self, $c) {
  my $zone_data = {
    name => $c->param('name'),
    kind => $c->param('kind') // 'Master',
  };
  my $result = $c->powerdns_api->create_zone($zone_data);
  if ($result->{success}) {
    $c->flash(message => 'Zone created successfully');
    return $c->redirect_to('powerdns_index');
  }
  $c->flash(error => $result->{error} // 'Failed to create zone');
  $c->stash(zone => $zone_data);
  $c->render(template => 'powerdns/form');
}

sub edit_zone ($self, $c) {
  my $zone_id = $c->stash('id');
  my $zone = $c->powerdns_api->get_zone($zone_id);
  unless ($zone) {
    $c->flash(error => 'Zone not found');
    return $c->redirect_to('powerdns_index');
  }
  $c->stash(zone => $zone);
  $c->render(template => 'powerdns/form');
}

sub update_zone ($self, $c) {
  my $zone_id = $c->stash('id');
  my $zone_data = {
    name => $c->param('name'),
    kind => $c->param('kind'),
  };
  my $result = $c->powerdns_api->update_zone($zone_id, $zone_data);
  if ($result->{success}) {
    $c->flash(message => 'Zone updated successfully');
    return $c->redirect_to('powerdns_index');
  }
  $c->flash(error => $result->{error} // 'Failed to update zone');
  $c->stash(zone => $zone_data);
  $c->render(template => 'powerdns/form');
}

sub delete_zone ($self, $c) {
  my $zone_id = $c->stash('id');
  my $result = $c->powerdns_api->delete_zone($zone_id);
  $c->flash(message => $result->{success} ? 'Zone deleted successfully' : ($result->{error} // 'Failed to delete zone'));
  $c->redirect_to('powerdns_index');
}

### Record CRUD (for a given zone)

sub list_records ($self, $c) {
  my $zone_id = $c->stash('zone_id');
  my $records = $c->powerdns_api->list_records($zone_id);
  if ($c->req->headers->accept =~ m{application/json}) {
    $c->render(json => { records => $records });
  } else {
    $c->stash(zone_id => $zone_id, records => $records);
    $c->render(template => 'powerdns/records');
  }
}

sub new_record ($self, $c) {
  my $zone_id = $c->stash('zone_id');
  $c->stash(record => {}, zone_id => $zone_id);
  $c->render(template => 'powerdns/record_form');
}

sub create_record ($self, $c) {
  my $zone_id = $c->stash('zone_id');
  my $record_data = {
    name     => $c->param('name'),
    type     => $c->param('type'),
    content  => $c->param('content'),
    ttl      => $c->param('ttl') || 3600,
    priority => $c->param('priority') || 0,
  };
  my $result = $c->powerdns_api->create_record($zone_id, $record_data);
  if ($result->{success}) {
    $c->flash(message => 'Record created successfully');
    return $c->redirect_to('powerdns_records', zone_id => $zone_id);
  }
  $c->flash(error => $result->{error} // 'Failed to create record');
  $c->stash(record => $record_data, zone_id => $zone_id);
  $c->render(template => 'powerdns/record_form');
}

sub edit_record ($self, $c) {
  my $zone_id   = $c->stash('zone_id');
  my $record_id = $c->stash('record_id');
  my $record = $c->powerdns_api->get_record($zone_id, $record_id);
  unless ($record) {
    $c->flash(error => 'Record not found');
    return $c->redirect_to('powerdns_records', zone_id => $zone_id);
  }
  $c->stash(record => $record, zone_id => $zone_id);
  $c->render(template => 'powerdns/record_form');
}

sub update_record ($self, $c) {
  my $zone_id   = $c->stash('zone_id');
  my $record_id = $c->stash('record_id');
  my $record_data = {
    name     => $c->param('name'),
    type     => $c->param('type'),
    content  => $c->param('content'),
    ttl      => $c->param('ttl'),
    priority => $c->param('priority'),
  };
  my $result = $c->powerdns_api->update_record($zone_id, $record_id, $record_data);
  if ($result->{success}) {
    $c->flash(message => 'Record updated successfully');
    return $c->redirect_to('powerdns_records', zone_id => $zone_id);
  }
  $c->flash(error => $result->{error} // 'Failed to update record');
  $c->stash(record => $record_data, zone_id => $zone_id);
  $c->render(template => 'powerdns/record_form');
}

sub delete_record ($self, $c) {
  my $zone_id   = $c->stash('zone_id');
  my $record_id = $c->stash('record_id');
  my $result = $c->powerdns_api->delete_record($zone_id, $record_id);
  $c->flash(message => $result->{success} ? 'Record deleted successfully' : ($result->{error} // 'Failed to delete record'));
  $c->redirect_to('powerdns_records', zone_id => $zone_id);
}

1;