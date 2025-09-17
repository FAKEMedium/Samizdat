package Samizdat::Plugin::SMS;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::SMS;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  my $manager = $r->manager('sms')->to(controller => 'SMS')->name('sms');

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

=head1 NAME

Samizdat::Plugin::SMS - SMS Management Plugin for Samizdat using Teltonika Devices

=head1 DESCRIPTION

This plugin provides SMS management functionality for the Samizdat application, leveraging Teltonika devices to send
and receive SMS messages. It includes routes for managing SMS conversations, sending messages, receiving incoming
messages, checking message status, and synchronizing messages.

=head1 ROUTES

=over 4
=item * GET /sms - Main SMS page (requires authentication)
=item * GET /sms/conversation/:phone - View conversation with a specific phone number (requires
  authentication)
=item * POST /sms/send - Send an SMS message (requires authentication)
=item * GET /sms/receive - Endpoint for receiving incoming SMS messages (requires authentication)
=item * GET /sms/messages - Retrieve a list of SMS messages (requires authentication)
=item * GET /sms/status - Check the status of sent messages (requires authentication)
=item * POST /sms/sync - Synchronize messages with the Teltonika device (requires
  authentication)
=item * DELETE /sms/messages/:id - Delete a specific SMS message by ID (requires authentication
=item * ANY /sms/<webhook_secret> - Webhook endpoint for Teltonika devices to post incoming SMS messages
  (no authentication required)
=back