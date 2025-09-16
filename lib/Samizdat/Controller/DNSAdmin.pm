package Samizdat::Controller::DNSAdmin;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Data::Dumper;

# Simple auth check – assumes a "current_user" helper exists.
sub check_auth($self) {
  return 1 if $self->current_user;
  $self->flash(error => $self->app->__('Please log in to access that page'));
  $self->redirect_to('login');
  return undef;
}


sub index($self) {
  my $title = $self->app->__('DNS management');
  my $web = { title => $title };
  my $zones = $self->dnsadmin->list_zones;
  if ($self->req->headers->accept =~ m{application/json}) {
    $self->render(json => { zones => $zones });
  } else {
    $web->{script} .= $self->render_to_string(template => 'dnsadmin/index', format => 'js');
    $self->stash(web => $web);
    $self->render(template => 'dnsadmin/index');
  }
}

### Zone CRUD

sub zones($self) {
  my $title = $self->app->__('DNS Zones');
  my $web = { title => $title };
  if ($self->req->headers->accept =~ m{application/json}) {
    my $searchtern = $self->param('searchterm') // undef;
    my $zones = $self->dnsadmin->list_zones({ searchterm => $searchtern });
    $self->render(json => { zones => $zones });
  } else {
    $web->{script} .= $self->render_to_string(template => 'dnsadmin/zones/index', format => 'js');
    $self->stash(web => $web, title => $title);
    $self->render(template => 'dnsadmin/zones/index');
  }
}

# Helper method to determine if the request expects JSON.
sub is_json_request ($self) {
  return $self->req->headers->accept =~ m{application/json};
}

# Render a new-zone form.
sub new_zone ($self) {
  return $self->render(json => { zone => {} }) if $self->is_json_request;

  my $title = $self->app->__('Edit zone');
  my $web = { title => $title };
  $web->{script} .= $self->render_to_string(template => 'dnsadmin/zones/edit/index', format => 'js');
  $self->stash(title => $title, web => $web);
  return $self->render(template => 'dnsadmin/zones/edit/index');
}

# Create a new zone.
sub create_zone ($self) {
  my $title = $self->app->__('Edit zone');
  my $web = { title => $title };
  my $zone_data = {
    name => $self->param('name'),
    kind => $self->param('kind') // 'Master',
  };
  my $result = $self->dnsadmin->create_zone($zone_data);

  if ($self->is_json_request) {
    return $self->render(json => {
      success => $result->{success} ? 1 : 0,
      toast   => $result->{success}
        ? $self->app->__('Zone created successfully')
        : ($result->{error} // $self->app->__('Failed to create zone')),
    });
  }

  if ($result->{success}) {
    return $self->redirect_to('dnsadmin_index');
  } else {
    $self->stash(toast => $result->{error} // $self->app->__('Failed to create zone'));
    $web->{script} .= $self->render_to_string(template => 'dnsadmin/zones/edit/index', format => 'js');
    $self->stash(title => $title, web => $web);
  return $self->render(template => 'dnsadmin/zones/edit/index');
  }
}

# Edit an existing zone.
sub edit_zone ($self) {
  my $zone_id = $self->stash('zone_id') // '';
  my $zone    = $self->dnsadmin->get_zone($zone_id);

  unless ($zone) {
    if ($self->is_json_request) {
      return $self->render(json => { success => 0, toast => $self->app->__('Zone not found') });
    }
    return $self->redirect_to('dnsadmin_index');
  }

  return $self->render(json => $zone) if $self->is_json_request;

  my $title = $self->app->__('Edit zone');
  my $web = { title => $title };
  $web->{script} .= $self->render_to_string(template => 'dnsadmin/zones/edit/index', format => 'js');
  $self->stash(title => $title, web => $web);
  return $self->render(template => 'dnsadmin/zones/edit/index');
}

# Update an existing zone.
sub update_zone ($self) {
  my $zone_id   = $self->stash('zone_id') // '';
  my $zone_data = {
    name => $self->param('name'),
    kind => $self->param('kind'),
  };
  my $result = $self->dnsadmin->update_zone($zone_id, $zone_data);

  if ($self->is_json_request) {
    return $self->render(json => {
      success => $result->{success} ? 1 : 0,
      toast   => $result->{success} ? $self->app->__('Zone updated successfully')
        : ($result->{error} // $self->app->__('Failed to update zone')),
    });
  }

  if ($result->{success}) {
    $self->stash(toast => $self->app->__('Zone updated successfully'));
    return $self->redirect_to('dnsadmin_index');
  }
  else {
    $self->stash(toast => $result->{error} // $self->app->__('Failed to update zone'));

    my $title = $self->app->__('Edit zone');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'dnsadmin/zones/edit/index', format => 'js');
    $self->stash(title => $title, web => $web);
    return $self->render(template => 'dnsadmin/zones/edit/index');
  }
}

sub delete_zone($self) {
  my $zone_id = $self->stash('zone_id') // '';
  my $result = $self->dnsadmin->delete_zone($zone_id);
  $self->flash(message => $result->{success}
    ? $self->app->__('Zone deleted successfully')
    : ($result->{error} // $self->app->__('Failed to delete zone'))
  );
  $self->redirect_to('dnsadmin_index');
}

### Record CRUD (for a given zone)

sub records($self) {
  my $title = $self->app->__('Zone records');
  my $web = { title => $title };
  my $zone_id = $self->stash('zone_id');
  my $rrsets = $self->dnsadmin->list_rrsets($zone_id);
  say Dumper $rrsets;
  if ($self->req->headers->accept =~ m{application/json}) {
    $self->render(json => { zone_id => $zone_id, rrsets => $rrsets });
  } else {
    $web->{script} .= $self->render_to_string(template => 'dnsadmin/records/index', format => 'js');
    $self->stash(web => $web, title => $title);
    $self->render(template => 'dnsadmin/records/index');
  }
}

sub new_record($self) {
  my $zone_id = $self->stash('zone_id');
  $self->stash(record => {}, zone_id => $zone_id);
  $self->render(template => 'dnsadmin/records/edit/index');
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
  my $result = $self->dnsadmin->create_record($zone_id, $record_data);
  if ($result->{success}) {
    $self->flash(message => $self->app->__('Record created successfully'));
    return $self->redirect_to('dnsadmin_record_index', zone_id => $zone_id);
  }
  $self->flash(error => $result->{error} // $self->app->__('Failed to create record'));
  $self->stash(record => $record_data, zone_id => $zone_id);
  $self->render(template => 'dnsadmin/records/edit/index');
}

sub edit_record($self) {
  my $zone_id = $self->stash('zone_id');
  my $record_id = $self->stash('record_id');
  my $record = $self->dnsadmin->get_record($zone_id, $record_id);
  unless ($record) {
    $self->flash(error => 'Record not found');
    return $self->redirect_to('dnsadmin_record_index', zone_id => $zone_id);
  }
  $self->stash(record => $record, zone_id => $zone_id);
  $self->render(template => 'dnsadmin/records/edit/index');
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
  my $result = $self->dnsadmin->update_record($zone_id, $record_id, $record_data);
  if ($result->{success}) {
    $self->flash(message => $self->app->__('Record updated successfully'));
    return $self->redirect_to('dnsadmin_record_index', zone_id => $zone_id);
  }
  $self->flash(error => $result->{error} // $self->app->__('Failed to update record'));
  $self->stash(record => $record_data, zone_id => $zone_id);
  $self->render(template => 'dnsadmin/records/edit/index');
}

sub delete_record($self) {
  my $zone_id = $self->stash('zone_id');
  my $record_id = $self->stash('record_id');
  my $result = $self->dnsadmin->delete_record($zone_id, $record_id);
  $self->flash(message => $result->{success}
    ? $self->app->__('Record deleted successfully')
    : ($result->{error} // $self->app->__('Failed to delete record'))
  );
  $self->redirect_to('dnsadmin_record_index', zone_id => $zone_id);
}

1;