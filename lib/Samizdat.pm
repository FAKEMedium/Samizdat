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
    symbols => {},
    headlinebuttons => undef,
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
      username => undef,
      givennname => undef,
      commonnname => undef,
      displayname => undef,
      email => undef,
      id => undef,
      blocked => undef,
      languages_id => 1,
      modified => 1,
      checked => undef,
      deleted => undef,
      activated => 0,
    },
  );

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

#  $self->plugin('Minion' => {Pg => shift->pg });
  $self->helper(merger => sub { state $merger = Hash::Merge->new() });
  $self->helper(uuid => sub { state $uuid = Data::UUID->new });
  if (exists($config->{import}->{dsn})) {
    $self->helper(mysql => sub { state $mysql = Mojo::mysql->new($config->{import}->{dsn}) });
    $self->mysql->on(connection => sub {
      my ($mysql, $dbh) = @_;
      $mysql->max_connections(5);
    });
  }
  $self->plugin('Account');
  $self->plugin('Public');
  $self->plugin('Utils');
  $self->plugin('Icons');
  $self->plugin('Contact');
  $self->plugin('Shortbytes');
  # Add your local plugins in your extraplugins setting
  for my $plugin (@{ $config->{extraplugins} }) {
    $self->plugin($plugin);
  }
  $self->plugin('DefaultHelpers');
  $self->plugin('TagHelpers');
  $self->plugin('Captcha', {
    session_name => $config->{captcha}->{session_name},
    out          => {force => 'png'},
    particle     => [ 500, 0 ],
    create       => ['ttf', 'ellipse', '#ff0000'],
    new          => {
      rndmax     => $config->{captcha}->{length} // 3,
      rnd_data   => [ '2', '3', '4', '6', '7', '9', 'A', 'C', 'E', 'F', 'H', 'J' ... 'N', 'P', 'R', 'T' ... 'Y' ],
      width      => $config->{captcha}->{width},
      height     => $config->{captcha}->{height},
      lines      => 20,
      font       => $config->{captcha}->{font},
      ptsize     => $config->{captcha}->{ptsize},
      scramble   => 1,
      bgcolor    => '#ffffff',
      frame      => 1,
      send_ctobg => 1,
    }
  });
  $self->routes->get('/captcha.png')->to(controller => 'Captcha', action => 'index')->name('captcha_index');

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
    my $language = $c->cookie('language') // '';
    if (exists($c->config->{locale}->{languages}->{$language})) {
      $c->language($language);
      $c->stash(language => $language);
    } else {
      $c->cookie(language => $c->config->{locale}->{default_language}, {
        secure   => 1,
        httponly => 0,
        path     => '/',
        expires  => time + 360000,
        domain   => $c->config->{domain},
        hostonly => 1,
        samesite => 'None',
      });
      $c->language($c->config->{locale}->{default_language});
    }
  });

  # If Nginx serves files from the public directory, there's no need to have it in this application's list
  if ($config->{nginx}) {

  }

  $self->plugin('Web'); # Routes not covered by other plugins go here
}

1;