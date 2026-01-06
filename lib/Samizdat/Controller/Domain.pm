package Samizdat::Controller::Domain;

use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    my $title = $self->app->__('Domains');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'domain/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'domain/index', domains => [], status => 200);
  } else {
    return unless $self->access({ admin => 1 });

    my $searchterm = $self->param('searchterm') // '';
    my $page = int($self->param('page') // 1);
    my $per_page = int($self->param('per_page') // 50);
    my $filter = $self->param('filter') // '';  # expiring, dontrenew, all
    my $customerid = $self->param('customerid') // '';
    my $params = {};

    # Build where clause
    my @conditions;

    if ($searchterm ne '') {
      push @conditions, { domainname => { -like => sprintf('%%%s%%', $searchterm) } };
    }

    if ($filter eq 'expiring') {
      push @conditions, { dontrenew => 0 };  # due is calculated field
    } elsif ($filter eq 'dontrenew') {
      push @conditions, { dontrenew => 1 };
    }

    if ($customerid ne '') {
      push @conditions, { customerid => int($customerid) };
    }

    $params->{where} = { -and => \@conditions } if @conditions;

    # Get total count for pagination
    my $all_domains = $self->app->domain->get($params);
    my $total = scalar @$all_domains;

    # Apply pagination
    my $offset = ($page - 1) * $per_page;
    my @paginated = splice(@$all_domains, $offset, $per_page);

    # Filter expiring domains after fetching (since 'due' is calculated)
    if ($filter eq 'expiring') {
      @paginated = grep { $_->{due} } @paginated;
    }

    # Get customer counts for filter dropdown (only on first page without customer filter)
    my $customers = [];
    if ($page == 1 && $customerid eq '') {
      my %counts;
      $counts{$_->{customerid}}++ for @{$self->app->domain->get({})};
      $customers = [ map { { id => $_, count => $counts{$_} } } sort { $a <=> $b } keys %counts ];
    }

    my $formdata = {
      domains    => \@paginated,
      customers  => $customers,
      searchterm => $searchterm,
      page       => $page,
      per_page   => $per_page,
      total      => $total,
      pages      => int(($total + $per_page - 1) / $per_page),
      filter     => $filter,
    };
    return $self->render(json => $formdata);
  }
}

sub register ($self) {
  my $customerid = int($self->param('customerid') // 0);
  my $accept = $self->req->headers->{headers}->{accept}->[0];

  if ($accept !~ /json/) {
    $self->stash(docpath => '/domain/register/index.html');
    my $title = $self->app->__('Register domain');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'domain/register/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'domain/register/index', status => 200);
  } else {
    return unless $self->access({ admin => 1 });

    my $formdata = { domain => { customerid => $customerid } };
    return $self->render(json => $formdata);
  }
}

sub get ($self) {
  my $customerid = int($self->param('customerid') // 0);
  my $domainid = int($self->param('domainid') // 0);
  my $accept = $self->req->headers->{headers}->{accept}->[0];

  if ($accept !~ /json/) {
    $self->stash(docpath => '/customers/domains/domain/index.html');
    my $title = $self->app->__('Domain');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'domain/show/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'domain/show/index', status => 200);
  } else {
    return unless $self->access({ admin => 1 });

    my $params = { where => { domainid => $domainid } };
    my $domain = $self->app->domain->get($params)->[0];
    return $self->render(json => { domain => $domain });
  }
}

sub register_create ($self) {
  return unless $self->access({ admin => 1 });

  my $customerid = int($self->param('customerid') // 0);
  my $json = $self->req->json // {};
  my $domainname = $json->{domainname} // '';

  # TODO: Implement domain registration via EPP/RealtimeRegister
  return $self->render(json => { success => 0, error => 'Not implemented' }, status => 501);
}

sub transfer ($self) {
  my $customerid = int($self->param('customerid') // 0);
  my $accept = $self->req->headers->{headers}->{accept}->[0];

  if ($accept !~ /json/) {
    $self->stash(docpath => '/domain/transfer/index.html');
    my $title = $self->app->__('Transfer domain');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'domain/transfer/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'domain/transfer/index', status => 200);
  } else {
    return unless $self->access({ admin => 1 });

    my $formdata = { domain => { customerid => $customerid } };
    return $self->render(json => $formdata);
  }
}

sub transfer_create ($self) {
  return unless $self->access({ admin => 1 });

  my $customerid = int($self->param('customerid') // 0);
  my $json = $self->req->json // {};
  my $domainname = $json->{domainname} // '';
  my $authcode = $json->{authcode} // '';

  my $result = $self->app->domain->transfer($json);

  my $status = $result->{success} ? 201 : 400;
  return $self->render(json => $result, status => $status);
}

sub update ($self) {
  return unless $self->access({ admin => 1 });

  my $customerid = int($self->param('customerid') // 0);
  my $domainid = int($self->param('domainid') // 0);

  # TODO: Implement domain update
  return $self->render(json => { success => 0, error => 'Not implemented' }, status => 501);
}

# Contact management

sub contacts ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0];

  if ($accept !~ /json/) {
    my $title = $self->app->__('Contacts');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'domain/contacts/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'domain/contacts/index', status => 200);
  } else {
    return unless $self->access({ admin => 1 });

    my $search = $self->param('search') // '';
    my $page = int($self->param('page') // 1);
    my $per_page = int($self->param('per_page') // 50);

    my $params = {};
    $params->{search} = $search if $search;
    $params->{limit} = $per_page;
    $params->{offset} = ($page - 1) * $per_page;

    my $contacts = $self->app->domain->contacts($params);
    my $total = scalar @$contacts;

    return $self->render(json => {
      contacts => $contacts,
      page     => $page,
      per_page => $per_page,
      total    => $total,
      pages    => int(($total + $per_page - 1) / $per_page) || 1,
    });
  }
}

sub contact ($self) {
  my $handle = $self->param('handle') // '';
  my $accept = $self->req->headers->{headers}->{accept}->[0];

  if ($accept !~ /json/) {
    $self->stash(docpath => '/domain/contacts/contact/index.html');
    my $title = $self->app->__('Contact');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'domain/contacts/contact/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'domain/contacts/contact/index', status => 200);
  } else {
    return unless $self->access({ admin => 1 });

    my $contact = $self->app->domain->contact_get($handle);
    return $self->render(json => { contact => $contact });
  }
}

sub contact_edit ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  my $registries = $self->param('registries') // '';
  my $handle = $self->param('handle') // '';

  if ($accept !~ /json/) {
    my $title = $handle ? $self->app->__('Edit contact') : $self->app->__('New contact');
    my $web = { title => $title };
    $self->stash(
      preselected_registries => $registries,
      edit_handle => $handle,
    );
    $web->{script} .= $self->render_to_string(template => 'domain/contacts/edit/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'domain/contacts/edit/index', layout => 'modal', status => 200);
  } else {
    return unless $self->access({ admin => 1 });
    return $self->render(json => { contact => {} });
  }
}

sub contact_create ($self) {
  return unless $self->access({ admin => 1 });

  my $json = $self->req->json // {};
  my $result = $self->app->domain->contact_create($json);

  my $status = $result->{success} ? 201 : 400;
  return $self->render(json => $result, status => $status);
}

sub contact_update ($self) {
  return unless $self->access({ admin => 1 });

  my $handle = $self->param('handle') // '';
  my $json = $self->req->json // {};
  my $result = $self->app->domain->contact_update($handle, $json);

  my $status = $result->{success} ? 200 : 400;
  return $self->render(json => $result, status => $status);
}

sub contact_delete ($self) {
  return unless $self->access({ admin => 1 });

  my $handle = $self->param('handle') // '';
  my $result = $self->app->domain->contact_delete($handle);

  my $status = $result->{success} ? 200 : 400;
  return $self->render(json => $result, status => $status);
}

1;