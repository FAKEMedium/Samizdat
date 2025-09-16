package Samizdat::Plugin::Manager;

use Mojo::Base 'Mojolicious::Plugin', -signatures;

sub register ($self, $app, $conf) {
  my $r = $app->routes;
  $r->root->add_shortcut(manager => sub {
    my ($route, $path) = @_;
    my $manager_url = $app->config->{manager}->{url} || '/manager/';
    $path = $manager_url . ($path || '');
    $path =~ s/\/{2,}/\//g;
    my $manager = $route->any($path);
    return $manager;
  });
  $r->manager->get('')->to(controller => 'Manager', action => 'index')->name('manager_index');

}

1;