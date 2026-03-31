package Samizdat::Plugin::Chat;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::Loader qw(data_section);
use Samizdat::Model::Chat;

sub register ($self, $app, $conf) {
  return unless $app->config->{anthropic};

  my $r = $app->routes;

  # Store OpenAPI fragment
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Chat} = $openapi_yaml if $openapi_yaml;

  # Manager routes (HTML pages - GET)
  my $manager = $r->manager('chat')->to(controller => 'Chat');
  $manager->get('/')               ->to('#index')  ->name('chat_index');

  # WebSocket route (not OpenAPI, needs its own route)
  $manager->websocket('/stream')   ->to('#stream') ->name('chat_stream_ws');

  # API routes are defined in OpenAPI spec (__DATA__ section)

  # Helper
  $app->helper(chat => sub ($c) {
    state $model = Samizdat::Model::Chat->new({
      config => $c->config->{anthropic},
      redis  => $c->app->redis,
    });
    return $model;
  });
}

1;

__DATA__

@@ openapi.yaml
paths:
  /chat/conversations:
    get:
      operationId: Chat.conversations.index
      x-mojo-to: Chat#conversations
      summary: List saved conversations
      tags: [Chat]
      responses:
        '200':
          description: List of conversations
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Chat_ConversationList'
    post:
      operationId: Chat.conversations.save
      x-mojo-to: Chat#save
      summary: Save a conversation
      tags: [Chat]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Chat_ConversationInput'
      responses:
        '200':
          description: Conversation saved
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Chat_Result'

  /chat/conversations/{id}:
    get:
      operationId: Chat.conversations.get
      x-mojo-to: Chat#conversations
      summary: Get a conversation
      tags: [Chat]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Conversation details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Chat_Conversation'
    delete:
      operationId: Chat.conversations.delete
      x-mojo-to: Chat#delete
      summary: Delete a conversation
      tags: [Chat]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Conversation deleted
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Chat_Result'

components:
  schemas:
    Chat_Message:
      type: object
      properties:
        role:
          type: string
          enum: [user, assistant]
        content:
          type: string
    Chat_Conversation:
      type: object
      properties:
        id:
          type: string
        title:
          type: string
        messages:
          type: array
          items:
            $ref: '#/components/schemas/Chat_Message'
        created:
          type: string
          format: date-time
        updated:
          type: string
          format: date-time
    Chat_ConversationList:
      type: object
      properties:
        conversations:
          type: array
          items:
            $ref: '#/components/schemas/Chat_Conversation'
    Chat_ConversationInput:
      type: object
      required: [messages]
      properties:
        title:
          type: string
        messages:
          type: array
          items:
            $ref: '#/components/schemas/Chat_Message'
    Chat_Result:
      type: object
      properties:
        success:
          type: boolean
        error:
          type: string
