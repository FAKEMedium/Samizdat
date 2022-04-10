package Samizdat;
use Mojo::Base 'Mojolicious', -signatures;
use Samizdat::Model::Markdown;


sub startup ($self) {

  my $config = $self->plugin('NotYAMLConfig');

  $self->secrets($config->{secrets});
  $self->helper(markdown => sub { state $markdown = Samizdat::Model::Markdown->new });
  $self->plugin('DefaultHelpers');
  $self->plugin('TagHelpers');
  $self->plugin('Subdispatch');
  $self->plugin('LocaleTextDomainOO', {
    file_type => 'mo',
    default => 'en',
    languages => [qw(en ru sv)],
    no_header_detect => 1,
  });
  $self->lexicon({
    search_dirs => [qw(locale)],
    gettext_to_maketext => 0,
    decode => 1,
    category => 'LC_MESSAGES',
    texxtdomain =>  'com.fakenews',
    data   => [
      '*:LC_MESSAGES:com.fakenews' => '*/LC_MESSAGES/com.fakenews.mo',
    ],
  });
  $self->language('en');
  push @{$self->commands->namespaces}, 'Samizdat::Command';
  unshift @{$self->plugins->namespaces}, 'Samizdat::Plugin';

  my $r = $self->routes;
  $r->any('/*url' => { url => ''} => sub ($c) {} => 'index');
}

1;
