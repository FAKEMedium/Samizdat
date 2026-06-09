package Samizdat;

use Mojo::Base 'Mojolicious', -signatures;
use Mojo::Home;
use MojoX::MIME::Types;
use Mojo::Pg;
use Mojo::mysql;
use Mojo::Redis;
use Data::UUID;
use Hash::Merge;
use Data::Dumper;
use JSON::PP ();

sub startup {
  my $app = shift;
  my $config = $app->plugin('NotYAMLConfig');
  push @{$app->commands->namespaces}, 'Samizdat::Command';
  unshift @{$app->plugins->namespaces}, 'Samizdat::Plugin';

  # --- Install-aware path-resolution contract (see MIGRATION.md, Phase A1) ---
  # Bases are computed once here (never per-request, never off the current working
  # directory) so the app runs identically from a git checkout or an install under
  # /usr/local. Read-only dist resources resolve from the installed
  # Samizdat/resources tree when present, else the checkout; mutable output (the
  # static cache) and config resolve from their own bases.
  my $home = $app->home;
  my $first_existing = sub { (grep { -d $_->to_string } @_)[0] };

  # Read-only vendored third-party data (countries / languages / fonts; the raw
  # icons/flag-icons are build-time only). Resolved across: a SAMIZDAT_SHARED_SRC
  # override, the install share dir, every Samizdat/resources/shared tree on @INC
  # (the Samizdat-Resources dist), and the checkout src/ last. sharedir(@rel) returns
  # the first root that actually CONTAINS @rel (so a moved asset resolves to whichever
  # dist ships it); bare sharedir() returns the first existing root.
  my @shared_roots;
  my %seen_shared;
  my $add_shared = sub {
    my $root = shift or return;
    return if $seen_shared{$root->to_string}++;
    push @shared_roots, $root;
  };
  $add_shared->($ENV{SAMIZDAT_SHARED_SRC} ? Mojo::Home->new($ENV{SAMIZDAT_SHARED_SRC}) : undef);
  $add_shared->(Mojo::Home->new('/usr/local/share/samizdat/src'));
  $add_shared->(Mojo::Home->new("$_")->child('Samizdat', 'resources', 'shared')) for grep { !ref } @INC;
  $add_shared->($home->child('src'));
  $app->helper(sharedir => sub {
    my ($c, @rel) = @_;
    if (@rel) {
      for my $d (@shared_roots) { return $d->child(@rel) if -e $d->child(@rel)->to_string }
      return $shared_roots[-1]->child(@rel);
    }
    return $first_existing->(@shared_roots) // $home->child('src');
  });

  # Read-only dist resources by kind, unioned across every place a dist can ship
  # them: an explicit SAMIZDAT_RESOURCES override, core's own tree, every other
  # Samizdat/resources tree found on @INC (each installed/sibling plugin dist), and
  # the checkout home last. This makes a real install (one shared site_perl tree)
  # AND a dev checkout (sibling dists on PERL5LIB, each with its own resources/)
  # resolve uniformly — a polyrepo plugin's templates/settings/locale are found
  # wherever it lives. Core stays first so dir-mode lookups and build tools
  # (makei18n, makeswcache) keep resolving to core even when PERL5LIB prepends siblings.
  my $res_env = $ENV{SAMIZDAT_RESOURCES} ? Mojo::Home->new($ENV{SAMIZDAT_RESOURCES}) : undef;
  my @res_roots;
  my %seen_root;
  my $add_root = sub {
    my $root = shift or return;
    return if $seen_root{$root->to_string}++;
    push @res_roots, $root;
  };
  $add_root->($res_env);
  $add_root->(Mojo::Home->new($INC{'Samizdat.pm'})->dirname->child('Samizdat', 'resources'));
  $add_root->(Mojo::Home->new("$_")->child('Samizdat', 'resources')) for grep { !ref } @INC;

  my %res_subdir = (templates => 'templates', static => 'public',
                    migrations => 'migrations', locale => 'locale', settings => 'settings');
  my %res_home   = (templates  => [ $home->child('templates') ],
                    migrations => [ $home->child('migrations', 'pg') ],
                    locale     => [ $home->child('locale') ]);
  my %resource;
  for my $kind (keys %res_subdir) {
    my @cands = grep { -d $_->to_string } map { $_->child($res_subdir{$kind}) } @res_roots;
    push @cands, @{ $res_home{$kind} // [] };
    $resource{$kind} = \@cands;
  }

  # resource($kind, @rel): a single Mojo::File. With @rel it returns the first
  # candidate dir that actually CONTAINS that relative path (so a module's
  # schema/template resolves to whichever dist ships it); without @rel, the first
  # existing dir (core, by ordering above).
  $app->helper(resource => sub {
    my ($c, $kind, @rel) = @_;
    my $cands = $resource{$kind} // [ $home->child($kind) ];
    if (@rel) {
      for my $d (@$cands) { return $d->child(@rel) if -e $d->child(@rel)->to_string }
      return $cands->[-1]->child(@rel);
    }
    return $first_existing->(@$cands) // $cands->[-1];
  });
  # resources($kind): ALL existing candidate dirs of a kind, for path lists
  # (renderer / static / locale) that must search every dist's tree.
  $app->helper(resources => sub {
    my ($c, $kind) = @_;
    return [ grep { -d $_->to_string } @{ $resource{$kind} // [] } ];
  });

  # Mutable output base (static cache: html, webp, gz/br, symlinks).
  my $datadir = ($config->{paths} && $config->{paths}->{data})
    ? Mojo::Home->new($config->{paths}->{data}) : $home->child('public');
  $app->helper(datadir => sub { my ($c, @rel) = @_; @rel ? $datadir->child(@rel) : $datadir });

  # Per-site content root (the manager.web.src content tree: markdown source, media,
  # uploads, logos). CWD-independent; an absolute paths.content / manager.web.src
  # points at a per-site www tree in an install.
  my $content_base = $config->{paths}{content} // $config->{manager}{web}{src} // 'src';
  my $contentdir = ($content_base =~ m{^/})
    ? Mojo::Home->new($content_base)->child('public')
    : $home->child($content_base, 'public');
  $app->helper(contentdir => sub { my ($c, @rel) = @_; @rel ? $contentdir->child(@rel) : $contentdir });

  # Config base (thin seam for installed deployments).
  my $confdir = $first_existing->(
    ($ENV{SAMIZDAT_ETC} ? Mojo::Home->new($ENV{SAMIZDAT_ETC}) : ()),
    Mojo::Home->new('/usr/local/etc/samizdat'),
    $home,
  ) // $home;
  $app->helper(confdir => sub { my ($c, @rel) = @_; @rel ? $confdir->child(@rel) : $confdir });

  # Templates: main resources path first, then Mojolicious fallback templates.
  @{$app->renderer->paths} = ((map { $_->to_string } @{$app->resources('templates')}), @{$config->{extratemplates} // []});
  # Static, override order front->back: generated cache, then per-site content
  # (favicon/media), then the shipped read-only bundle (resources/public/assets).
  @{$app->static->paths} = (
    $app->datadir->to_string,                       # generated cache (public/)
    $app->contentdir->to_string,                    # per-site content static (favicon/media; follows paths.content)
    (map { $_->to_string } @{$app->resources('static')}),   # shipped bundles (every dist's resources/public)
  );
  $app->secrets($config->{secrets});
  $app->types(MojoX::MIME::Types->new);

  $app->defaults(
    layout     => $config->{layout},
    template   => 'index',
    languages  => {},
    language   => $config->{locale}->{default_language},
    countries  => {},
    themecolor => '',
    headtitle  => '',
    extrajs    => '',
    extracss   => '',
    symbols    => undef,
    headline   => undef,
    web        => {
      docid          => 0,
      comments       => 0,
      creator        => 1,
      published      => 0,
      epochpublished => 0,
      resources_id   => 0,
      canonical      => $config->{siteurl},
      title          => '',
      url            => '',
    },
    user       => {
      username     => undef,
      givennname   => undef,
      commonnname  => undef,
      displayname  => undef,
      email        => undef,
      id           => undef,
      blocked      => undef,
      languages_id => 1,
      modified     => 1,
      checked      => undef,
      deleted      => undef,
      activated    => 0,
    },
  );

  $app->helper(merger => sub {state $merger = Hash::Merge->new()});
  $app->helper(uuid => sub {state $uuid = Data::UUID->new});

  $app->helper(redis => sub {
    state $redis = Mojo::Redis->new($config->{dsn}->{redis});
    return $redis;
  });
  $app->helper(pg => sub {
    state $pg = Mojo::Pg->new($config->{dsn}->{pg});
    return $pg;
  });
  $app->pg->on(connection => sub {
    my ($pg, $dbh) = @_;
    $dbh->do('SET search_path TO public');
    $dbh->{pg_server_prepare} = 0;
    $pg->max_connections(32);
  });
  # Per-plugin migrations: every dist ships fresh-snapshot migrations under
  # resources/migrations/{pg,mysql}/<NN>-<schema>/<version>/{up,down}.sql — the Mojo
  # from_dir layout (numbered version dirs, so pgModeler schema-diff dumps drop
  # straight in as new versions). Each <NN>-<schema> dir is one named Mojo set; sets
  # run in basename order across ALL dist trees (the <NN> prefix encodes cross-schema
  # dependency tiers), so a fresh install builds every schema in order. Existing
  # deployments are grandfathered: if a set's first table already exists (from the
  # legacy monolithic migrations), it is recorded as applied instead of re-run. See
  # MIGRATION.md.
  $app->helper(run_migrations => sub ($c, $db, $kind) {
    my @dirs = sort { Mojo::File->new($a)->basename cmp Mojo::File->new($b)->basename }
      grep { -d } map { glob($_->child($kind)->to_string . '/*') } @{ $c->app->resources('migrations') };
    for my $dir (@dirs) {
      (my $name = Mojo::File->new($dir)->basename) =~ s/^\d+-//;
      my $m = $db->migrations->name("samizdat-$name")->from_dir($dir);
      next if $m->active >= $m->latest;
      if ($m->active == 0 && $kind eq 'pg') {
        # Grandfather: if the first version's first table is already present, stamp
        # the set as applied rather than re-running its CREATEs on a live database.
        my ($first_up) = sort { ($a =~ m{/(\d+)/up\.sql$})[0] <=> ($b =~ m{/(\d+)/up\.sql$})[0] }
          glob("$dir/*/up.sql");
        if ($first_up and my ($tbl) = Mojo::File->new($first_up)->slurp =~ /CREATE TABLE (?:IF NOT EXISTS\s+)?(\S+?)\s*\(/) {
          if (defined $db->db->query('SELECT to_regclass(?) AS r', $tbl)->hash->{r}) {
            $db->db->query(
              'INSERT INTO mojo_migrations (name, version) VALUES (?, ?)
               ON CONFLICT (name) DO UPDATE SET version = EXCLUDED.version',
              "samizdat-$name", $m->latest);
            next;
          }
        }
      }
      $m->migrate;
    }
  });
  $app->run_migrations($app->pg, 'pg');
  $app->pg->db->dbh->{pg_server_prepare} = 1;

  if (exists($config->{import}->{dsn})) {
    $app->helper(mysql => sub {state $mysql = Mojo::mysql->new($config->{import}->{dsn})});
    $app->mysql->on(connection => sub {
      my ($mysql, $dbh) = @_;
      $mysql->max_connections(5);
    });
    # mysql per-plugin migrations (resources/migrations/mysql/*.sql) — capability is
    # in place; no plugin ships mysql migrations yet (legacy/external schemas).
    $app->run_migrations($app->mysql, 'mysql');
  }

  # Make web root reusable for other plugins as $app->routes->home
  $app->routes->root->add_shortcut(home => sub {
    my ($route, $path) = @_;
    my $home_url = $app->config->{baseurl} || '/';
    $path = $home_url . ($path || '');
    $path =~ s/\/{2,}/\//g;
    my $home = $route->any($path);
    return $home;
  });

  # Make manager root reusable for other plugins as $app->routes->manager
  $app->routes->root->add_shortcut(manager => sub {
    my ($route, $path) = @_;
    my $manager_url = $app->config->{manager}->{url} || '/manager/';
    $path = $manager_url . ($path || '');
    $path =~ s/\/{2,}/\//g;
    my $manager = $route->any($path);
    return $manager;
  });

  # Core layered-config resolver — load early so plugins can resolve their settings.
  $app->plugin('Settings');

  # Load OAuth2 plugin and register providers from config
  $app->plugin('OAuth2');

  # Automatically register OAuth2 providers from manager.*.oauth2 sections
  if ($config->{manager}) {
    my $providers = $app->oauth2->providers;
    for my $module (keys %{$config->{manager}}) {
      next unless ref $config->{manager}->{$module} eq 'HASH';
      next unless $config->{manager}->{$module}->{oauth2};

      my $module_config = $config->{manager}->{$module};
      my $oauth2_config = { %{$module_config->{oauth2}} };

      # Handle token_url_template interpolation (for Teltonika SMS)
      if ($oauth2_config->{token_url_template}) {
        my $protocol = ($module_config->{port} && $module_config->{port} == 443) ? 'https' : 'http';
        $oauth2_config->{token_url} = $oauth2_config->{token_url_template};
        $oauth2_config->{token_url} =~ s/\{protocol\}/$protocol/g;
        $oauth2_config->{token_url} =~ s/\{host\}/$module_config->{host}/g;
        delete $oauth2_config->{token_url_template};
      }

      # Remove redirect_uri from provider config (passed at request time)
      delete $oauth2_config->{redirect_uri};

      # Map client_id to key for OAuth2 plugin compatibility
      $oauth2_config->{key} = $oauth2_config->{client_id} if $oauth2_config->{client_id};

      # Register the provider
      $providers->{$module} = $oauth2_config;
      say "Registered OAuth2 provider: $module";
    }
  }
  $app->plugin('Minion', { Pg => $config->{dsn}->{pg} });
  $app->plugin('Cache');
  $app->plugin('Account');
  $app->plugin('Public');
  $app->plugin('Manager');
  $app->plugin('Icons');
  $app->plugin('Contact');
  $app->plugin('Shortbytes');

  # Add your local plugins in your extraplugins setting
  for my $plugin (@{ $config->{extraplugins} }) {
    $app->plugin($plugin);
  }
  $app->plugin('DefaultHelpers');
  $app->plugin('TagHelpers');
  $app->plugin('Mail', $config->{mail});
  $app->plugin('Util::RandomString', {
    entropy => 256,
    printable => {
      alphabet => '2345679bdfhmnprtFGHJLMNPRT',
      length   => 20
    }
  });

  # Internationalization block. Use "make i18n" to rebuild text lexicon.
  $app->plugin('LocaleTextDomainOO', {
    file_type => 'mo',
    default => $config->{locale}->{default_language},
    languages => [ keys %{$config->{locale}->{languages}} ],
    no_header_detect => 1,
  });
  # Each plugin dist owns its per-module source catalogs
  # (resources/locale/<module>/<lang>/<module>.po); `make i18n` merges them into
  # one runtime catalog per language (resources/locale/<lang>.mo) which we load
  # flat under the empty domain, so __('msg') resolves in code AND templates
  # regardless of the calling package.
  $app->lexicon({
    search_dirs => [ map { $_->to_string } @{$app->resources('locale')} ],
    gettext_to_maketext => 0,
    decode => 1,
    data => [
      '*::' => '*.mo',
      delete_lexicon => 'i-default::',
    ],
  });
  $app->hook(before_routes => sub ($c) {
    my $language;

    # 1. Check language cookie first
    my $cookie_lang = $c->cookie('language') // '';
    if (exists($c->config->{locale}->{languages}->{$cookie_lang})) {
      $language = $cookie_lang;
    }

    # 2. If no valid cookie, check Accept-Language header
    if (!$language) {
      my $accept_lang = $c->req->headers->accept_language // '';
      # Parse Accept-Language header (e.g., "en-US,en;q=0.9,sv;q=0.8")
      my @langs = split /,/, $accept_lang;
      for my $lang_spec (@langs) {
        my ($lang) = $lang_spec =~ /^([a-z]{2})(?:-|;|$)/i;
        if ($lang && exists($c->config->{locale}->{languages}->{lc $lang})) {
          $language = lc $lang;
          last;
        }
      }
    }

    # 3. Fall back to default language
    $language //= $c->config->{locale}->{default_language};
    
    # Set the language and update cookie if needed
    $c->language($language);
    $c->stash(language => $language);
#    say $language;
    # Update cookie if it doesn't match current language
    if ($cookie_lang ne $language) {
      $c->cookie(language => $language, {
        secure   => 1,
        httponly => 0,
        path     => '/',
        expires  => time + 360000,
        domain   => $c->config->{domain},
        hostonly => 1,
        samesite => 'None',
      });
    }
  });

  # Captcha plugin with locale-aware font selection
  $app->plugin('Captcha');

  # If Nginx serves files from the public directory, there's no need to have it in this application's list
  if ($config->{nginx}) {

  }

  $app->plugin('Web'); # Routes not covered by other plugins go here

  # Collect OpenAPI fragments from plugins and merge into single spec
  $app->_load_openapi($config);

  # Wildcard catch-all route for database/markdown content
  # Registered AFTER OpenAPI routes so API endpoints take priority
  $app->routes->home->get('/*docpath')->to(controller => 'Web', action => 'getdoc');
#  say Dumper $app->routes;
}


# Collect OpenAPI fragments from all plugins and load OpenAPI plugin
sub _load_openapi {
  my ($self, $config) = @_;
  require Hash::Merge;
  require YAML::XS;

  # Base OpenAPI spec
  my $spec = {
    openapi => '3.0.3',
    info => {
      title       => ($config->{sitename} // 'Samizdat') . ' API',
      description => $config->{description} // 'API documentation',
      version     => '1.0.0',
    },
    servers => [
      { url => $config->{api}->{url} || '/api/', description => 'API server' }
    ],
    paths      => {},
    components => { schemas => {}, securitySchemes => {} },
    tags       => [],
    security   => [],
  };

  # Add cookie auth security scheme (cookie name from Account plugin config)
  $spec->{components}->{securitySchemes}->{cookieAuth} = {
    type => 'apiKey',
    in   => 'cookie',
    name => $config->{manager}->{account}->{authcookiename} || 'session',
  };

  # Collect fragments from plugins (stored in config during plugin registration)
  my $merger = Hash::Merge->new('RIGHT_PRECEDENT');
  my $fragments = $config->{openapi_fragments} || {};

  for my $name (keys %$fragments) {
    my $fragment = $fragments->{$name};
    next unless $fragment;
    # Parse YAML string if not already a hashref
    $fragment = YAML::XS::Load($fragment) unless ref $fragment;
    if (ref $fragment eq 'HASH') {
      $spec = $merger->merge($spec, $fragment);
    }
  }

  # Only load OpenAPI plugin if we have paths defined
  if (keys %{$spec->{paths}}) {
    # Fix YAML booleans for JSON/OpenAPI compatibility
    $spec = _fix_booleans($spec);

    $self->plugin('OpenAPI' => {
      plugins                        => [qw(+SpecRenderer)],
      spec                           => $spec,
      route                          => $self->routes->any($config->{api}->{url} || '/api'),
      schema                         => 'v3',
      render_specification           => 1,  # Enables /api.html and /api.json
      render_specification_for_paths => 0,  # Ensable per-path spec rendering
    });

    # Serve the merged spec as JSON at /api/openapi.json
    $self->routes->get(($config->{api}->{url} || '/api/') . 'openapi.json')->to(cb => sub {
      my $c = shift;
      $c->render(json => $spec);
    })->name('openapi_spec');
  }
}

# Deep clone and convert YAML booleans to JSON booleans for OpenAPI compatibility
sub _fix_booleans {
  my ($data) = @_;
  return $data unless ref $data;

  if (ref $data eq 'HASH') {
    my %new;
    for my $key (keys %$data) {
      if ($key eq 'required' && defined $data->{$key} && !ref $data->{$key}) {
        $new{$key} = $data->{$key} ? JSON::PP::true : JSON::PP::false;
      } else {
        $new{$key} = _fix_booleans($data->{$key});
      }
    }
    return \%new;
  } elsif (ref $data eq 'ARRAY') {
    return [ map { _fix_booleans($_) } @$data ];
  }
  return $data;
}

1;