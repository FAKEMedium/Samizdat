package Samizdat::Plugin::Web;

use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Samizdat::Model::Web;

sub register ($self, $app, $conf) {
  my $r = $app->routes;
  $r->any([qw( GET                       )] => '/manifest.json')->to(controller => 'Web', action => 'manifest', docpath => 'manifest.json');
  $r->any([qw( GET                       )] => '/robots.txt')->to(controller => 'Web', action => 'robots', docpath => 'robots.txt');
  $r->any([qw( GET                       )] => '/humans.txt')->to(controller => 'Web', action => 'humans', docpath => 'humans.txt');
  $r->any([qw( GET                       )] => '/ads.txt')->to(controller => 'Web', action => 'ads', docpath => 'ads.txt');
  $r->any([qw( GET                       )] => '/.well-known/security.txt')->to(controller => 'Web', action => 'security', docpath => '.well-known/security.txt');

  $app->helper(web => sub { state $web = Samizdat::Model::Web->new });

  $app->helper(headlinebuttons => sub ($self, $chunkname =  'chunks/sharebuttons') {
    return ($chunkname) ? $self->app->include($chunkname) : '';
  });

}


1;