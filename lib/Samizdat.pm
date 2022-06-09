package Samizdat;

use Mojo::Base 'Mojolicious', -signatures;
use MojoX::MIME::Types;
use Mojo::Pg;
use Mojo::Redis;
use Samizdat::Model::Markdown;
use Samizdat::Model::Account;
use Samizdat::Model::RedisSession;
use Data::Dumper;

sub startup ($self) {
  my $config = $self->plugin('NotYAMLConfig');
  $self->secrets($config->{secrets});
  $self->types(MojoX::MIME::Types->new);

  $self->defaults(
    themecolor => '',
    headtitle => '',
    extrajs => '',
    extracss => '',
    web => {
      docid => 0,
      comments => 0,
      creator => 1,
      published => 0,
      epochpublished => 0,
      resources_id => 0,
      canonical => $config->{siteurl},
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

  my $dsnpg = sprintf('postgresql://%s:%s@%s/%s',
    $config->{pgsql}->{user},
    $config->{pgsql}->{password},
    $config->{pgsql}->{host},
    $config->{pgsql}->{database}
  );
  $self->helper(pg => sub { state $pg = Mojo::Pg->new($dsnpg) });
  $self->pg->on(connection => sub {
    my ($pg, $dbh) = @_;
    $dbh->do('SET search_path TO public');
    $pg->max_connections(32);
  });
  $self->pg->migrations->from_dir('migrations')->migrate;

  $self->plugin('Minion' => {Pg => shift->pg });

  my $dsnredis = sprintf('redis://%s:%s/%s',
    $config->{redis}->{host},
    $config->{redis}->{port},
    $config->{redis}->{database}
  );
  $self->helper(redis => sub { state $redis = Mojo::Redis->new($dsnredis) });

  $self->helper(markdown => sub { state $markdown = Samizdat::Model::Markdown->new });
  $self->helper(account => sub { state $account = Samizdat::Model::Account->new(pg => shift->pg) });
  $self->helper(redissession => sub { state $redissession = Samizdat::Model::RedisSession->new(redis => shift->redis) });

  $self->plugin('DefaultHelpers');
  $self->plugin('TagHelpers');

  # Internationalization block. Use "make i18n" to rebuild text lexicon.
  $self->plugin('LocaleTextDomainOO', {
    file_type => 'mo',
    default => 'en',
    languages => [qw(en ru sv)],
    no_header_detect => 1,
  });
  $self->lexicon({
    search_dirs => [qw(./locale)],
    gettext_to_maketext => 0,
    decode => 1,
    data => [
      '*::' => '*/com.fakenews.mo',
      delete_lexicon => 'i-default::',
    ],
  });
  $self->hook(before_routes => sub {
    my $c = shift;
    my $language = $c->cookie('language') // '';
    if (exists($config->{locale}->{languages}->{$language})) {
      $self->language($language);
    } else {
      $c->cookie(language => 'en', {
        secure => 1,
        httponly => 0,
        path => '/',
        expires => time + 36000,
        domain => $config->{domain},
        hostonly => 1,
      });
      $self->language('en');
    }
  });
  push @{$self->commands->namespaces}, 'Samizdat::Command';
  unshift @{$self->plugins->namespaces}, 'Samizdat::Plugin';
  push @{$self->renderer->paths}, '/usr/local/share/perl/5.30.0/Mojolicious/resources/templates/mojo';
  $self->plugin('Utils');
  $self->plugin('Icons');

  my $r = $self->routes;
  $r->any([qw(     POST                  )] => '/login')->to(controller => 'Login', action => 'login');
  $r->any([qw( GET                       )] => '/login')->to(controller => 'Login', action => 'index');
  $r->any([qw(     POST DELETE           )] => '/logout')->to(controller => 'Login', action => 'logout');
  $r->any([qw( GET                       )] => '/user')->to(controller => 'User');
  $r->any([qw( GET                       )] => '/panel')->to(controller => 'Panel');
  $r->any([qw( GET                       )] => '/')->to(controller => 'Markdown', action => 'geturi', docpath => '');
  $r->any([qw( GET                       )] => '/*docpath')->to(controller => 'Markdown', action => 'geturi');
}

1;
