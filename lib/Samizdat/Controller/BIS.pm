package Samizdat::Controller::BIS;

use Mojo::Base 'Mojolicious::Controller', -signatures;

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
    my $tag = $self->param('tag');
    my $limit = $self->param('limit') || 100;
    my $offset = $self->param('offset') || 0;
    my $lang = $self->param('lang') || $self->stash('lang') || 'en';

    my $scores = $self->bis->get_latest_scores(
      tag => $tag,
      limit => $limit,
      offset => $offset
    );
    my $sector_stats = $self->bis->get_sector_stats(lang => $lang);

    my $data = {
      success => 1,
      scores => $scores,
      sector_stats => $sector_stats,
    };

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $data, status => 200);
  }

  # Render HTML page
  my $title = $self->app->__('Based in Sweden - Compliance Dashboard');
  my $web = { title => $title };
  $web->{script} = $self->render_to_string(template => 'bis/index', format => 'js');

  $self->stash(web => $web);
  $self->render(template => 'bis/index');
}

sub domain ($self) {
  my $domain_name = $self->param('domain');
  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';

  if ($accept =~ /json/) {
    my $lang = $self->param('lang') || $self->stash('lang') || 'en';

    # Get domain details
    my $domain = $self->bis->pg->db->query(
      'SELECT * FROM bis.latest_scores WHERE domain = ?',
      $domain_name
    )->hash;

    unless ($domain) {
      return $self->render(json => { error => 'Domain not found' }, status => 404);
    }

    # Get checks for this domain
    my $checks = $self->bis->pg->db->query(
      'SELECT * FROM bis.checks
       WHERE domain_id = ? AND run_id = (SELECT MAX(id) FROM bis.runs WHERE status = ?)
       ORDER BY record_type, checked_at',
      $domain->{domain_id}, 'completed'
    )->hashes->to_array;

    # Get languageid for this language
    my $language = $self->bis->pg->db->query(
      'SELECT languageid FROM public.languages WHERE code = ?',
      $lang
    )->hash;
    my $languageid = $language ? $language->{languageid} : 1;

    # Get tags with localized names
    my $tags = $self->bis->pg->db->query(
      'SELECT t.id, t.color, t.priority, tn.key, tn.display_name, tn.description
       FROM bis.tags t
       JOIN bis.domain_tags dt ON t.id = dt.tag_id
       JOIN bis.tag_names tn ON t.id = tn.tag_id AND tn.languageid = ?
       WHERE dt.domain_id = ?
       ORDER BY t.priority DESC',
      $languageid, $domain->{domain_id}
    )->hashes->to_array;

    my $data = {
      success => 1,
      domain => $domain,
      checks => $checks,
      tags => $tags
    };

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $data, status => 200);
  }

  # Render HTML page
  my $title = $self->app->__("BIS Check: $domain_name");
  my $web = { title => $title };
  $web->{script} = $self->render_to_string(template => 'bis/domain/index', format => 'js');

  $self->stash(web => $web);
  $self->stash(docpath => '/bis/domain/index.html');
  $self->render(template => 'bis/domain/index');
}

sub sector ($self) {
  my $sector = $self->param('sector');
  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';

  if ($accept =~ /json/) {
    my $limit = $self->param('limit') || 100;
    my $offset = $self->param('offset') || 0;
    my $lang = $self->param('lang') || $self->stash('lang') || 'en';

    my $scores = $self->bis->get_latest_scores(
      tag => $sector,
      limit => $limit,
      offset => $offset
    );

    # Get languageid for this language
    my $language = $self->bis->pg->db->query(
      'SELECT languageid FROM public.languages WHERE code = ?',
      $lang
    )->hash;
    my $languageid = $language ? $language->{languageid} : 1;

    # Get sector info with localized name
    my $sector_info = $self->bis->pg->db->query(
      'SELECT t.color, tn.display_name, tn.description
       FROM bis.tags t
       JOIN bis.tag_names tn ON t.id = tn.tag_id AND tn.languageid = ?
       WHERE tn.key = ?',
      $languageid, $sector
    )->hash;

    my $data = {
      success => 1,
      sector => $sector,
      sector_info => $sector_info,
      scores => $scores
    };

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $data, status => 200);
  }

  # Render HTML page
  my $title = $self->app->__("BIS - $sector");
  my $web = { title => $title };
  $web->{script} = $self->render_to_string(template => 'bis/sector/index', format => 'js');

  $self->stash(web => $web);
  $self->stash(docpath => '/bis/sector/index.html');
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

  $self->stash(web => $web);
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

  $self->stash(web => $web);
  $self->render(template => 'bis/trends/index');
}

# Manager routes

sub manager ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';

  if ($accept =~ /json/) {
    # Get overview statistics
    my $sector_stats = $self->bis->get_sector_stats();
    my $provider_stats = $self->bis->get_provider_stats();

    # Get recent runs
    my $recent_runs = $self->bis->pg->db->select(
      'bis.runs',
      '*',
      undef,
      {-desc => 'started_at', limit => 10}
    )->hashes->to_array;

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

  $self->stash(web => $web);
  $self->render(template => 'bis/manager/index');
}

sub domains ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';

  if ($accept =~ /json/) {
    my $limit = $self->param('limit') || 100;
    my $offset = $self->param('offset') || 0;
    my $tag = $self->param('tag');

    my $sql = 'SELECT d.*, array_agg(tn.key) as tags
               FROM bis.domains d
               LEFT JOIN bis.domain_tags dt ON d.id = dt.domain_id
               LEFT JOIN bis.tag_names tn ON dt.tag_id = tn.tag_id';
    my @bind;

    if ($tag) {
      $sql .= ' WHERE d.id IN (
                  SELECT domain_id FROM bis.domain_tags dt2
                  JOIN bis.tag_names tn2 ON dt2.tag_id = tn2.tag_id
                  WHERE tn2.key = ?
                )';
      push @bind, $tag;
    }

    $sql .= ' GROUP BY d.id ORDER BY d.domain LIMIT ? OFFSET ?';
    push @bind, $limit, $offset;

    my $domains = $self->bis->pg->db->query($sql, @bind)->hashes->to_array;

    my $data = {
      success => 1,
      domains => $domains
    };

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $data, status => 200);
  }

  # Return error for non-JSON
  return $self->render(text => 'JSON only', status => 406);
}

sub add_domain ($self) {
  my $params = $self->req->json;

  unless ($params && $params->{domain}) {
    return $self->render(json => { error => 'Domain required' }, status => 400);
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
    return $self->render(json => { error => 'Failed to add domain' }, status => 500);
  }
}

sub update_domain ($self) {
  my $id = $self->param('id');
  my $params = $self->req->json;

  unless ($id && $params) {
    return $self->render(json => { error => 'Invalid request' }, status => 400);
  }

  eval {
    # Update domain
    $self->bis->pg->db->update('bis.domains', {
      active => $params->{active} // 1,
      updated_at => \'NOW()'
    }, {id => $id});

    # Update domain descriptions if provided
    if ($params->{title} || $params->{description}) {
      my $lang = $params->{lang} || 'en';
      my $language = $self->bis->pg->db->query(
        'SELECT languageid FROM public.languages WHERE code = ?',
        $lang
      )->hash;
      my $languageid = $language ? $language->{languageid} : 1;

      $self->bis->pg->db->query(
        'INSERT INTO bis.domain_descriptions (domain_id, languageid, title, description)
         VALUES (?, ?, ?, ?)
         ON CONFLICT (domain_id, languageid) DO UPDATE
         SET title = EXCLUDED.title, description = EXCLUDED.description',
        $id, $languageid, $params->{title}, $params->{description}
      );
    }

    # Update tags if provided
    if ($params->{tags}) {
      # Remove existing tags
      $self->bis->pg->db->delete('bis.domain_tags', {domain_id => $id});

      # Add new tags (tags are keys now)
      for my $tag_key (@{$params->{tags}}) {
        my $tag = $self->bis->pg->db->query(
          'SELECT DISTINCT tag_id FROM bis.tag_names WHERE key = ?',
          $tag_key
        )->hash;
        if ($tag) {
          $self->bis->pg->db->insert('bis.domain_tags', {
            domain_id => $id,
            tag_id => $tag->{tag_id}
          });
        }
      }
    }

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => { success => 1 }, status => 200);
  };

  if ($@) {
    $self->app->log->error("Failed to update domain: $@");
    return $self->render(json => { error => 'Failed to update domain' }, status => 500);
  }
}

sub delete_domain ($self) {
  my $id = $self->param('id');

  unless ($id) {
    return $self->render(json => { error => 'ID required' }, status => 400);
  }

  eval {
    $self->bis->pg->db->delete('bis.domains', {id => $id});

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => { success => 1 }, status => 200);
  };

  if ($@) {
    $self->app->log->error("Failed to delete domain: $@");
    return $self->render(json => { error => 'Failed to delete domain' }, status => 500);
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
  my $params = $self->req->json;

  unless ($params && $params->{key} && $params->{display_name}) {
    return $self->render(json => { error => 'Key and display_name required' }, status => 400);
  }

  eval {
    # Insert tag
    my $result = $self->bis->pg->db->query(
      'INSERT INTO bis.tags (color, priority) VALUES (?, ?) RETURNING id',
      $params->{color} || '#0066cc',
      $params->{priority} || 0
    );
    my $tag_id = $result->hash->{id};

    # Insert localized tag name
    my $lang = $params->{lang} || 'en';
    my $language = $self->bis->pg->db->query(
      'SELECT languageid FROM public.languages WHERE code = ?',
      $lang
    )->hash;
    my $languageid = $language ? $language->{languageid} : 1;

    $self->bis->pg->db->insert('bis.tag_names', {
      tag_id => $tag_id,
      languageid => $languageid,
      key => $params->{key},
      display_name => $params->{display_name},
      description => $params->{description} || ''
    });

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => { success => 1, tag_id => $tag_id }, status => 200);
  };

  if ($@) {
    $self->app->log->error("Failed to add tag: $@");
    return $self->render(json => { error => 'Failed to add tag' }, status => 500);
  }
}

sub runs ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0] || '';

  if ($accept =~ /json/) {
    my $limit = $self->param('limit') || 50;
    my $offset = $self->param('offset') || 0;

    my $runs = $self->bis->pg->db->select(
      'bis.runs',
      '*',
      undef,
      {-desc => 'started_at', limit => $limit, offset => $offset}
    )->hashes->to_array;

    # Add statistics for each run
    for my $run (@$runs) {
      my $stats = $self->bis->pg->db->select(
        'bis.statistics',
        '*',
        {run_id => $run->{id}}
      )->hash;
      $run->{statistics} = $stats;
    }

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
  eval {
    my $run_id = $self->bis->start_run();

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => {
      success => 1,
      run_id => $run_id,
      message => 'Run started. Use /manager/bis/runs/:id/check to begin checking domains.'
    }, status => 200);
  };

  if ($@) {
    $self->app->log->error("Failed to start run: $@");
    return $self->render(json => { error => 'Failed to start run' }, status => 500);
  }
}

sub check_run ($self) {
  my $run_id = $self->param('id');

  unless ($run_id) {
    return $self->render(json => { error => 'Run ID required' }, status => 400);
  }

  # This should be run as a background job, but for now run synchronously
  eval {
    # Get all active domains
    my $domains = $self->bis->pg->db->select(
      'bis.domains',
      ['id'],
      {active => 1}
    )->hashes->to_array;

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
    return $self->render(json => { error => "Failed to check run: $@" }, status => 500);
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
  my $params = $self->req->json;

  unless ($params && $params->{key} && $params->{name} && $params->{country_code}) {
    return $self->render(json => { error => 'Key, name and country_code required' }, status => 400);
  }

  eval {
    # Insert provider
    my $result = $self->bis->pg->db->query(
      'INSERT INTO bis.providers (country_code, is_swedish, cloud_act_applies, asn_list, as_name_patterns, ip_ranges)
       VALUES (?, ?, ?, ?, ?, ?) RETURNING id',
      $params->{country_code},
      $params->{is_swedish} // 0,
      $params->{cloud_act_applies} // 0,
      $params->{asn_list},
      $params->{as_name_patterns},
      $params->{ip_ranges}
    );
    my $provider_id = $result->hash->{id};

    # Insert localized provider name
    my $lang = $params->{lang} || 'en';
    my $language = $self->bis->pg->db->query(
      'SELECT languageid FROM public.languages WHERE code = ?',
      $lang
    )->hash;
    my $languageid = $language ? $language->{languageid} : 1;

    $self->bis->pg->db->insert('bis.provider_names', {
      provider_id => $provider_id,
      languageid => $languageid,
      key => $params->{key},
      name => $params->{name},
      notes => $params->{notes} || ''
    });

    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => { success => 1, provider_id => $provider_id }, status => 200);
  };

  if ($@) {
    $self->app->log->error("Failed to add provider: $@");
    return $self->render(json => { error => 'Failed to add provider' }, status => 500);
  }
}

1;

=head1 SEE ALSO

L<Samizdat::Model::BIS>, L<Samizdat::Plugin::BIS>

=cut
