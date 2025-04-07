package Samizdat::Plugin::Contact;

use Mojo::Base 'Mojolicious::Plugin', -signatures;

sub register ($self, $app, $conf = {}) {
  my $r = $app->routes;
  $r->any([qw( GET POST )] => '/contact')->to(controller => 'Contact', action => 'index')->name('contact');
}

1;