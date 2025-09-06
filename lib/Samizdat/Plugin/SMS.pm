package Samizdat::Plugin::SMS;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::SMS;

sub register ($self, $app, $conf) {
  my $r = $app->routes;
  my $sms = $r->under('sms');
  
  # Public routes
  $sms->any([qw(GET POST)] => '')->name('sms_index')->to(
    controller => 'SMS',
    action => 'index',
    docpath => 'sms/index.html',
  );
  
  # API routes
  $sms->post('send')->to(controller => 'SMS', action => 'send')->name('sms_send');
  $sms->get('receive')->to(controller => 'SMS', action => 'receive')->name('sms_receive');
  $sms->get('messages')->to(controller => 'SMS', action => 'messages')->name('sms_messages');
  $sms->get('status')->to(controller => 'SMS', action => 'status')->name('sms_status');
  $sms->post('sync')->to(controller => 'SMS', action => 'sync')->name('sms_sync');
  $sms->delete('messages/:id')->to(controller => 'SMS', action => 'delete')->name('sms_delete');
  
  # Webhook route - Teltonika posts incoming SMS here
  my $webhook_secret = $app->config->{sms}->{teltonika}->{secret};
  $sms->any([qw(GET POST)] => "/$webhook_secret")->to(controller => 'SMS', action => 'webhook')->name('sms_webhook');
  
  # Manager routes (protected)
  my $manager = $sms->under('manager')->to('SMS#access');
  $manager->any('/')->to('SMS#manager')->name('sms_manager');
  
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