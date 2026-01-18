package Samizdat::Controller::Website;

use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($self) {
  my $accept = $self->req->headers->accept // '';
  if ($accept !~ /json/) {
    my $title = $self->app->__('Websites');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'website/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'website/index', headline => 'website/chunks/headlinebuttons', status => 200);
  } else {
    return unless $self->access({ admin => 1 });

    my $customerid = $self->param('customerid');
    my $searchterm = $self->param('searchterm');
    my $params = {};
    $params->{where} = { customerid => int($customerid) } if $customerid;
    # Only add searchterm if non-empty
    $params->{searchterm} = $searchterm if defined $searchterm && $searchterm ne '';

    my $websites = $self->website->get($params);
    return $self->render(json => { websites => $websites });
  }
}

sub get ($self) {
  my $accept = $self->req->headers->accept // '';
  my $websiteid = $self->param('websiteid');

  if ($accept !~ /json/) {
    $self->stash(docpath => '/websites/website/index.html');
    my $title = $self->app->__('Website');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'website/show/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'website/show/index', status => 200);
  } else {
    return unless $self->access({ admin => 1 });

    my $website = $self->website->get_by_id(int($websiteid));
    my $domains = $self->website->domains({ where => { websiteid => int($websiteid) } });
    my $phpconfig = $self->website->get_phpconfig(int($websiteid));
    my $serverextra = $self->website->get_serverextra(int($websiteid));
    return $self->render(json => {
      website           => $website,
      domains           => $domains,
      servers           => $self->website->servers,
      shells            => $self->website->shells,
      php_enabled       => ($phpconfig && $phpconfig->{active}) ? 1 : 0,
      serverextra_enabled => ($serverextra && $serverextra->{active}) ? 1 : 0,
    });
  }
}

sub edit ($self) {
  my $accept = $self->req->headers->accept // '';
  my $websiteid = $self->param('websiteid') // 'new';

  if ($accept !~ /json/) {
    $self->stash(docpath => '/websites/edit/index.html');
    my $title = $websiteid eq 'new' ? $self->app->__('New Website') : $self->app->__('Edit Website');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'website/edit/index', format => 'js');

    # Add sidebar for existing websites
    if ($websiteid ne 'new') {
      $web->{sidebar} = $self->render_to_string(template => 'website/chunks/domains', format => 'html');
      $web->{script} .= $self->render_to_string(template => 'website/chunks/domains', format => 'js');
    }

    return $self->render(web => $web, title => $title, template => 'website/edit/index', headline => 'website/chunks/headlinebuttons', status => 200);
  } else {
    return unless $self->access({ admin => 1 });

    if ($websiteid eq 'new') {
      return $self->render(json => {
        website => {},
        servers => $self->website->servers,
        shells  => $self->website->shells,
      });
    }

    my $website = $self->website->get_by_id(int($websiteid));
    my $domains = $self->website->domains({ where => { websiteid => int($websiteid) } });
    my $phpconfig = $self->website->get_phpconfig(int($websiteid));
    my $serverextra = $self->website->get_serverextra(int($websiteid));
    return $self->render(json => {
      website           => $website,
      domains           => $domains,
      servers           => $self->website->servers,
      shells            => $self->website->shells,
      php_enabled       => ($phpconfig && $phpconfig->{active}) ? 1 : 0,
      serverextra_enabled => ($serverextra && $serverextra->{active}) ? 1 : 0,
    });
  }
}

sub create ($self) {
  return unless $self->access({ admin => 1 });

  my $data = $self->req->json // {};

  # Validate IP settings
  if (my $error = $self->website->validate_ip($data)) {
    return $self->render(json => { success => 0, error => $error }, status => 400);
  }

  my $websiteid = $self->website->add($data);

  # Set PHP and serverextra active state (config content saved via modals)
  $self->website->set_phpconfig($websiteid, $data->{php_enabled}, '') if $data->{php_enabled};
  $self->website->set_serverextra($websiteid, $data->{serverextra_enabled}, '') if $data->{serverextra_enabled};

  my $website = $self->website->get_by_id($websiteid);
  return $self->render(json => { success => 1, website => $website }, status => 201);
}

sub update ($self) {
  return unless $self->access({ admin => 1 });

  my $websiteid = int($self->param('websiteid'));
  my $data = $self->req->json // {};

  # Validate IP settings
  if (my $error = $self->website->validate_ip($data, $websiteid)) {
    return $self->render(json => { success => 0, error => $error }, status => 400);
  }

  $self->website->update($websiteid, $data);

  # Set PHP and serverextra active state (preserve existing config)
  if (exists $data->{php_enabled}) {
    my $existing = $self->website->get_phpconfig($websiteid);
    $self->website->set_phpconfig($websiteid, $data->{php_enabled}, $existing ? $existing->{phpconfig} : '');
  }
  if (exists $data->{serverextra_enabled}) {
    my $existing = $self->website->get_serverextra($websiteid);
    $self->website->set_serverextra($websiteid, $data->{serverextra_enabled}, $existing ? $existing->{configextra} : '');
  }

  my $website = $self->website->get_by_id($websiteid);
  return $self->render(json => { success => 1, website => $website });
}

sub delete ($self) {
  return unless $self->access({ admin => 1 });

  my $websiteid = int($self->param('websiteid'));
  $self->website->delete($websiteid);
  return $self->render(json => { success => 1 });
}

sub domains ($self) {
  my $accept = $self->req->headers->accept // '';
  if ($accept !~ /json/) {
    my $title = $self->app->__('Domains');
    my $web = { title => $title };
    return $self->render(web => $web, title => $title, template => 'website/domains/index', status => 200);
  } else {
    return unless $self->access({ admin => 1 });

    my $customerid = $self->param('customerid');
    my $websiteid = $self->param('websiteid');
    my $params = {};
    $params->{where} = { customerid => int($customerid) } if $customerid;
    $params->{where} = { websiteid => int($websiteid) } if $websiteid;

    my $domains = $self->website->domains($params);
    return $self->render(json => { domains => $domains });
  }
}

sub add_domain ($self) {
  return unless $self->access({ admin => 1 });

  my $websiteid = int($self->param('websiteid'));
  my $data = $self->req->json // {};
  $data->{websiteid} = $websiteid;

  # Get customerid from website if not provided
  unless ($data->{customerid}) {
    my $website = $self->website->get_by_id($websiteid);
    $data->{customerid} = $website->{customerid} if $website;
  }

  my $domainid = $self->website->add_domain($data);
  return $self->render(json => { success => 1, domainid => $domainid }, status => 201);
}

sub delete_domain ($self) {
  return unless $self->access({ admin => 1 });

  my $domainid = int($self->param('domainid'));
  $self->website->delete_domain($domainid);
  return $self->render(json => { success => 1 });
}

sub set_primary_domain ($self) {
  return unless $self->access({ admin => 1 });

  my $websiteid = int($self->param('websiteid'));
  my $data = $self->req->json // {};
  my $domainid = $data->{domainid};

  $self->website->set_primary_domain($websiteid, $domainid);
  return $self->render(json => { success => 1 });
}

sub servers ($self) {
  my $accept = $self->req->headers->accept // '';
  if ($accept !~ /json/) {
    my $title = $self->app->__('Servers');
    my $web = { title => $title };
    return $self->render(web => $web, title => $title, template => 'website/servers/index', status => 200);
  } else {
    return unless $self->access({ admin => 1 });
    my $servers = $self->website->servers;
    return $self->render(json => { servers => $servers });
  }
}

sub server_types ($self) {
  return unless $self->access({ admin => 1 });
  my $types = $self->website->servertypes;
  return $self->render(json => { types => $types });
}

sub shells ($self) {
  return unless $self->access({ admin => 1 });
  my $shells = $self->website->shells;
  return $self->render(json => { shells => $shells });
}

sub get_phpconfig ($self) {
  my $accept = $self->req->headers->accept // '';

  if ($accept !~ /json/) {
    my $web = {};
    return $self->render(template => 'website/edit/phpconfig/index', format => 'html', layout => 'modal', web => $web);
  }

  return unless $self->access({ admin => 1 });

  my $websiteid = int($self->param('websiteid'));
  my $phpconfig = $self->website->get_phpconfig($websiteid);

  return $self->render(json => {
    config => $phpconfig ? $phpconfig->{phpconfig} : '',
    active => $phpconfig ? $phpconfig->{active} : 0,
  });
}

sub update_phpconfig ($self) {
  return unless $self->access({ admin => 1 });

  my $websiteid = int($self->param('websiteid'));
  my $data = $self->req->json // {};

  $self->website->set_phpconfig($websiteid, $data->{active}, $data->{config} // '');

  return $self->render(json => { success => 1 });
}

sub get_serverextra ($self) {
  my $accept = $self->req->headers->accept // '';

  if ($accept !~ /json/) {
    my $web = {};
    return $self->render(template => 'website/edit/serverextra/index', format => 'html', layout => 'modal', web => $web);
  }

  return unless $self->access({ admin => 1 });

  my $websiteid = int($self->param('websiteid'));
  my $serverextra = $self->website->get_serverextra($websiteid);

  return $self->render(json => {
    config => $serverextra ? $serverextra->{configextra} : '',
    active => $serverextra ? $serverextra->{active} : 0,
  });
}

sub update_serverextra ($self) {
  return unless $self->access({ admin => 1 });

  my $websiteid = int($self->param('websiteid'));
  my $data = $self->req->json // {};

  $self->website->set_serverextra($websiteid, $data->{active}, $data->{config} // '');

  return $self->render(json => { success => 1 });
}

sub delete_phpconfig ($self) {
  return unless $self->access({ admin => 1 });

  my $websiteid = int($self->param('websiteid'));
  $self->website->delete_phpconfig($websiteid);

  return $self->render(json => { success => 1 });
}

sub delete_serverextra ($self) {
  return unless $self->access({ admin => 1 });

  my $websiteid = int($self->param('websiteid'));
  $self->website->delete_serverextra($websiteid);

  return $self->render(json => { success => 1 });
}

1;
