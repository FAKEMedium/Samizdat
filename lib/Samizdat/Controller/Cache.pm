package Samizdat::Controller::Cache;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::JSON qw(decode_json encode_json);

# Index action - list cache keys
sub index($self) {
  my $accept = $self->req->headers->accept || '';

  # HTML view
  if ($accept !~ /json/) {
    my $title = $self->app->__('Cache Management');
    my $web = { title => $title };

    # Render JavaScript template into web->script
    $web->{script} = $self->render_to_string(template => 'cache/index', format => 'js');

    $self->stash(headline => 'cache/chunks/headline');

    return $self->render(
      web      => $web,
      title    => $title,
      template => 'cache/index',
      status   => 200
    );
  } else {
    # JSON API response - require superadmin
    return if !$self->access({ 'superadmin' => 1 });

    my $pattern = $self->param('pattern') || '*';
    my $page = $self->param('page') || 1;
    my $limit = $self->param('limit') || 50;

    # Get keys matching pattern
    my $redis = $self->cache->{redis};
    my @all_keys = $redis->db->keys($pattern);

    my $total = scalar @all_keys;
    my $offset = ($page - 1) * $limit;

    # Paginate
    my @keys = splice(@all_keys, $offset, $limit);

    # Get info for each key
    my @cache_entries;
    foreach my $key (@keys) {
      my $ttl = $redis->db->ttl($key);
      my $type = $redis->db->type($key);
      my $value = $self->cache->get($key);

      # Truncate long values for display
      my $preview = ref($value) ? encode_json($value) : $value;
      if (length($preview) > 100) {
        $preview = substr($preview, 0, 100) . '...';
      }

      push @cache_entries, {
        key     => $key,
        type    => $type,
        ttl     => $ttl,
        preview => $preview
      };
    }

    return $self->render(json => {
      entries => \@cache_entries,
      pagination => {
        page  => $page,
        limit => $limit,
        total => $total,
        pages => int(($total + $limit - 1) / $limit)
      },
      pattern => $pattern
    });
  }
}

# Show action - view cache entry details
sub show($self) {
  return if !$self->access({ 'superadmin' => 1 });

  my $key = $self->param('key');
  return $self->render(json => { error => 'Key required' }, status => 400) unless $key;

  my $redis = $self->cache->{redis};

  unless ($redis->db->exists($key)) {
    return $self->render(json => { error => 'Key not found' }, status => 404);
  }

  my $value = $self->cache->get($key);
  my $ttl = $redis->db->ttl($key);
  my $type = $redis->db->type($key);

  return $self->render(json => {
    success => 1,
    entry => {
      key   => $key,
      value => $value,
      type  => $type,
      ttl   => $ttl
    }
  });
}

# Delete action - purge cache entry
sub delete($self) {
  return if !$self->access({ 'superadmin' => 1 });

  my $key = $self->param('key');
  return $self->render(json => { error => 'Key required' }, status => 400) unless $key;

  my $deleted = $self->cache->del($key);

  if ($deleted) {
    return $self->render(json => {
      success => 1,
      message => $self->app->__('Cache entry deleted successfully')
    });
  } else {
    return $self->render(json => {
      error => 'Failed to delete cache entry',
      message => $self->app->__('Cache entry not found or could not be deleted')
    }, status => 404);
  }
}

# Purge action - clear cache by pattern
sub purge($self) {
  return if !$self->access({ 'superadmin' => 1 });

  my $pattern = $self->param('pattern') || '*';

  # Safety check - require explicit confirmation for wildcard
  if ($pattern eq '*' && !$self->param('confirmed')) {
    return $self->render(json => {
      error => 'Confirmation required',
      message => $self->app->__('Purging all cache requires confirmation')
    }, status => 400);
  }

  my $redis = $self->cache->{redis};
  my @keys = $redis->db->keys($pattern);
  my $count = 0;

  foreach my $key (@keys) {
    $count += $self->cache->del($key);
  }

  return $self->render(json => {
    success => 1,
    count => $count,
    message => sprintf($self->app->__('Purged %d cache entries'), $count)
  });
}

1;
