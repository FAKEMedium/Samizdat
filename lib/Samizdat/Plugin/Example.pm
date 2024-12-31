package Samizdat::Plugin::Example;

use Mojo::Base 'Mojolicious::Plugin', -signatures;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  $r->any(sprintf('example'))->to(text => '
    This is output from Samizdat::Plugin::Example.
    You can add your own plugins in the configuration file.
');

}

1;