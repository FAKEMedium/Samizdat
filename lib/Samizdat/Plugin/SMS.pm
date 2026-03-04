package Samizdat::Plugin::SMS;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::SMS;
use Mojo::Loader qw(data_section);

sub register ($self, $app, $conf) {
  return if (!(exists($app->config->{manager}->{sms})));

  my $r = $app->routes;

  # Store OpenAPI fragment (parsed centrally in _load_openapi)
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{SMS} = $openapi_yaml if $openapi_yaml;

  # Manager routes (HTML pages only - GET)
  my $manager = $r->manager('sms')->to(controller => 'SMS')->name('sms');
  $manager->get('/conversation/:phone')                      ->to(action => 'conversation')    ->name('sms_conversation');
  $manager->get('/messages')                                 ->to(action => 'messages')        ->name('sms_messages');
  $manager->get('/status')                                   ->to(action => 'status')          ->name('sms_status');
  $manager->get('/receive')                                  ->to(action => 'receive')         ->name('sms_receive');
  $manager->get('/')                                         ->to(action => 'index')           ->name('sms_index');

  # Webhook route - Teltonika posts incoming SMS here (no auth required)
  my $webhook_secret = $app->config->{manager}->{sms}->{webhook_secret};
  $manager->any($webhook_secret)                             ->to(action => 'webhook')         ->name('sms_webhook');

  # API routes are defined in OpenAPI spec (__DATA__ section)

  # Register helper
  $app->helper(sms => sub ($c) {
    state $model = Samizdat::Model::SMS->new({
      config   => $app->config->{manager}->{sms},
      database => $c->pg,
      app      => $app,
    });
    return $model;
  });
}

=head1 NAME

Samizdat::Plugin::SMS - SMS Management Plugin for Samizdat using Teltonika Devices

=head1 DESCRIPTION

This plugin provides SMS management functionality for the Samizdat application, leveraging Teltonika devices to send
and receive SMS messages. It includes routes for managing SMS conversations, sending messages, receiving incoming
messages, checking message status, and synchronizing messages.

=head1 ROUTES

=head2 Manager Routes (HTML)

=over 4

=item * GET /manager/sms - Main SMS page

=item * GET /manager/sms/conversation/:phone - View conversation with a specific phone number

=item * GET /manager/sms/messages - Retrieve list of SMS messages

=item * GET /manager/sms/status - Check the status of sent messages

=item * GET /manager/sms/receive - Endpoint for receiving incoming SMS messages

=item * ANY /manager/sms/<webhook_secret> - Webhook for Teltonika devices

=back

=head2 API Routes (OpenAPI)

=over 4

=item * POST /api/sms/send - Send an SMS message

=item * POST /api/sms/sync - Synchronize messages with Teltonika device

=item * DELETE /api/sms/messages/:id - Delete a specific SMS message

=back

=head1 NGINX CONFIGURATION

SMS routes use dynamic C<:phone> parameters for conversations. The controller
sets C<docpath> to ensure all phone numbers share the same cached template.

=head2 Regex Routes

    # SMS conversation - phone numbers use same cached template
    # Phone can be +46701234567 or similar, URL-encoded
    location ~ ^/manager/sms/conversation/[^/]+$ {
        root /path/to/public;
        try_files /manager/sms/conversation/index.html @backend;
    }

    # Webhook route - always proxy (no caching)
    location ~ ^/manager/sms/[a-zA-Z0-9_-]{20,}$ {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location @backend {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

=cut

1;

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for SMS API
paths:
  /sms/send:
    post:
      operationId: SMS.send
      x-mojo-to: SMS#send
      summary: Send an SMS message
      tags: [SMS]
      requestBody:
        content:
          application/x-www-form-urlencoded:
            schema:
              $ref: '#/components/schemas/SMS_SendInput'
          application/json:
            schema:
              $ref: '#/components/schemas/SMS_SendInput'
      responses:
        '200':
          description: SMS send result
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/SMS_Result'

  /sms/sync:
    post:
      operationId: SMS.sync
      x-mojo-to: SMS#sync
      summary: Synchronize messages with Teltonika device
      tags: [SMS]
      responses:
        '200':
          description: Sync result
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/SMS_SyncResult'

  /sms/messages:
    get:
      operationId: SMS.messages.index
      x-mojo-to: SMS#messages
      summary: List SMS messages
      tags: [SMS]
      parameters:
        - name: phone
          in: query
          schema:
            type: string
          description: Filter by phone number
        - name: limit
          in: query
          schema:
            type: integer
            default: 20
        - name: offset
          in: query
          schema:
            type: integer
            default: 0
        - name: total
          in: query
          schema:
            type: integer
          description: Include total count if set to 1
      responses:
        '200':
          description: List of messages
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/SMS_MessageListResponse'

  /sms/messages/{id}:
    delete:
      operationId: SMS.messages.delete
      x-mojo-to: SMS#delete
      summary: Delete an SMS message
      tags: [SMS]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Delete result
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/SMS_Result'

  /sms/status:
    get:
      operationId: SMS.status
      x-mojo-to: SMS#status
      summary: Check status of sent messages
      tags: [SMS]
      responses:
        '200':
          description: Status information
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/SMS_StatusResponse'

components:
  schemas:
    SMS_SendInput:
      type: object
      required:
        - to
        - message
      properties:
        to:
          type: string
          description: Recipient phone number
        message:
          type: string
          description: Message content
    SMS_Message:
      type: object
      properties:
        id:
          type: integer
        phone:
          type: string
        message:
          type: string
        direction:
          type: string
          enum: [inbound, outbound]
        status:
          type: string
        created_at:
          type: string
          format: date-time
    SMS_MessageListResponse:
      type: object
      properties:
        success:
          type: boolean
        messages:
          type: array
          items:
            $ref: '#/components/schemas/SMS_Message'
        total:
          type: integer
    SMS_SyncResult:
      type: object
      properties:
        success:
          type: boolean
        synced:
          type: integer
        error:
          type: string
    SMS_StatusResponse:
      type: object
      properties:
        success:
          type: boolean
        status:
          type: object
    SMS_Result:
      type: object
      properties:
        success:
          type: boolean
        error:
          type: string
        message_text:
          type: string
