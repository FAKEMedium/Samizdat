package Samizdat::Plugin::Example;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Example;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  my $manager = $r->manager('examples')->to(controller => 'Example');
  $manager->get('/:id/edit')              ->to('#edit')                             ->name('example_edit');
  $manager->get('new')                    ->to('#edit', id => 'new')                ->name('example_new');
  $manager->post('new')                   ->to('#create', id => 'new')              ->name('example_create');
  $manager->get('/:id')                   ->to('#show')                             ->name('example_show');
  $manager->put('/:id')                   ->to('#update')                           ->name('example_update');
  $manager->delete('/:id')                ->to('#delete')                           ->name('example_delete');
  $manager->get('/')                      ->to('#index')                            ->name('example_index');

  $app->helper(example => sub {
    state $example = Samizdat::Model::Example->new({
      pg => $app->pg,
      config => $self->config->{manager}->{example}
    });
    return $example;
  });

}

1;