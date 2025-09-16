package Samizdat::Plugin::SMS;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::SMS;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  my $manager = $r->manager('sms')               ->to(controller => 'SMS')           ->name('sms');

  # Protected SMS routes - require authentication
  my $protected = $manager->under()              ->to(action => 'access');
  
  # Main SMS page (protected)
  $protected->any([qw(GET POST)] => '')          ->to(action => 'index')             ->name('sms_index');
  
  # SMS conversation with specific phone number  
  $protected->get('/conversation/:phone')        ->to(action => 'conversation')      ->name('sms_conversation');
  
  # API routes (protected)
  $protected->post('send')                       ->to(action => 'send')              ->name('sms_send');
  $protected->get('receive')                     ->to(action => 'receive')           ->name('sms_receive');
  $protected->get('messages')                    ->to(action => 'messages')          ->name('sms_messages');
  $protected->get('status')                      ->to(action => 'status')            ->name('sms_status');
  $protected->post('sync')                       ->to(action => 'sync')              ->name('sms_sync');
  $protected->delete('messages/:id')             ->to(action => 'delete')            ->name('sms_delete');
  
  # Webhook route - Teltonika posts incoming SMS here
  my $webhook_secret = $app->config->{sms}->{teltonika}->{secret};
  $manager->any([qw(GET POST)] => "/$webhook_secret") ->to(action => 'webhook')          ->name('sms_webhook');
  
  # Register helper
  $app->helper(sms => sub {
    state $sms = Samizdat::Model::SMS->new({
      config   => $app->config->{sms}->{teltonika},
      database => shift->pg,
    });
    return $sms;
  });
}

1;