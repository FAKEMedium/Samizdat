package Samizdat::Plugin::Account;

use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Samizdat::Model::Account;

sub register ($self, $app, $conf) {
  $app->helper(account => sub { state $account = Samizdat::Model::Account->new(app => $app) });

  my $r = $app->routes;

  $r->any([qw( GET                       )] => '/register')->to(controller => 'Account', action => 'register');
  $r->any([qw( GET                       )] => '/register/confirm')->to(controller => 'Account', action => 'confirm');
  $r->any([qw( GET                       )] => '/register/password')->to(controller => 'Account', action => 'password');
  $r->any([qw( GET POST                  )] => '/login')->to(controller => 'Account', action => 'login');
  $r->any([qw( GET POST DELETE           )] => '/logout')->to(controller => 'Account', action => 'logout');

  $r->any([qw( GET                       )] => '/user')->to(controller => 'Account', action => 'user');

  my $panel = $r->under('panel')->to(controller => 'Account', action => 'authorize');
  $panel->get('/panel')->to(controller => 'Account', action => 'panel');

}


1;