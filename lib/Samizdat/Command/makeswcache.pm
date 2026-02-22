package Samizdat::Command::makeswcache;

use Mojo::Base 'Mojolicious::Command', -signatures;
use Mojo::UserAgent;
use Mojo::JSON qw(encode_json);
use Mojo::File qw(path);

has description => 'Generate Service Worker cache files for dynamic routes';
has usage => sub ($self) { $self->extract_usage };

my $ua = Mojo::UserAgent->new;

sub run ($self, @args) {
  my $config = $self->app->config;
  my $sw_config = $config->{serviceworker} || {};
  my $routes = $sw_config->{routes} || [];

  my $manager_url = $config->{manager}->{url} || '/manager/';
  $manager_url =~ s|^/||;
  $manager_url =~ s|/$||;

  my $server = ${ $config->{hypnotoad}->{listen} }[0];
  $server =~ s/\?.*//;

  my $languages = $config->{locale}->{languages} || { en => {} };
  my $default_lang = $config->{locale}->{default_language} || 'en';

  # Generate sw.js and sw-routes.json as static files
  $self->generate_sw_js($config);
  $self->generate_routes_json($config, $routes, $manager_url, $default_lang, $sw_config);

  # Generate cached HTML for each route and language
  for my $route (@$routes) {
    my $cache_path = $route->{cachePath};
    $cache_path =~ s/\{manager\}/$manager_url/g;

    # We need a sample URL to hit - derive from cache path
    my $sample_url = $self->derive_sample_url($route, $manager_url);
    next unless $sample_url;

    for my $lang (keys %$languages) {
      say "Generating cache for $cache_path (lang: $lang)...";

      $ua->cookie_jar->empty;
      $ua->cookie_jar->add(
        Mojo::Cookie::Response->new(
          name   => 'editlanguage',
          value  => $lang,
          domain => $config->{manager}->{account}->{cookiedomain} || 'localhost',
          path   => '/'
        )
      );

      my $url = sprintf('%s/%s', $server, $sample_url);
      my $res = $ua->get($url)->result;

      if ($res->is_success) {
        say "  -> Generated (status: " . $res->code . ")";
      } else {
        say "  -> Failed: " . $res->code . " " . $res->message;
      }
    }
  }

  say "Service Worker cache generation complete.";
}

sub generate_sw_js ($self, $config) {
  my $baseurl = $config->{baseurl} || '/';
  $baseurl =~ s|^/||;  # Remove leading slash for public/ path

  # sw.js is now plain JavaScript (no EP template syntax), so just copy it
  my $src = $self->app->home->child('templates/sw.js');
  my $dest_dir = $baseurl ? path("public/$baseurl") : path('public');
  $dest_dir->make_path;
  my $dest = $dest_dir->child('sw.js');
  $dest->spew($src->slurp);
  say "Generated $dest";
}

sub generate_routes_json ($self, $config, $routes, $manager_url, $default_lang, $sw_config) {
  my @processed_routes;

  for my $route (@$routes) {
    my $pattern = $route->{pattern};
    my $cache_path = $route->{cachePath};

    # Replace {manager} placeholder with actual manager URL
    $pattern =~ s/\{manager\}/$manager_url/g;
    $cache_path =~ s/\{manager\}/$manager_url/g;

    push @processed_routes, {
      pattern    => $pattern,
      cachePath  => $cache_path,
      revalidate => $route->{revalidate} ? \1 : \0,
    };
  }

  my $json = encode_json({
    routes          => \@processed_routes,
    defaultLanguage => $default_lang,
    precache        => $sw_config->{precache} || [],
    version         => $sw_config->{version} || 1,
  });

  # Place sw-routes.json next to sw.js (same baseurl path)
  my $baseurl = $config->{baseurl} || '/';
  $baseurl =~ s|^/||;
  my $dest_dir = $baseurl ? path("public/$baseurl") : path('public');
  $dest_dir->make_path;
  my $file = $dest_dir->child('sw-routes.json');
  $file->spew($json);
  say "Generated $file";
}

sub derive_sample_url ($self, $route, $manager_url) {
  my $cache_path = $route->{cachePath};
  $cache_path =~ s/\{manager\}/$manager_url/g;
  $cache_path =~ s/\{lang\}/en/g;
  $cache_path =~ s/index\.en\.html$//;
  $cache_path =~ s|^/||;

  # For menu routes, we need to construct a valid URL with a menu ID
  # The cache path is like: rs/web/menus/menu/
  # We need to hit: rs/web/menus/1 (with any valid menu ID)

  if ($cache_path =~ m|/web/menus/menu/$|) {
    # Menu editor - need a menu ID
    my $menuid = $self->get_first_menu_id();
    return undef unless $menuid;
    $cache_path =~ s|/menu/$|/$menuid|;
  } elsif ($cache_path =~ m|/web/menus/menu/item/$|) {
    # Menu item editor - need menu ID and item ID
    my ($menuid, $itemid) = $self->get_first_menuitem_ids();
    return undef unless $menuid && $itemid;
    $cache_path =~ s|/menu/item/$|/$menuid/items/$itemid|;
  } elsif ($cache_path =~ m|/web/src/$|) {
    # Src browser - just needs any path
    $cache_path =~ s|/$||;
  }

  return $cache_path;
}

sub get_first_menu_id ($self) {
  my $menus = $self->app->web->getMenus();
  return $menus->[0]{menuid} if $menus && @$menus;
  return undef;
}

sub get_first_menuitem_ids ($self) {
  my $menus = $self->app->web->getMenus();
  return (undef, undef) unless $menus && @$menus;

  my $menuid = $menus->[0]{menuid};
  my $items = $self->app->web->getMenuItems($menuid, 1);
  return ($menuid, undef) unless $items && @$items;

  return ($menuid, $items->[0]{menuitemid});
}

1;

=encoding utf8

=head1 NAME

Samizdat::Command::makeswcache - Generate Service Worker cache files

=head1 SYNOPSIS

  Usage: bin/samizdat makeswcache

  Generates:
  - public/sw.js - Service Worker script (from templates/sw.js)
  - public/sw-routes.json - Route configuration
  - Cached HTML files for all configured routes and languages

  Files are placed under public/{baseurl} to match route configuration.

=head1 DESCRIPTION

This command pre-generates cached HTML files for dynamic routes
configured in the serviceworker section of samizdat.yml.

The Service Worker uses these cached files to serve pages instantly
without hitting the server, supporting cookie-based language selection.

=head1 CONFIGURATION

Add to samizdat.yml:

  serviceworker:
    version: 1
    routes:
      # {manager} is replaced with actual manager URL
      # {lang} is replaced with language code
      - pattern: "^/({manager})/web/menus/\\d+/?$"
        cachePath: "/{manager}/web/menus/menu/index.{lang}.html"
      - pattern: "^/({manager})/web/menus/\\d+/items/(\\d+|new)/?$"
        cachePath: "/{manager}/web/menus/menu/item/index.{lang}.html"

=cut
