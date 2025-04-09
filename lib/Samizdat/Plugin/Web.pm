package Samizdat::Plugin::Web;

use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Samizdat::Model::Web;

sub register ($self, $app, $conf) {
  my $r = $app->routes;
  $r->get('/manifest.json')->to(controller => 'Web', action => 'manifest', docpath => 'manifest.json');
  $r->get('/robots.txt')->to(controller => 'Web', action => 'robots', docpath => 'robots.txt');
  $r->get('/humans.txt')->to(controller => 'Web', action => 'humans', docpath => 'humans.txt');
  $r->get('/ads.txt')->to(controller => 'Web', action => 'ads', docpath => 'ads.txt');
  $r->get('/.well-known/security.txt')->to(controller => 'Web', action => 'security', docpath => '.well-known/security.txt');
  $r->get('/*docpath')->to(controller => 'Web', action => 'geturi');

  $app->helper(web => sub ($self) {
    state $web = Samizdat::Model::Web->new(app => $app);
    return $web;
  });

  $app->helper(headlinebuttons => sub ($self, $chunkname =  'chunks/sharebuttons') {
    return ($chunkname) ? $self->app->include($chunkname) : '';
  });

}


1;