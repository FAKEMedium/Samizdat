package Samizdat;

use Mojo::Base 'Mojolicious', -signatures;
use MojoX::MIME::Types;
use Mojo::Pg;
use Mojo::mysql;
use Mojo::Redis;
use Data::UUID;
use Hash::Merge;
use Data::Dumper;

sub startup {
  my $app = shift;
  my $config = $app->plugin('NotYAMLConfig');
  push @{$app->commands->namespaces}, 'Samizdat::Command';
  unshift @{$app->plugins->namespaces}, 'Samizdat::Plugin';
  push @{$app->renderer->paths}, @{$config->{extratemplates}};
  push @{$app->static->paths}, 'src/public';
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
  $app->pg->migrations->from_dir('migrations')->migrate;
  $app->pg->db->dbh->{pg_server_prepare} = 1;

  if (exists($config->{import}->{dsn})) {
    $app->helper(mysql => sub {state $mysql = Mojo::mysql->new($config->{import}->{dsn})});
    $app->mysql->on(connection => sub {
      my ($mysql, $dbh) = @_;
      $mysql->max_connections(5);
    });
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
  if (exists($config->{buymeacoffee}->{slug}) && $config->{buymeacoffee}->{slug}) {
    $app->plugin('BuyMeACoffee', $config->{buymeacoffee});
  }
  if (exists($config->{manager}->{nets}) && $config->{manager}->{nets}) {
    $app->plugin('Nets');
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
  $app->lexicon({
    search_dirs => [qw(./locale)],
    gettext_to_maketext => 0,
    decode => 1,
    data => [
      '*::' => sprintf('*/%s.mo', $config->{locale}->{textdomain}),
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

  # Collect OpenAPI fragments from plugins and merge into single spec
  $app->_load_openapi($config);


  $app->plugin('Web'); # Routes not covered by other plugins go here
#  say Dumper $app->routes;
}


# Collect OpenAPI fragments from all plugins and load OpenAPI plugin
sub _load_openapi {
  my ($self, $config) = @_;
  require Hash::Merge;

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
    if ($fragment && ref $fragment eq 'HASH') {
      $spec = $merger->merge($spec, $fragment);
    }
  }

  # Only load OpenAPI plugin if we have paths defined
  if (keys %{$spec->{paths}}) {
    $self->plugin('OpenAPI' => {
      spec   => $spec,
      route  => $self->routes->any($config->{api}->{url} || '/api'),
      schema => 'v3',
    });

    # Serve the merged spec as JSON at /api/openapi.json
    $self->routes->get(($config->{api}->{url} || '/api/') . 'openapi.json')->to(cb => sub {
      my $c = shift;
      $c->render(json => $spec);
    })->name('openapi_spec');
  }
}

1;