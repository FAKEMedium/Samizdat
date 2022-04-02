package Samizdat;
use Mojo::Base 'Mojolicious', -signatures;
use Samizdat::Model::Markdown;


sub startup ($self) {

  my $config = $self->plugin('NotYAMLConfig');

  $self->secrets($config->{secrets});
  $self->helper(markdown => sub { state $markdown = Samizdat::Model::Markdown->new });
  push @{$self->commands->namespaces}, 'Samizdat::Command';
  unshift @{$self->plugins->namespaces}, 'Samizdat::Plugin';

  my $r = $self->routes;

  $r->get('/')->to('#index');
}

1;
