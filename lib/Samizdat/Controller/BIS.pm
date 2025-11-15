package Samizdat::Controller::BIS;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::JSON qw(encode_json decode_json);

=head1 NAME

Samizdat::Controller::BIS - Based in Sweden controller

=head1 DESCRIPTION

Handles all BIS (Based in Sweden) compliance tracking requests.
All endpoints support JSON response when Accept: application/json header is provided.

=cut

sub index ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';

  if ($accept =~ /json/) {
    # Return JSON data for dashboard
    my $tag = $self->param('tag') || '';
    my $search = $self->param('search') || '';
    my $compliance = $self->param('compliance') || '';
    my $limit = $self->param('limit') || 100;
    my $offset = $self->param('offset') || 0;
    my $lang = $self->param('lang') || $self->stash('language') || 'en';

    # Save filter to cookie for navigation
    my $filter = {
      tag => $tag,
      search => $search,
      compliance => $compliance
    };
    $self->cookie(bisfilter => encode_json($filter), {
      path     => '/',
      httponly => 0,
      secure   => 1,
      samesite => 'Lax'
      # No expires = session cookie
    });

    my $result = $self->bis->get_latest_scores(
      tag => $tag,
      search => $search,
      limit => $limit,
      offset => $offset,
      with_total => 1,
      lang => $lang
    );
    my $sector_stats = $self->bis->get_sector_stats(lang => $lang);

    my $data = {
      success => 1,
      scores => $result->{scores},
      total => $result->{total},
      sector_stats => $sector_stats,
    };

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $data, status => 200);
  }

  # Render HTML page
  my $title = $self->app->__('Based in Sweden - Compliance Dashboard');
  my $web = { title => $title };
  $web->{script} = $self->render_to_string(template => 'bis/index', format => 'js');

  $self->stash(title => $title, web => $web);
  $self->render(template => 'bis/index');
}


sub domain ($self) {
  my $domain_name = $self->param('domain');
  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';

  if ($accept =~ /json/) {
    my $lang = $self->param('lang') || $self->stash('language') || 'en';

    # Get domain details from model
    my $details = $self->bis->get_domain_details(domain => $domain_name, lang => $lang);

    unless ($details) {
      return $self->render(json => { error => $self->app->__('Domain not found') }, status => 404);
    }

    my $data = {
      success => 1,
      domain => $details->{domain},
      checks => $details->{checks},
      tags => $details->{tags}
    };

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $data, status => 200);
  }

  # Render HTML page
  my $title = $self->app->__("BIS Check: $domain_name");
  my $web = { title => $title };
  $web->{script} = $self->render_to_string(template => 'bis/domain/index', format => 'js');

  $self->stash(title => $title, web => $web, docpath => '/bis/domain/index.html', headline => 'bis/chunks/domainheadline');
  $self->render(template => 'bis/domain/index');
}


sub nav ($self) {
  my $domain_name = $self->param('domain');
  my $to = $self->param('to');  # 'prev' or 'next'

  # Get filter from cookie
  my $filter_cookie = $self->cookie('bisfilter');
  my $filter = {};
  if ($filter_cookie) {
    eval { $filter = decode_json($filter_cookie); };
  }

  # Build filter parameters
  my $tag = $filter->{tag} || '';
  my $search = $filter->{search} || '';

  # Navigation respects the filter
  my $next_domain = $self->bis->nav(
    domain => $domain_name,
    to => $to,
    tag => $tag,
    search => $search
  );

  if ($next_domain && $next_domain->{domain}) {
    # Override the domain parameter with the new domain
    $self->param(domain => $next_domain->{domain});
  }

  # Render domain view (will return JSON if Accept header is set)
  $self->domain;
}


sub sector ($self) {
  my $sector = $self->param('sector');
  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';

  if ($accept =~ /json/) {
    my $limit = $self->param('limit') || 100;
    my $offset = $self->param('offset') || 0;
    my $lang = $self->param('lang') || $self->stash('language') || 'en';

    # Save filter to cookie for navigation
    my $filter = {
      tag => $sector,
      search => '',
      compliance => ''
    };
    $self->cookie(bisfilter => encode_json($filter), {
      path     => '/',
      httponly => 0,
      secure   => 1,
      samesite => 'Lax'
      # No expires = session cookie
    });

    my $result = $self->bis->get_latest_scores(
      tag => $sector,
      limit => $limit,
      offset => $offset,
      with_total => 1
    );

    # Get sector info from model
    my $sector_info = $self->bis->get_sector_info(sector => $sector, lang => $lang);

    my $data = {
      success => 1,
      sector => $sector,
      sector_info => $sector_info,
      scores => $result->{scores},
      total => $result->{total}
    };

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $data, status => 200);
  }

  # Render HTML page
  my $title = $self->app->__("BIS - $sector");
  my $web = { title => $title };
  $web->{script} = $self->render_to_string(template => 'bis/sector/index', format => 'js');

  $self->stash(title => $title, web => $web, docpath => '/bis/sector/index.html', headline => 'bis/chunks/headline');
  $self->render(template => 'bis/sector/index');
}


sub providers ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';

  if ($accept =~ /json/) {
    my $stats = $self->bis->get_provider_stats();

    my $data = {
      success => 1,
      providers => $stats
    };

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $data, status => 200);
  }

  # Render HTML page
  my $title = $self->app->__('BIS - Hosting Providers');
  my $web = { title => $title };
  $web->{script} = $self->render_to_string(template => 'bis/providers/index', format => 'js');

  $self->stash(title => $title, web => $web, headline => 'bis/chunks/headline');
  $self->render(template => 'bis/providers/index');
}


sub trends ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';

  if ($accept =~ /json/) {
    my $days = $self->param('days') || 90;
    my $trends = $self->bis->get_historical_trends(days => $days);

    my $data = {
      success => 1,
      trends => $trends
    };

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $data, status => 200);
  }

  # Render HTML page
  my $title = $self->app->__('BIS - Compliance Trends');
  my $web = { title => $title };
  $web->{script} = $self->render_to_string(template => 'bis/trends/index', format => 'js');

  $self->stash(title => $title, web => $web, headline => 'bis/chunks/headline');
  $self->render(template => 'bis/trends/index');
}

# Manager routes

sub manager ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';

  if ($accept =~ /json/) {
    # Get overview statistics
    my $sector_stats = $self->bis->get_sector_stats();
    my $provider_stats = $self->bis->get_provider_stats();
    my $recent_runs = $self->bis->get_recent_runs(limit => 10);

    my $data = {
      success => 1,
      sector_stats => $sector_stats,
      provider_stats => $provider_stats,
      recent_runs => $recent_runs
    };

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $data, status => 200);
  }

  # Render HTML page
  my $title = $self->app->__('BIS Manager');
  my $web = { title => $title };
  $web->{script} = $self->render_to_string(template => 'bis/manager/index', format => 'js');

  $self->stash(title => $title, web => $web, headline => 'bis/chunks/managerheadline');
  $self->render(template => 'bis/manager/index');
}


sub domains ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';

  if ($accept =~ /json/) {
    my $limit = $self->param('limit') || 100;
    my $offset = $self->param('offset') || 0;
    my $tag = $self->param('tag');

    # Get domains from model
    my $domains = $self->bis->get_domains_with_tags(tag => $tag, limit => $limit, offset => $offset);

    my $data = {
      success => 1,
      domains => $domains
    };

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $data, status => 200);
  }

  # Return error for non-JSON
  return $self->render(text => $self->app->__('JSON only'), status => 406);
}


sub add_domain ($self) {
  # Require admin access
  return if !$self->access({ admin => 1 });

  my $params = $self->req->json;

  unless ($params && $params->{domain}) {
    return $self->render(json => { error => $self->app->__('Domain required') }, status => 400);
  }

  eval {
    my $domain_id = $self->bis->add_domain(
      domain => $params->{domain},
      title => $params->{title} || '',
      description => $params->{description} || '',
      tags => $params->{tags} || []
    );

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => {
      success => 1,
      domain_id => $domain_id
    }, status => 200);
  };

  if ($@) {
    $self->app->log->error("Failed to add domain: $@");
    return $self->render(json => { error => $self->app->__('Failed to add domain') }, status => 500);
  }
}


sub update_domain ($self) {
  # Require admin access
  return if !$self->access({ admin => 1 });

  my $id = $self->param('id');
  my $params = $self->req->json;

  unless ($id && $params) {
    return $self->render(json => { error => $self->app->__('Invalid request') }, status => 400);
  }

  eval {
    # Update domain using model
    $self->bis->update_domain(
      id => $id,
      active => $params->{active},
      title => $params->{title},
      description => $params->{description},
      tags => $params->{tags},
      lang => $params->{lang}
    );

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => { success => 1 }, status => 200);
  };

  if ($@) {
    $self->app->log->error("Failed to update domain: $@");
    return $self->render(json => { error => $self->app->__('Failed to update domain') }, status => 500);
  }
}


sub delete_domain ($self) {
  # Require admin access
  return if !$self->access({ admin => 1 });

  my $id = $self->param('id');

  unless ($id) {
    return $self->render(json => { error => $self->app->__('ID required') }, status => 400);
  }

  eval {
    # Delete domain using model
    $self->bis->delete_domain(id => $id);

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => { success => 1 }, status => 200);
  };

  if ($@) {
    $self->app->log->error("Failed to delete domain: $@");
    return $self->render(json => { error => $self->app->__('Failed to delete domain') }, status => 500);
  }
}


sub tags ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';

  if ($accept =~ /json/) {
    my $lang = $self->param('lang') || 'en';
    my $tags = $self->bis->get_tags(lang => $lang);

    my $data = {
      success => 1,
      tags => $tags
    };

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $data, status => 200);
  }

  return $self->render(text => 'JSON only', status => 406);
}


sub add_tag ($self) {
  # Require admin access
  return if !$self->access({ admin => 1 });

  my $params = $self->req->json;

  unless ($params && $params->{key} && $params->{display_name}) {
    return $self->render(json => { error => $self->app->__('Key and display_name required') }, status => 400);
  }

  eval {
    # Add tag using model
    my $tag_id = $self->bis->add_tag(
      key => $params->{key},
      display_name => $params->{display_name},
      description => $params->{description},
      color => $params->{color},
      priority => $params->{priority},
      lang => $params->{lang}
    );

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => { success => 1, tag_id => $tag_id }, status => 200);
  };

  if ($@) {
    $self->app->log->error("Failed to add tag: $@");
    return $self->render(json => { error => $self->app->__('Failed to add tag') }, status => 500);
  }
}


sub runs ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';

  if ($accept =~ /json/) {
    my $limit = $self->param('limit') || 50;
    my $offset = $self->param('offset') || 0;

    # Get runs from model
    my $runs = $self->bis->get_runs_with_stats(limit => $limit, offset => $offset);

    my $data = {
      success => 1,
      runs => $runs
    };

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $data, status => 200);
  }

  return $self->render(text => 'JSON only', status => 406);
}


sub start_run ($self) {
  # Require admin access
  return if !$self->access({ admin => 1 });

  eval {
    my $run_id = $self->bis->start_run();

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => {
      success => 1,
      run_id => $run_id,
      message => $self->app->__('Run started. Use /manager/bis/runs/:id/check to begin checking domains.')
    }, status => 200);
  };

  if ($@) {
    $self->app->log->error("Failed to start run: $@");
    return $self->render(json => { error => $self->app->__('Failed to start run') }, status => 500);
  }
}


sub check_run ($self) {
  # Require admin access
  return if !$self->access({ admin => 1 });

  my $run_id = $self->param('id');

  unless ($run_id) {
    return $self->render(json => { error => $self->app->__('Run ID required') }, status => 400);
  }

  # This should be run as a background job, but for now run synchronously
  eval {
    # Get all active domains from model
    my $domains = $self->bis->get_active_domains();

    my @results;
    for my $domain (@$domains) {
      my $result = $self->bis->check_domain($domain->{id}, $run_id);
      push @results, $result;
    }

    # Complete the run
    my $stats = $self->bis->complete_run($run_id);

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => {
      success => 1,
      checked => scalar(@results),
      statistics => $stats
    }, status => 200);
  };

  if ($@) {
    $self->app->log->error("Failed to check run: $@");
    return $self->render(json => { error => $self->app->__('Failed to check run') . ": $@" }, status => 500);
  }
}


sub manage_providers ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';

  if ($accept =~ /json/) {
    my $lang = $self->param('lang') || 'en';
    my $providers = $self->bis->get_providers(lang => $lang);

    my $data = {
      success => 1,
      providers => $providers
    };

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $data, status => 200);
  }

  return $self->render(text => 'JSON only', status => 406);
}


sub add_provider ($self) {
  # Require admin access
  return if !$self->access({ admin => 1 });

  my $params = $self->req->json;

  unless ($params && $params->{key} && $params->{name} && $params->{country_code}) {
    return $self->render(json => { error => $self->app->__('Key, name and country_code required') }, status => 400);
  }

  eval {
    # Add provider using model
    my $provider_id = $self->bis->add_provider(
      key => $params->{key},
      name => $params->{name},
      country_code => $params->{country_code},
      is_swedish => $params->{is_swedish},
      cloud_act_applies => $params->{cloud_act_applies},
      asn_list => $params->{asn_list},
      as_name_patterns => $params->{as_name_patterns},
      ip_ranges => $params->{ip_ranges},
      notes => $params->{notes},
      lang => $params->{lang}
    );

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => { success => 1, provider_id => $provider_id }, status => 200);
  };

  if ($@) {
    $self->app->log->error("Failed to add provider: $@");
    return $self->render(json => { error => $self->app->__('Failed to add provider') }, status => 500);
  }
}

1;

=head1 SEE ALSO

L<Samizdat::Model::BIS>, L<Samizdat::Plugin::BIS>

=cut
