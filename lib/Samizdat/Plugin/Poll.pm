package Samizdat::Plugin::Poll;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Poll;


sub register ($self, $app, $conf) {
  my $r = $app->routes;

  my $manager = $r->manager('poll')->to(controller => 'Poll');
  $manager->any('/')                                   ->to('#manager')         ->name('poll_manager');

  my $polls = $r->home('poll')->to(controller => 'Poll');
  $polls->websocket('signatures')                     ->to('#signatures')       ->name('poll_signatures_ws');
  $polls->any([qw( GET )] => 'signatures.svg')        ->to('#svg')              ->name('poll_signatures_svg');
  $polls->any([qw( GET )] => 'confirm/:uuid')         ->to('#confirm')          ->name('poll_confirm');
  $polls->any([qw( GET POST )] => '')                 ->to('#index')            ->name('poll_index');


  $app->helper(poll => sub {
    state $poll = Samizdat::Model::Poll->new({
      config   => $self->app->config->{poll},
      database => shift->pg,
    });
    return $poll;
  });
}

1;