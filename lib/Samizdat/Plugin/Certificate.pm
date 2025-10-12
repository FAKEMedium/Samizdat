package Samizdat::Plugin::Certificate;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Certificate;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  my $manager = $r->manager('certificates')->to(controller => 'Certificate');
  $manager->get('/renew/:id')             ->to('#renew')                            ->name('certificate_renew');
  $manager->get('/new')                   ->to('#edit', id => 'new')                ->name('certificate_new');
  $manager->post('/new')                  ->to('#create', id => 'new')              ->name('certificate_create');
  $manager->get('/expiring')              ->to('#expiring')                         ->name('certificate_expiring');
  $manager->get('/:id/edit')              ->to('#edit')                             ->name('certificate_edit');
  $manager->get('/:id')                   ->to('#show')                             ->name('certificate_show');
  $manager->put('/:id')                   ->to('#update')                           ->name('certificate_update');
  $manager->delete('/:id')                ->to('#delete')                           ->name('certificate_delete');
  $manager->get('/')                      ->to('#index')                            ->name('certificate_index');

  $app->helper(certificate => sub {
    state $certificate = Samizdat::Model::Certificate->new({
      pg => $app->pg,
      config => $self->config->{manager}->{certificate}
    });
    return $certificate;
  });

}

1;
