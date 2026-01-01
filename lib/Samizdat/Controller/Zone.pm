package Samizdat::Controller::Zone;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Data::Dumper;

### Zone CRUD

sub index($self) {
  # Check for customerid from route (customer-specific zone listing)
  my $customerid = $self->stash('customerid');
  my $title = $customerid
    ? $self->app->__x('DNS Zones for customer {id}', id => $customerid)
    : $self->app->__('DNS Zones');
  my $web = { title => $title };

  if ($self->req->headers->accept =~ m{application/json}) {
    return unless $self->access({ admin => 1 });
    my $searchterm = $self->param('searchterm') // '';
    # Use customerid from route, or account from query param
    my $account = $customerid // $self->param('account') // undef;

    my $zones;
    if ($self->zone->pdns) {
      # Use PostgreSQL for all searches when available (faster)
      $zones = $self->zone->search_zones({
        searchterm => $searchterm || undef,
        account    => $account,
      });
    } else {
      # Fall back to API when PostgreSQL not configured
      $zones = $self->zone->list_zones();
    }

    $self->render(json => { zones => $zones, customerid => $customerid });
  } else {
    # Set docpath for customer-specific routes to use shared cached template
    $self->stash(docpath => '/zone/index.html') if $customerid;

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
    name    => $json->{name},
    kind    => $json->{kind} // 'Native',
    account => $json->{account} // '',
  };

  my $result;
  if ($json->{templateid}) {
    # Create zone from template
    $result = $self->zone->create_zone_from_template($zone_data, $json->{templateid});
  } else {
    $result = $self->zone->create_zone($zone_data);
  }

  return $self->render(json => {
    success => $result->{success} ? 1 : 0,
    toast   => $result->{success}
      ? $self->app->__('Zone created successfully')
      : ($result->{error} // $self->app->__('Failed to create zone'))
  });
}

# List available zone templates.
sub templates ($self) {
  my $title = $self->app->__('Zone Templates');
  my $web = { title => $title };

  if ($self->is_json_request) {
    return unless $self->access({ admin => 1 });
    my $customerid = $self->stash('customerid') // $self->param('customerid');
    my $templates = $self->zone->list_templates({ customerid => $customerid });
    return $self->render(json => { templates => $templates });
  }

  $web->{script} .= $self->render_to_string(template => 'zone/templates/index', format => 'js');
  return $self->render(web => $web, title => $title, template => 'zone/templates/index');
}

# Get a single template with records.
sub get_template ($self) {
  return unless $self->access({ admin => 1 });

  my $templateid = $self->stash('template_id');
  my $template = $self->zone->get_template($templateid);

  return $self->render(json => { template => $template });
}

# Create a new template.
sub create_template ($self) {
  return unless $self->access({ admin => 1 });

  my $json = $self->req->json;
  my $result = $self->zone->create_template($json);

  return $self->render(json => {
    success => $result->{success},
    templateid => $result->{templateid},
    toast => $self->app->__('Template created'),
  });
}

# Update a template.
sub update_template ($self) {
  return unless $self->access({ admin => 1 });

  my $templateid = $self->stash('template_id');
  my $json = $self->req->json;
  my $result = $self->zone->update_template($templateid, $json);

  return $self->render(json => {
    success => $result->{success},
    toast => $self->app->__('Template updated'),
  });
}

# Delete a template.
sub delete_template ($self) {
  return unless $self->access({ admin => 1 });

  my $templateid = $self->stash('template_id');
  my $result = $self->zone->delete_template($templateid);

  return $self->render(json => {
    success => $result->{success},
    toast => $self->app->__('Template deleted'),
  });
}

sub duplicate_template ($self) {
  return unless $self->access({ admin => 1 });

  my $templateid = $self->stash('template_id');
  my $result = $self->zone->duplicate_template($templateid);

  return $self->render(json => {
    success    => $result->{success},
    templateid => $result->{templateid},
    toast      => $self->app->__('Template duplicated'),
  });
}

# Template record CRUD
sub get_template_record ($self) {
  return unless $self->access({ admin => 1 });

  my $recordid = $self->stash('record_id');
  my $record = $self->zone->get_template_record($recordid);

  return $self->render(json => { record => $record });
}

sub create_template_record ($self) {
  return unless $self->access({ admin => 1 });

  my $templateid = $self->stash('template_id');
  my $json = $self->req->json;
  my $result = $self->zone->create_template_record($templateid, $json);

  return $self->render(json => {
    success => $result->{success},
    recordid => $result->{recordid},
    toast => $self->app->__('Record added'),
  });
}

sub update_template_record ($self) {
  return unless $self->access({ admin => 1 });

  my $recordid = $self->stash('record_id');
  my $json = $self->req->json;
  my $result = $self->zone->update_template_record($recordid, $json);

  return $self->render(json => {
    success => $result->{success},
    toast => $self->app->__('Record updated'),
  });
}

sub delete_template_record ($self) {
  return unless $self->access({ admin => 1 });

  my $recordid = $self->stash('record_id');
  my $result = $self->zone->delete_template_record($recordid);

  return $self->render(json => {
    success => $result->{success},
    toast => $self->app->__('Record deleted'),
  });
}


# Render import zone form.
sub import_zone_form ($self) {
  my $title = $self->app->__('Import zone');
  my $web = { title => $title };
  $web->{script} .= $self->render_to_string(template => 'zone/import/index', format => 'js');
  $self->stash(web => $web);
  return $self->render(template => 'zone/import/index', layout => 'modal');
}


# Import a zone from zone file content.
sub import_zone ($self) {
  return unless $self->access({ admin => 1 });

  my $json = $self->req->json;
  my $zone_data = {
    name    => $json->{name},
    kind    => $json->{kind} // 'Native',
    zone    => $json->{zone},
    account => $json->{account} // '',
  };
  my $result = $self->zone->import_zone($zone_data);

  return $self->render(json => {
    success => $result->{success} ? 1 : 0,
    toast   => $result->{success}
      ? $self->app->__('Zone imported successfully')
      : ($result->{error} // $self->app->__('Failed to import zone'))
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

  # Set docpath to ensure static cache goes to /zone/edit/index.html instead of /<zone_id>/index.html
  $self->stash(docpath => '/zone/edit/index.html');

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
    kind    => $json->{kind},    # Zone name is immutable
    account => $json->{account} // '',
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


# Export zone in AXFR format (text/plain).
sub export_zone($self) {
  return unless $self->access({ admin => 1 });

  my $zone_id = $self->stash('zone_id') // '';
  my $result = $self->zone->export_zone($zone_id);

  if ($result->{success}) {
    return $self->render(text => $result->{content}, format => 'txt');
  }

  return $self->render(json => {
    success => 0,
    error => $result->{error} // $self->app->__('Failed to export zone')
  }, status => 400);
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
    # Set docpath to ensure static cache goes to /zone/records/index.html instead of /<zone_id>/records/index.html
    $self->stash(docpath => '/zone/records/index.html');

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
  # For updates, include original content to remove old record
  $record_data->{original_content} = $json->{original_content} if $json->{original_content};
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
  my $record_id = $self->stash('record_id');  # This is the record name
  my $record_type = $self->param('type');      # Type from query param
  my $record_content = $self->param('content'); # Content for multi-record rrsets

  if ($self->is_json_request) {
    return unless $self->access({ admin => 1 });
    my $record = $self->zone->get_record($zone_id, $record_id, $record_type, $record_content);
    unless ($record) {
      return $self->render(json => { success => 0, toast => $self->app->__('Record not found') });
    }
    return $self->render(json => { success => 1, record => $record });
  }

  # Set docpath to ensure static cache goes to /zone/records/edit/index.html instead of /<zone_id>/records/<record_id>/index.html
  $self->stash(docpath => '/zone/records/edit/index.html');

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
  # For updates, include original content to remove old record
  $record_data->{original_content} = $json->{original_content} if $json->{original_content};
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
  # Get content from request body for single record deletion from multi-record rrsets
  my $json = $self->req->json;
  my $content = $json->{content} if $json;
  my $result = $self->zone->delete_record($zone_id, $record_id, $content);

  return $self->render(json => {
    success => $result->{success} ? 1 : 0,
    toast   => $result->{success}
      ? $self->app->__('Record deleted successfully')
      : ($result->{error} // $self->app->__('Failed to delete record'))
  });
}


### Cryptokeys CRUD (DNSSEC)

sub cryptokeys($self) {
  my $zone_id = $self->stash('zone_id');

  if ($self->is_json_request) {
    return unless $self->access({ admin => 1 });
    my $keys = $self->zone->list_cryptokeys($zone_id);
    return $self->render(json => { zone_id => $zone_id, cryptokeys => $keys });
  }

  $self->stash(docpath => '/zone/cryptokeys/index.html');
  my $title = $self->app->__('DNSSEC Keys');
  my $web = { title => $title };
  $web->{script} .= $self->render_to_string(template => 'zone/cryptokeys/index', format => 'js');
  $self->stash(web => $web);
  return $self->render(template => 'zone/cryptokeys/index', layout => 'modal');
}


sub create_cryptokey($self) {
  return unless $self->access({ admin => 1 });

  my $zone_id = $self->stash('zone_id');
  my $json = $self->req->json;
  my $key_data = {
    keytype   => $json->{keytype} // 'ksk',
    algorithm => $json->{algorithm} // 'ECDSAP256SHA256',
    active    => $json->{active} // 1,
  };
  $key_data->{bits} = $json->{bits} if $json->{bits};

  my $result = $self->zone->create_cryptokey($zone_id, $key_data);

  return $self->render(json => {
    success => $result->{success} ? 1 : 0,
    key     => $result->{key},
    toast   => $result->{success}
      ? $self->app->__('Cryptokey created successfully')
      : ($result->{error} // $self->app->__('Failed to create cryptokey'))
  });
}


sub delete_cryptokey($self) {
  return unless $self->access({ admin => 1 });

  my $zone_id = $self->stash('zone_id');
  my $key_id = $self->stash('key_id');
  my $result = $self->zone->delete_cryptokey($zone_id, $key_id);

  return $self->render(json => {
    success => $result->{success} ? 1 : 0,
    toast   => $result->{success}
      ? $self->app->__('Cryptokey deleted successfully')
      : ($result->{error} // $self->app->__('Failed to delete cryptokey'))
  });
}


### Zone Check

# Display the zone check interface
sub check_index ($self) {
  my $title = $self->app->__('Zone Check');
  my $web = { title => $title };

  $web->{script} .= $self->render_to_string(template => 'zone/check/index', format => 'js');
  $self->render(web => $web, title => $title, template => 'zone/check/index');
}

# Run a zone check (synchronous or async via Minion)
sub check_run ($self) {
  return unless $self->access({ admin => 1 });

  my $json = $self->req->json;
  my $zone = $json->{zone};

  unless ($zone) {
    return $self->render(json => { success => 0, error => 'Zone name required' }, status => 400);
  }

  # Async mode - queue as Minion job
  if ($json->{async}) {
    my $job_id = $self->minion->enqueue('zone_check', [$zone]);
    return $self->render(json => {
      success => 1,
      async => 1,
      job_id => $job_id,
      message => $self->app->__('Check queued'),
    });
  }

  # Synchronous mode - run check directly (supports wildcards like *.example.com)
  my $result = $self->zone->check_zones($zone);
  return $self->render(json => $result);
}

# Get status of a zone check job
sub check_status ($self) {
  return unless $self->access({ admin => 1 });

  my $job_id = $self->stash('job_id');
  my $job = $self->minion->job($job_id);

  unless ($job) {
    return $self->render(json => { success => 0, error => 'Job not found' }, status => 404);
  }

  my $info = $job->info;
  my $response = {
    job_id => $job_id,
    status => $info->{state},
  };

  # Include result if job is finished
  if ($info->{state} eq 'finished' && $info->{result}) {
    $response->{result} = $info->{result};
  }

  # Include error if job failed
  if ($info->{state} eq 'failed') {
    $response->{error} = $info->{result} // 'Unknown error';
  }

  return $self->render(json => $response);
}

1;