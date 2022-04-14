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
  push @{$self->commands->namespaces}, 'Samizdat::Command';
  unshift @{$self->plugins->namespaces}, 'Samizdat::Plugin';
  $self->plugin('Utils');

  $self->hook(before_routes => sub {
    my $c = shift;
    my $language = $c->cookie('language') // 'sv';
    if ($language =~ /^(ru|sv|en)$/) {
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

  my $r = $self->routes;
  $r->any([qw(GET)] => '/')->to(controller => 'Markdown', action => 'geturi', docpath => '');
  $r->any([qw(GET)] => '/*docpath')->to(controller => 'Markdown', action => 'geturi');
}

1;
