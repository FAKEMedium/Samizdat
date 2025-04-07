package Samizdat::Plugin::Poll;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Poll;


sub register ($self, $app, $conf) {
  $app->helper(poll => sub {
    state $poll = Samizdat::Model::Poll->new({
      config   => $self->app->config->{poll},
      database => shift->pg,
    });
    return $poll;
  });

  my $r = $app->routes;
  my $polls = $r->under('poll');
  $polls->websocket('signatures')->to('Poll#signatures');
  $polls->any([qw( GET                       )] => 'signatures.svg')->to(controller => 'Poll', action => 'svg');
  $polls->any([qw( GET POST                  )] => '')->to(controller => 'Poll', action => 'index');
  $polls->any([qw( GET                       )] => 'confirm/:uuid')->to(controller => 'Poll', action => 'confirm');

  my $manager = $polls->under('manager')->to('Poll#access');
  $manager->any('/')->to('Poll#manager');

}


1;