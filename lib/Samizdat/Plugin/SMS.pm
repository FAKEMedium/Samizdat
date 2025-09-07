package Samizdat::Plugin::SMS;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::SMS;

sub register ($self, $app, $conf) {
  my $r = $app->routes;
  my $manager = $r->under($app->config->{managerurl});
  my $sms = $manager->under('sms');
  
  # Protected SMS routes - require authentication
  my $protected = $sms->under()->to('SMS#access');
  
  # Main SMS page (protected)
  $protected->any([qw(GET POST)] => '')->name('sms_index')->to(
    controller => 'SMS',
    action => 'index',
    docpath => 'sms/index.html',
  );
  
  # API routes (protected)
  $protected->post('send')->to(controller => 'SMS', action => 'send')->name('sms_send');
  $protected->get('receive')->to(controller => 'SMS', action => 'receive')->name('sms_receive');
  $protected->get('messages')->to(controller => 'SMS', action => 'messages')->name('sms_messages');
  $protected->get('status')->to(controller => 'SMS', action => 'status')->name('sms_status');
  $protected->post('sync')->to(controller => 'SMS', action => 'sync')->name('sms_sync');
  $protected->delete('messages/:id')->to(controller => 'SMS', action => 'delete')->name('sms_delete');
  
  # Webhook route - Teltonika posts incoming SMS here
  my $webhook_secret = $app->config->{sms}->{teltonika}->{secret};
  $sms->any([qw(GET POST)] => "/$webhook_secret")->to(controller => 'SMS', action => 'webhook')->name('sms_webhook');
  
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