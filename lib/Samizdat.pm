package Samizdat;

use Mojo::Base 'Mojolicious', -signatures;
use MojoX::MIME::Types;
use Mojo::Pg;
use Mojo::mysql;
use Mojo::Redis;
use Data::UUID;
use Hash::Merge;
use Data::Dumper;

sub startup ($self) {
  my $config = $self->plugin('NotYAMLConfig');
  push @{$self->commands->namespaces}, 'Samizdat::Command';
  unshift @{$self->plugins->namespaces}, 'Samizdat::Plugin';
  push @{$self->renderer->paths}, @{ $config->{extratemplates} };
  push @{$self->static->paths}, 'src/public';
  $self->secrets($config->{secrets});
  $self->types(MojoX::MIME::Types->new);

  $self->defaults(
    layout => $config->{layout},
    template => 'index',
    languages => {},
    language => $config->{locale}->{default_language},
    countries => {},
    themecolor => '',
    headtitle => '',
    extrajs => '',
    extracss => '',
    symbols => undef,
    headline => undef,
    web => {
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
    user => {
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

  $self->helper(merger => sub { state $merger = Hash::Merge->new() });
  $self->helper(uuid => sub { state $uuid = Data::UUID->new });

  $self->helper(redis => sub { state $redis = Mojo::Redis->new($config->{dsn}->{redis}); return $redis; });
  $self->helper(pg => sub { state $pg = Mojo::Pg->new($config->{dsn}->{pg}); return $pg; });
  $self->pg->on(connection => sub {
    my ($pg, $dbh) = @_;
    $dbh->do('SET search_path TO public');
    $dbh->{pg_server_prepare} = 0;
    $pg->max_connections(32);
  });
  $self->pg->migrations->from_dir('migrations')->migrate;
  $self->pg->db->dbh->{pg_server_prepare} = 1;

  if (exists($config->{import}->{dsn})) {
    $self->helper(mysql => sub { state $mysql = Mojo::mysql->new($config->{import}->{dsn}) });
    $self->mysql->on(connection => sub {
      my ($mysql, $dbh) = @_;
      $mysql->max_connections(5);
    });
  }

  # Make web root reusable for other plugins as $app->routes->home
  $self->routes->root->add_shortcut(home => sub {
    my ($route, $path) = @_;
    my $home_url = $self->config->{baseurl} || '/';
    $path = $home_url . ($path || '');
    $path =~ s/\/{2,}/\//g;
    my $home = $route->any($path);
    return $home;
  });

  # Make manager root reusable for other plugins as $app->routes->manager
  $self->routes->root->add_shortcut(manager => sub {
    my ($route, $path) = @_;
    my $manager_url = $self->config->{manager}->{url} || '/manager/';
    $path = $manager_url . ($path || '');
    $path =~ s/\/{2,}/\//g;
    my $manager = $route->any($path);
    return $manager;
  });

  $self->plugin('Cache');
  $self->plugin('Account');
  $self->plugin('Manager');
  $self->plugin('Public');
  $self->plugin('Icons');
  $self->plugin('Contact');
  $self->plugin('Shortbytes');

  # Add your local plugins in your extraplugins setting
  for my $plugin (@{ $config->{extraplugins} }) {
    $self->plugin($plugin);
  }
  if (exists($config->{buymeacoffee}->{slug}) && $config->{buymeacoffee}->{slug}) {
    $self->plugin('BuyMeACoffee', $config->{buymeacoffee});
  }
  $self->plugin('DefaultHelpers');
  $self->plugin('TagHelpers');
  $self->plugin('Mail', $config->{mail});
  $self->plugin('Util::RandomString', {
    entropy => 256,
    printable => {
      alphabet => '2345679bdfhmnprtFGHJLMNPRT',
      length   => 20
    }
  });

  # Internationalization block. Use "make i18n" to rebuild text lexicon.
  $self->plugin('LocaleTextDomainOO', {
    file_type => 'mo',
    default => $config->{locale}->{default_language},
    languages => [ keys %{$config->{locale}->{languages}} ],
    no_header_detect => 1,
  });
  $self->lexicon({
    search_dirs => [qw(./locale)],
    gettext_to_maketext => 0,
    decode => 1,
    data => [
      '*::' => sprintf('*/%s.mo', $config->{locale}->{textdomain}),
      delete_lexicon => 'i-default::',
    ],
  });
  $self->hook(before_routes => sub ($c) {
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
        secure   => 0,
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
  $self->plugin('Captcha');

  # If Nginx serves files from the public directory, there's no need to have it in this application's list
  if ($config->{nginx}) {

  }

  $self->plugin('Web'); # Routes not covered by other plugins go here
#  say Dumper $self->routes;
}

1;