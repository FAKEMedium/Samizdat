package Samizdat;
use Mojo::Base 'Mojolicious', -signatures;
use Samizdat::Model::Markdown;


sub startup ($self) {

  my $config = $self->plugin('NotYAMLConfig');

  $self->secrets($config->{secrets});
  $self->helper(markdown => sub { state $markdown = Samizdat::Model::Markdown->new });
  $self->plugin('DefaultHelpers');
  $self->plugin('TagHelpers');
  $self->plugin('LocaleTextDomainOO', {
    file_type => 'mo',
    default => 'en',
    languages => [qw(en-US en ru)],
    support_url_langs => [ qw( en ru ) ],
    no_header_detect => 1,
  });
  $self->lexicon({
    search_dirs => [qw(locale)],
    gettext_to_maketext => 0,
    decode => 1,
    data   => [ '*::' => '*.mo' ],
  });

  push @{$self->commands->namespaces}, 'Samizdat::Command';
  unshift @{$self->plugins->namespaces}, 'Samizdat::Plugin';

  my $r = $self->routes;
  $r->any('/' => sub ($c) {} => 'index');
}

1;
