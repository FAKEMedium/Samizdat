package Samizdat::Plugin::Poll;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Poll;
use Mojo::Loader qw(data_section);

sub register ($self, $app, $conf) {
  return if (!(exists($app->config->{manager}->{poll})));

  my $r = $app->routes;

  # Store OpenAPI fragment (parsed centrally in _load_openapi)
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Poll} = $openapi_yaml if $openapi_yaml;

  # Manager routes (HTML pages only - GET)
  my $manager = $r->manager('poll')->to(controller => 'Poll');
  $manager->get('/')                                     ->to('#index')           ->name('poll_manager');

  # Public routes (HTML pages)
  my $polls = $r->home('poll')->to(controller => 'Poll');
  $polls->websocket('signatures')                        ->to('#signatures')      ->name('poll_signatures_ws');
  $polls->get('signatures.svg')                          ->to('#svg')             ->name('poll_signatures_svg');
  $polls->get('confirm/:uuid')                           ->to('#confirm')         ->name('poll_confirm');
  $polls->get('/')                                       ->to('#index')           ->name('poll_index');

  # API routes are defined in OpenAPI spec (__DATA__ section)

  $app->helper(poll => sub {
    state $model = Samizdat::Model::Poll->new({
      config   => $app->settings->resolve('poll'),
      database => shift->pg,
    });
    return $model;
  });
}

=head1 NAME

Samizdat::Plugin::Poll - Poll and petition signature plugin

=head1 DESCRIPTION

This plugin provides poll/petition functionality including signature collection,
confirmation via email, and live signature display via WebSocket.

=head1 ROUTES

=head2 Public Routes (HTML)

=over 4

=item * GET /poll - Poll signing form

=item * GET /poll/confirm/:uuid - Confirm signature via email link

=item * GET /poll/signatures.svg - SVG visualization of signatures

=item * WebSocket /poll/signatures - Live signature updates

=back

=head2 Manager Routes (HTML)

=over 4

=item * GET /manager/poll - Poll management page

=back

=head2 API Routes (OpenAPI)

=over 4

=item * GET /api/poll - List polls

=item * POST /api/poll/sign - Submit poll signature

=item * GET /api/poll/:pollid - Get poll information

=item * GET /api/poll/:pollid/signers - Get list of signers

=back

=head1 NGINX CONFIGURATION

Poll routes include public pages and dynamic confirmation links.
The controller sets C<docpath> to ensure shared cached templates.

=head2 Regex Routes

    # Poll confirmation - UUID parameter uses same cached template
    location ~ ^/poll/confirm/[a-f0-9-]+$ {
        root /path/to/public;
        try_files /poll/confirm/index.html @backend;
    }

    # WebSocket for live signatures - always proxy
    location /poll/signatures {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }

    location @backend {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

=head1 SEE ALSO

L<Samizdat::Controller::Poll>, L<Samizdat::Model::Poll>

=cut

1;

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for Poll API
paths:
  /poll:
    get:
      operationId: Poll.index
      x-mojo-to: Poll#index
      summary: List polls
      tags: [Poll]
      parameters:
        - name: searchterm
          in: query
          schema:
            type: string
      responses:
        '200':
          description: List of polls
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Poll_ListResponse'

  /poll/sign:
    post:
      operationId: Poll.sign
      x-mojo-to: Poll#sign
      summary: Submit a poll signature
      tags: [Poll]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Poll_SignInput'
          application/x-www-form-urlencoded:
            schema:
              $ref: '#/components/schemas/Poll_SignInput'
      responses:
        '200':
          description: Signature submission result
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Poll_Result'

  /poll/{pollid}:
    get:
      operationId: Poll.get
      x-mojo-to: Poll#get
      summary: Get poll information
      tags: [Poll]
      parameters:
        - name: pollid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Poll information
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Poll_PollResponse'

  /poll/{pollid}/signers:
    get:
      operationId: Poll.signers
      x-mojo-to: Poll#signers
      summary: Get list of poll signers
      tags: [Poll]
      parameters:
        - name: pollid
          in: path
          required: true
          schema:
            type: integer
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
      responses:
        '200':
          description: List of signers
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Poll_SignersResponse'

  /poll/confirm/{uuid}:
    post:
      operationId: Poll.confirm
      x-mojo-to: Poll#confirm_api
      summary: Confirm a poll signature
      tags: [Poll]
      parameters:
        - name: uuid
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: Confirmation result
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Poll_Result'

components:
  schemas:
    Poll_SignInput:
      type: object
      required:
        - pollid
        - firstname
        - lastname
        - email
        - city
        - cc
      properties:
        pollid:
          type: integer
        firstname:
          type: string
        lastname:
          type: string
        email:
          type: string
          format: email
        pc:
          type: string
          description: Postal code
        city:
          type: string
        cc:
          type: string
          description: Country code
        captcha:
          type: string
    Poll_Poll:
      type: object
      properties:
        pollid:
          type: integer
        title:
          type: string
        description:
          type: string
        created_at:
          type: string
          format: date-time
        signature_count:
          type: integer
    Poll_PollResponse:
      type: object
      properties:
        success:
          type: boolean
        poll:
          $ref: '#/components/schemas/Poll_Poll'
    Poll_Signer:
      type: object
      properties:
        firstname:
          type: string
        lastname:
          type: string
        city:
          type: string
        country:
          type: string
        confirmed_at:
          type: string
          format: date-time
    Poll_SignersResponse:
      type: object
      properties:
        success:
          type: boolean
        signers:
          type: array
          items:
            $ref: '#/components/schemas/Poll_Signer'
        total:
          type: integer
    Poll_ListResponse:
      type: object
      properties:
        success:
          type: boolean
        polls:
          type: array
          items:
            $ref: '#/components/schemas/Poll_Poll'
    Poll_Result:
      type: object
      properties:
        success:
          type: boolean
        error:
          type: string
        message:
          type: string
        uuid:
          type: string
