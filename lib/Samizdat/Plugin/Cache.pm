package Samizdat::Plugin::Cache;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Cache;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  # Manager routes for cache administration
  my $manager = $r->manager('cache')->to(controller => 'Cache');
  $manager->get('/view')          ->to(template => 'cache/view/index');
  $manager->get('/:key')          ->to('#show')   ->name('cache_show');
  $manager->delete('/:key')       ->to('#delete') ->name('cache_delete');
  $manager->post('/purge')        ->to('#purge')  ->name('cache_purge');
  $manager->get('/')              ->to('#index')  ->name('cache_index');

  # Helper for accessing the Cache model
  $app->helper(cache => sub ($c) {
    state $model = Samizdat::Model::Cache->new({
      redis  => $c->redis,
      config => $app->config->{manager}->{cache},
    });

    # Update session reference for encryption
    $model->session($c->session) if $c->can('session');

    return $model;
  });
}

1;