package Samizdat::Plugin::Manager;

use Mojo::Base 'Mojolicious::Plugin', -signatures;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  $r->manager->get('')->to(controller => 'Manager', action => 'index')->name('manager_index');


}

1;