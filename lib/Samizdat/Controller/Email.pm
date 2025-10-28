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

# Index action - list domains/mailboxes/aliases
sub index ($self) {
  my $accept = $self->req->headers->accept || '';
  my $type = $self->param('type') || 'domains';

  # HTML view
  if ($accept !~ /json/) {
    my $title = $self->app->__('Email Management');
    my $web = { title => $title };

    # Render type-specific template if type is set
    my $template = 'email/index';
    if ($type && $type =~ /^(domains|mailboxes|aliases|quotas)$/) {
      $template = "email/$type/index";
      $web->{script} = $self->render_to_string(
        template => $template,
        format => 'js'
      );
    }

    return $self->render(
      web => $web,
      title => $title,
      template => $template,
      status => 200
    );
  }

  # JSON API response
  else {
    return unless $self->access({ 'valid-user' => 1 });

    my $customerid = $self->param('customerid');
    my $domain = $self->param('domain');
    my $page = $self->param('page') || 1;
    my $limit = $self->param('limit') || $self->app->config->{pagination}->{perpage} || 10;
    my $offset = ($page - 1) * $limit;

    my $data;
    my $total;
    my $where = {};

    # Filter by customer if provided
    $where->{customerid} = $customerid if $customerid;
    $where->{domain} = $domain if $domain && $type ne 'domains';

    if ($type eq 'domains') {
      $data = $self->app->email->get_domains({
        where => $where,
        limit => $limit,
        offset => $offset
      });
      $total = $self->app->email->count_domains({ where => $where });
    }
    elsif ($type eq 'mailboxes') {
      $data = $self->app->email->get_mailboxes({
        where => $where,
        limit => $limit,
        offset => $offset
      });
      $total = $self->app->email->count_mailboxes({ where => $where });
    }
    elsif ($type eq 'aliases') {
      $data = $self->app->email->get_aliases({
        where => $where,
        limit => $limit,
        offset => $offset
      });
      $total = $self->app->email->count_aliases({ where => $where });
    }
    elsif ($type eq 'quotas') {
      $data = $self->app->email->get_quotas({
        where => $where,
        limit => $limit,
        offset => $offset
      });
      $total = scalar @{$data}; # Quotas don't have a count method
    }

    return $self->render(json => {
      success => 1,
      type => $type,
      data => $data,
      pagination => {
        page => $page,
        limit => $limit,
        total => $total,
        pages => int(($total + $limit - 1) / $limit)
      }
    });
  }
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

    return $self->render(json => {
      success => 1,
      domain => $data,
      stats => $stats
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

    my $result = $self->app->email->create_domain($formdata->{domain});
    return $self->render(json => {
      success => 1,
      domain => $result,
      message => $self->app->__('Domain created successfully')
    });
  }
  elsif ($method eq 'PUT' || $method eq 'PATCH') {
    my $formdata = $self->_formdata('domain');
    my $result = $self->app->email->update_domain($domain, $formdata->{domain});

    unless ($result) {
      return $self->render(json => {
        success => 0,
        error => $self->app->__('Failed to update domain')
      }, status => 500);
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

# Mailbox actions
sub mailbox ($self) {
  my $username = $self->param('username');
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
