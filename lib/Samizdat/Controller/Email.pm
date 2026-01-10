package Samizdat::Controller::Email;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Data::Dumper;

# Field definitions for domains
my $domain_fields = [qw(domain description aliases mailboxes maxquota quota transport backupmx password_expiry customerid)];
my $domain_checkfields = [qw(active backupmx)];

# Field definitions for mailboxes
my $mailbox_fields = [qw(username password name maildir quota domain local_part phone email_other token)];
my $mailbox_checkfields = [qw(active)];

# Field definitions for aliases
my $alias_fields = [qw(address goto domain)];
my $alias_checkfields = [qw(active)];

# Index action - HTML page for email management (domains list)
sub index ($self) {
  my $accept = $self->req->headers->accept || '';

  # HTML view
  if ($accept !~ /json/) {
    my $title = $self->app->__('Email Management');
    my $web = { title => $title };
    $web->{script} = $self->render_to_string(template => 'email/index', format => 'js');

    return $self->render(
      web => $web,
      title => $title,
      template => 'email/index',
      status => 200
    );
  }

  # JSON - redirect to domains_index as default
  return $self->domains_index;
}

# Admins list page
sub admins_page ($self) {
  my $accept = $self->req->headers->accept || '';

  if ($accept !~ /json/) {
    my $title = $self->app->__('Email Admins');
    my $web = { title => $title };
    $web->{script} = $self->render_to_string(template => 'email/admins/index', format => 'js');

    return $self->render(
      web => $web,
      title => $title,
      template => 'email/admins/index',
      status => 200
    );
  }

  return $self->admins_index;
}

# Mailboxes list page
sub mailboxes_page ($self) {
  my $accept = $self->req->headers->accept || '';

  if ($accept !~ /json/) {
    my $title = $self->app->__('Email Mailboxes');
    my $web = { title => $title };
    $web->{script} = $self->render_to_string(template => 'email/mailboxes/index', format => 'js');

    return $self->render(
      web => $web,
      title => $title,
      template => 'email/mailboxes/index',
      status => 200
    );
  }

  return $self->mailboxes_index;
}

# Helper for pagination params
sub _pagination_params ($self) {
  my $page = $self->param('page') || 1;
  my $limit = $self->param('limit') || $self->app->config->{pagination}->{perpage} || 50;
  my $offset = ($page - 1) * $limit;
  return ($page, $limit, $offset);
}

# List domains
sub domains_index ($self) {
  return unless $self->access({ 'valid-user' => 1 });

  my ($page, $limit, $offset) = $self->_pagination_params;
  my $customerid = $self->param('customerid');
  my $searchterm = $self->param('searchterm') || '';

  my $where = {};
  $where->{customerid} = $customerid if $customerid;
  $where->{domain} = { -like => sprintf('%%%s%%', $searchterm) } if $searchterm;

  my $data = $self->app->email->get_domains({
    where => $where,
    limit => $limit,
    offset => $offset
  });
  my $total = $self->app->email->count_domains({ where => $where });

  return $self->render(json => {
    success => 1,
    data => $data,
    pagination => {
      page => $page,
      limit => $limit,
      total => $total,
      pages => int(($total + $limit - 1) / $limit)
    }
  });
}

# List mailboxes for a domain
sub mailboxes_index ($self) {
  return unless $self->access({ 'valid-user' => 1 });

  my ($page, $limit, $offset) = $self->_pagination_params;
  my $domain = $self->param('domain');
  my $searchterm = $self->param('searchterm') || '';

  my $where = {};
  $where->{domain} = $domain if $domain;
  $where->{username} = { -like => sprintf('%%%s%%', $searchterm) } if $searchterm;

  my $data = $self->app->email->get_mailboxes({
    where => $where,
    limit => $limit,
    offset => $offset
  });
  my $total = $self->app->email->count_mailboxes({ where => $where });

  return $self->render(json => {
    success => 1,
    data => $data,
    pagination => {
      page => $page,
      limit => $limit,
      total => $total,
      pages => int(($total + $limit - 1) / $limit)
    }
  });
}

# List aliases
sub aliases_index ($self) {
  return unless $self->access({ 'valid-user' => 1 });

  my ($page, $limit, $offset) = $self->_pagination_params;
  my $domain = $self->param('domain');
  my $searchterm = $self->param('searchterm') || '';

  my $where = {};
  $where->{domain} = $domain if $domain;
  $where->{address} = { -like => sprintf('%%%s%%', $searchterm) } if $searchterm;

  my $data = $self->app->email->get_aliases({
    where => $where,
    limit => $limit,
    offset => $offset
  });
  my $total = $self->app->email->count_aliases({ where => $where });

  return $self->render(json => {
    success => 1,
    data => $data,
    pagination => {
      page => $page,
      limit => $limit,
      total => $total,
      pages => int(($total + $limit - 1) / $limit)
    }
  });
}

# List admins
sub admins_index ($self) {
  return unless $self->access({ 'valid-user' => 1 });

  my ($page, $limit, $offset) = $self->_pagination_params;
  my $searchterm = $self->param('searchterm') || '';

  my $where = {};
  $where->{username} = { -like => sprintf('%%%s%%', $searchterm) } if $searchterm;

  my $data = $self->app->email->get_admins({
    where => $where,
    limit => $limit,
    offset => $offset
  });
  my $total = $self->app->email->count_admins({ where => $where });

  return $self->render(json => {
    success => 1,
    data => $data,
    pagination => {
      page => $page,
      limit => $limit,
      total => $total,
      pages => int(($total + $limit - 1) / $limit)
    }
  });
}

# List quotas
sub quotas_index ($self) {
  return unless $self->access({ 'valid-user' => 1 });

  my ($page, $limit, $offset) = $self->_pagination_params;
  my $searchterm = $self->param('searchterm') || '';

  my $where = {};
  $where->{username} = { -like => sprintf('%%%s%%', $searchterm) } if $searchterm;

  my $data = $self->app->email->get_quotas({
    where => $where,
    limit => $limit,
    offset => $offset
  });

  return $self->render(json => {
    success => 1,
    data => $data,
    pagination => {
      page => $page,
      limit => $limit,
      total => scalar @$data,
      pages => 1
    }
  });
}

# Domain actions
sub domain ($self) {
  my $domain = $self->param('domain');
  my $method = $self->req->method;

  return unless $self->access({ admin => 1 });

  if ($method eq 'GET') {
    my $data = $self->app->email->find_domain($domain);
    unless ($data) {
      return $self->render(json => {
        success => 0,
        error => $self->app->__('Domain not found')
      }, status => 404);
    }

    # Get domain statistics
    my $stats = $self->app->email->domain_stats($domain);

    # Check if this is an alias domain (points TO another domain)
    my $alias_domain = $self->app->email->find_alias_domain($domain);

    # Get alias domains that point TO this domain
    my $alias_domains = $self->app->email->get_alias_domains_for_target($domain);

    return $self->render(json => {
      success => 1,
      domain => $data,
      stats => $stats,
      alias_domain => $alias_domain,
      alias_domains => $alias_domains
    });
  }
  elsif ($method eq 'POST') {
    my $formdata = $self->_formdata('domain');
    unless ($formdata->{domain}->{domain}) {
      return $self->render(json => {
        success => 0,
        error => $self->app->__('Domain name is required')
      }, status => 400);
    }

    # Check if alias domain
    my $is_alias = $self->param('isAliasDomain');
    my $target_domain = $self->param('targetDomain');

    # Validate: target domains cannot become alias domains
    if ($is_alias && $target_domain) {
      my $existing_aliases = $self->app->email->get_alias_domains_for_target($formdata->{domain}->{domain});
      if ($existing_aliases && @$existing_aliases > 0) {
        return $self->render(json => {
          success => 0,
          error => $self->app->__('Cannot make this domain an alias domain - it has alias domains pointing to it')
        }, status => 400);
      }
    }

    my $result = $self->app->email->create_domain($formdata->{domain});

    # Create alias domain entry if requested
    if ($is_alias && $target_domain && $result) {
      $self->app->email->create_alias_domain({
        alias_domain => $formdata->{domain}->{domain},
        target_domain => $target_domain,
        active => $formdata->{domain}->{active} // 1
      });
    }

    return $self->render(json => {
      success => 1,
      domain => $result,
      message => $self->app->__('Domain created successfully')
    });
  }
  elsif ($method eq 'PUT' || $method eq 'PATCH') {
    my $formdata = $self->_formdata('domain');

    # Check if trying to make this an alias domain
    my $is_alias = $self->param('isAliasDomain');
    my $target_domain = $self->param('targetDomain');

    # Validate: target domains cannot become alias domains
    if ($is_alias && $target_domain) {
      my $existing_aliases = $self->app->email->get_alias_domains_for_target($domain);
      if ($existing_aliases && @$existing_aliases > 0) {
        return $self->render(json => {
          success => 0,
          error => $self->app->__('Cannot make this domain an alias domain - it has alias domains pointing to it')
        }, status => 400);
      }
    }

    my $result = $self->app->email->update_domain($domain, $formdata->{domain});

    unless ($result) {
      return $self->render(json => {
        success => 0,
        error => $self->app->__('Failed to update domain')
      }, status => 500);
    }

    # Handle alias domain changes
    my $current_alias = $self->app->email->find_alias_domain($domain);
    if ($is_alias && $target_domain) {
      if ($current_alias) {
        # Update existing alias domain if target changed
        if ($current_alias->{target_domain} ne $target_domain) {
          $self->app->email->delete_alias_domain($domain);
          $self->app->email->create_alias_domain({
            alias_domain => $domain,
            target_domain => $target_domain,
            active => $formdata->{domain}->{active} // 1
          });
        }
      } else {
        # Create new alias domain entry
        $self->app->email->create_alias_domain({
          alias_domain => $domain,
          target_domain => $target_domain,
          active => $formdata->{domain}->{active} // 1
        });
      }
    } elsif ($current_alias && !$is_alias) {
      # Remove alias domain entry if unchecked
      $self->app->email->delete_alias_domain($domain);
    }

    return $self->render(json => {
      success => 1,
      domain => $result,
      message => $self->app->__('Domain updated successfully')
    });
  }
  elsif ($method eq 'DELETE') {
    my $result = $self->app->email->delete_domain($domain);

    unless ($result) {
      return $self->render(json => {
        success => 0,
        error => $self->app->__('Failed to delete domain')
      }, status => 500);
    }

    return $self->render(json => {
      success => 1,
      message => $self->app->__('Domain deleted successfully')
    });
  }
}

# Domain page (full page - new or edit)
sub domain_page ($self) {
  my $domain = $self->param('domain');
  my $accept = $self->req->headers->accept || '';

  # HTML view
  if ($accept !~ /json/) {
    $self->stash(docpath => $self->url_for('email_domain_new') . '/index.html');
    my $title = $domain ? $domain : $self->app->__('New domain');
    my $web = { title => $title };
    $web->{script} = $self->render_to_string(template => 'email/domain/index', format => 'js');

    # Show sidebar with administrators card when editing existing domain
    if ($domain) {
      $web->{sidebar} = $self->render_to_string(template => 'email/domain/sidebar', format => 'html');
    }

    return $self->render(
      web => $web,
      title => $title,
      template => 'email/domain/index',
      status => 200
    );
  }

  # JSON - redirect to domain action
  return $self->domain;
}

# Mailbox page (modal - new or edit) - HTML only, data via OpenAPI
sub mailbox_page ($self) {
  my $domain = $self->param('domain');
  my $username = $self->param('username');

  $self->stash(docpath => $self->url_for('email_mailbox_new', domain => 'domain') . '/index.html');
  my $title = $username ? $self->app->__('Edit mailbox') : $self->app->__('Add mailbox');
  my $web = { title => $title };
  $web->{script} = $self->render_to_string(template => 'email/domain/mailbox/index', format => 'js');
  return $self->render(
    web => $web,
    title => $title,
    template => 'email/domain/mailbox/index',
    layout => 'modal',
    status => 200
  );
}

# Admin page (modal - new or edit) - HTML only, data via OpenAPI
sub admin_page ($self) {
  my $username = $self->param('username');

  $self->stash(docpath => $self->url_for('email_admin_new') . '/index.html');
  my $title = $username ? $self->app->__('Edit admin') : $self->app->__('Add admin');
  my $web = { title => $title };
  $web->{script} = $self->render_to_string(template => 'email/admins/admin/index', format => 'js');
  return $self->render(
    web => $web,
    title => $title,
    template => 'email/admins/admin/index',
    layout => 'modal',
    status => 200
  );
}

# Alias page (modal - new or edit) - HTML only, data via OpenAPI
sub alias_page ($self) {
  my $address = $self->param('address');

  $self->stash(docpath => $self->url_for('email_alias_new', domain => 'domain') . '/index.html');
  my $title = $address ? $self->app->__('Edit forwarding') : $self->app->__('Add forwarding');
  my $web = { title => $title };
  $web->{script} = $self->render_to_string(template => 'email/domain/forwarding/index', format => 'js');
  return $self->render(
    web => $web,
    title => $title,
    template => 'email/domain/forwarding/index',
    layout => 'modal',
    status => 200
  );
}

# Domain admins list
sub domain_admins ($self) {
  my $domain = $self->param('domain');
  my $accept = $self->req->headers->accept || '';

  return unless $self->access({ admin => 1 });

  # TODO: Implement domain_admins table lookup
  return $self->render(json => {
    success => 1,
    admins => []
  });
}

# Domain admin actions (add/remove admin from domain)
sub domain_admin ($self) {
  my $domain = $self->param('domain');
  my $admin = $self->param('admin');
  my $method = $self->req->method;

  return unless $self->access({ admin => 1 });

  # TODO: Implement domain_admins table operations
  return $self->render(json => {
    success => 1,
    message => 'Not yet implemented'
  });
}

# Get available target domains for alias domain
sub available_targets ($self) {
  return unless $self->access({ admin => 1 });

  my $customerid = $self->param('customerid');
  unless ($customerid) {
    return $self->render(json => {
      success => 0,
      error => $self->app->__('Customer ID is required')
    }, status => 400);
  }

  my $domains = $self->app->email->get_available_target_domains($customerid);
  return $self->render(json => {
    success => 1,
    domains => $domains
  });
}

# Mailbox actions
sub mailbox ($self) {
  my $username = $self->param('username');
  my $domain = $self->param('domain');
  my $method = $self->req->method;

  return unless $self->access({ admin => 1 });

  if ($method eq 'GET') {
    my $data = $self->app->email->find_mailbox($username);
    unless ($data) {
      return $self->render(json => {
        success => 0,
        error => $self->app->__('Mailbox not found')
      }, status => 404);
    }

    # Get quota info
    my $quota = $self->app->email->find_quota($username);

    return $self->render(json => {
      success => 1,
      mailbox => $data,
      quota => $quota
    });
  }
  elsif ($method eq 'POST') {
    my $formdata = $self->_formdata('mailbox');
    unless ($formdata->{mailbox}->{username}) {
      return $self->render(json => {
        success => 0,
        error => $self->app->__('Username is required')
      }, status => 400);
    }

    # Normalize and validate username domain
    my $mailbox_username = $formdata->{mailbox}->{username};
    if ($mailbox_username !~ /\@/) {
      # No @ - append current domain
      $formdata->{mailbox}->{username} = $mailbox_username . '@' . $domain;
    } elsif ($mailbox_username =~ /\@(.+)$/) {
      # Has @ - verify domain matches
      my $username_domain = $1;
      if (lc($username_domain) ne lc($domain)) {
        return $self->render(json => {
          success => 0,
          error => $self->app->__('Mailbox domain must match the current domain')
        }, status => 400);
      }
    }

    my $result = $self->app->email->create_mailbox($formdata->{mailbox});
    return $self->render(json => {
      success => 1,
      mailbox => $result,
      message => $self->app->__('Mailbox created successfully')
    });
  }
  elsif ($method eq 'PUT' || $method eq 'PATCH') {
    my $formdata = $self->_formdata('mailbox');
    my $result = $self->app->email->update_mailbox($username, $formdata->{mailbox});

    unless ($result) {
      return $self->render(json => {
        success => 0,
        error => $self->app->__('Failed to update mailbox')
      }, status => 500);
    }

    return $self->render(json => {
      success => 1,
      mailbox => $result,
      message => $self->app->__('Mailbox updated successfully')
    });
  }
  elsif ($method eq 'DELETE') {
    my $result = $self->app->email->delete_mailbox($username);

    unless ($result) {
      return $self->render(json => {
        success => 0,
        error => $self->app->__('Failed to delete mailbox')
      }, status => 500);
    }

    return $self->render(json => {
      success => 1,
      message => $self->app->__('Mailbox deleted successfully')
    });
  }
}

# Alias actions
sub alias ($self) {
  my $address = $self->param('address');
  my $method = $self->req->method;

  return unless $self->access({ admin => 1 });

  if ($method eq 'GET') {
    my $data = $self->app->email->find_alias($address);
    unless ($data) {
      return $self->render(json => {
        success => 0,
        error => $self->app->__('Alias not found')
      }, status => 404);
    }

    return $self->render(json => {
      success => 1,
      alias => $data
    });
  }
  elsif ($method eq 'POST') {
    my $formdata = $self->_formdata('alias');
    unless ($formdata->{alias}->{address}) {
      return $self->render(json => {
        success => 0,
        error => $self->app->__('Address is required')
      }, status => 400);
    }

    my $result = $self->app->email->create_alias($formdata->{alias});
    return $self->render(json => {
      success => 1,
      alias => $result,
      message => $self->app->__('Alias created successfully')
    });
  }
  elsif ($method eq 'PUT' || $method eq 'PATCH') {
    my $formdata = $self->_formdata('alias');
    my $result = $self->app->email->update_alias($address, $formdata->{alias});

    unless ($result) {
      return $self->render(json => {
        success => 0,
        error => $self->app->__('Failed to update alias')
      }, status => 500);
    }

    return $self->render(json => {
      success => 1,
      alias => $result,
      message => $self->app->__('Alias updated successfully')
    });
  }
  elsif ($method eq 'DELETE') {
    my $result = $self->app->email->delete_alias($address);

    unless ($result) {
      return $self->render(json => {
        success => 0,
        error => $self->app->__('Failed to delete alias')
      }, status => 500);
    }

    return $self->render(json => {
      success => 1,
      message => $self->app->__('Alias deleted successfully')
    });
  }
}

# Quota action
sub quota ($self) {
  my $username = $self->param('username');
  my $method = $self->req->method;

  return unless $self->access({ admin => 1 });

  if ($method eq 'GET') {
    my $data = $self->app->email->find_quota($username);
    return $self->render(json => {
      success => 1,
      quota => $data || { username => $username, bytes => 0, messages => 0 }
    });
  }
  elsif ($method eq 'PUT' || $method eq 'PATCH') {
    my $formdata = $self->req->params->to_hash;
    $self->app->email->update_quota($username, {
      bytes => $formdata->{bytes} || 0,
      messages => $formdata->{messages} || 0
    });

    return $self->render(json => {
      success => 1,
      message => $self->app->__('Quota updated successfully')
    });
  }
}

# Admin actions
sub admin ($self) {
  my $username = $self->param('username');
  my $method = $self->req->method;

  return unless $self->access({ admin => 1 });

  if ($method eq 'GET') {
    my $data = $self->app->email->find_admin($username);
    unless ($data) {
      return $self->render(json => {
        success => 0,
        error => $self->app->__('Admin not found')
      }, status => 404);
    }

    return $self->render(json => {
      success => 1,
      admin => $data
    });
  }
  elsif ($method eq 'POST') {
    my $json = $self->req->json || {};
    unless ($json->{username}) {
      return $self->render(json => {
        success => 0,
        error => $self->app->__('Username is required')
      }, status => 400);
    }
    unless ($json->{password}) {
      return $self->render(json => {
        success => 0,
        error => $self->app->__('Password is required')
      }, status => 400);
    }

    my $result = $self->app->email->create_admin($json);
    return $self->render(json => {
      success => 1,
      admin => $result,
      message => $self->app->__('Admin created successfully')
    });
  }
  elsif ($method eq 'PUT' || $method eq 'PATCH') {
    my $json = $self->req->json || {};
    my $result = $self->app->email->update_admin($username, $json);

    unless ($result) {
      return $self->render(json => {
        success => 0,
        error => $self->app->__('Failed to update admin')
      }, status => 500);
    }

    return $self->render(json => {
      success => 1,
      admin => $result,
      message => $self->app->__('Admin updated successfully')
    });
  }
  elsif ($method eq 'DELETE') {
    my $result = $self->app->email->delete_admin($username);

    unless ($result) {
      return $self->render(json => {
        success => 0,
        error => $self->app->__('Failed to delete admin')
      }, status => 500);
    }

    return $self->render(json => {
      success => 1,
      message => $self->app->__('Admin deleted successfully')
    });
  }
}

# Private helper to extract form data
sub _formdata ($self, $type) {
  my $result = $self->req->params->to_hash;
  my $formdata = { $type => {} };

  my $fields;
  my $checkfields;

  if ($type eq 'domain') {
    $fields = $domain_fields;
    $checkfields = $domain_checkfields;
  }
  elsif ($type eq 'mailbox') {
    $fields = $mailbox_fields;
    $checkfields = $mailbox_checkfields;
  }
  elsif ($type eq 'alias') {
    $fields = $alias_fields;
    $checkfields = $alias_checkfields;
  }

  # Extract regular fields
  for my $field (@{$fields}) {
    $formdata->{$type}->{$field} = $result->{$field} if defined $result->{$field};
  }

  # Extract checkbox fields
  for my $checkfield (@{$checkfields}) {
    $formdata->{$type}->{$checkfield} = $result->{$checkfield} ? 1 : 0 if exists $result->{$checkfield};
  }

  return $formdata;
}

1;
