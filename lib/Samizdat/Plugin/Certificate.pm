package Samizdat::Plugin::Certificate;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Certificate;
use Mojo::Loader qw(data_section);

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  # Store OpenAPI fragment (parsed centrally in _load_openapi)
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Certificate} = $openapi_yaml if $openapi_yaml;

  # Manager routes (HTML pages only - GET)
  my $manager = $r->manager('certificates')->to(controller => 'Certificate');
  $manager->get('/renew/:id')             ->to('#renew')                ->name('certificate_renew');
  $manager->get('/new')                   ->to('#edit', id => 'new')    ->name('certificate_new');
  $manager->get('/expiring')              ->to('#expiring')             ->name('certificate_expiring');
  $manager->get('/:id/edit')              ->to('#edit')                 ->name('certificate_edit');
  $manager->get('/:id')                   ->to('#show')                 ->name('certificate_show');
  $manager->get('/')                      ->to('#index')                ->name('certificate_index');

  # API routes are defined in OpenAPI spec (__DATA__ section)

  $app->helper(certificate => sub {
    state $model = Samizdat::Model::Certificate->new({
      pg => $app->pg,
      config => $app->config->{manager}->{certificate}
    });
    return $model;
  });

}

=head1 NAME

Samizdat::Plugin::Certificate - SSL/TLS Certificate management plugin

=head1 DESCRIPTION

This plugin provides certificate management functionality including listing,
creating, renewing, and deleting SSL/TLS certificates.

=head1 ROUTES

=head2 Manager Routes (HTML)

=over 4

=item * GET /manager/certificates - List certificates

=item * GET /manager/certificates/new - New certificate form

=item * GET /manager/certificates/expiring - List expiring certificates

=item * GET /manager/certificates/:id - Certificate details

=item * GET /manager/certificates/:id/edit - Edit certificate form

=item * GET /manager/certificates/renew/:id - Renew certificate page

=back

=head1 NGINX CONFIGURATION

Certificate routes use dynamic C<:id> parameters. The controller sets
C<docpath> to ensure all certificate IDs share the same cached template.

=head2 Regex Routes

    # Certificate details - any ID uses same cached template
    location ~ ^/manager/certificates/\d+$ {
        root /path/to/public;
        try_files /manager/certificates/show/index.html @backend;
    }

    # Certificate edit form
    location ~ ^/manager/certificates/\d+/edit$ {
        root /path/to/public;
        try_files /manager/certificates/edit/index.html @backend;
    }

    # Certificate renew
    location ~ ^/manager/certificates/renew/\d+$ {
        root /path/to/public;
        try_files /manager/certificates/renew/index.html @backend;
    }

    location @backend {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

=head2 API Routes (OpenAPI)

=over 4

=item * GET /api/certificates - List certificates

=item * POST /api/certificates - Create certificate

=item * GET /api/certificates/:id - Get certificate details

=item * PUT /api/certificates/:id - Update certificate

=item * DELETE /api/certificates/:id - Delete certificate

=item * POST /api/certificates/:id/renew - Renew certificate

=back

=cut

1;

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for Certificate API
paths:
  /certificates:
    get:
      operationId: Certificate.index
      x-mojo-to: Certificate#index
      summary: List certificates
      tags: [Certificate]
      parameters:
        - name: status
          in: query
          schema:
            type: string
            enum: [active, expired, expiring]
        - name: domain
          in: query
          schema:
            type: string
      responses:
        '200':
          description: List of certificates
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Certificate_ListResponse'
    post:
      operationId: Certificate.create
      x-mojo-to: Certificate#create
      summary: Create certificate
      tags: [Certificate]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Certificate_Input'
          application/x-www-form-urlencoded:
            schema:
              $ref: '#/components/schemas/Certificate_Input'
      responses:
        '200':
          description: Certificate created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Certificate_Result'

  /certificates/expiring:
    get:
      operationId: Certificate.expiring
      x-mojo-to: Certificate#expiring
      summary: List expiring certificates
      tags: [Certificate]
      parameters:
        - name: days
          in: query
          schema:
            type: integer
            default: 30
          description: Number of days until expiration
      responses:
        '200':
          description: List of expiring certificates
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Certificate_ListResponse'

  /certificates/{id}:
    get:
      operationId: Certificate.get
      x-mojo-to: Certificate#show
      summary: Get certificate details
      tags: [Certificate]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Certificate details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Certificate_Response'
    put:
      operationId: Certificate.update
      x-mojo-to: Certificate#update
      summary: Update certificate
      tags: [Certificate]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Certificate_Input'
          application/x-www-form-urlencoded:
            schema:
              $ref: '#/components/schemas/Certificate_Input'
      responses:
        '200':
          description: Certificate updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Certificate_Result'
    delete:
      operationId: Certificate.delete
      x-mojo-to: Certificate#delete
      summary: Delete certificate
      tags: [Certificate]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Certificate deleted
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Certificate_Result'

  /certificates/{id}/renew:
    post:
      operationId: Certificate.renew
      x-mojo-to: Certificate#renew
      summary: Renew certificate
      tags: [Certificate]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Certificate renewed
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Certificate_Result'

components:
  schemas:
    Certificate:
      type: object
      properties:
        certificateid:
          type: integer
        domain:
          type: string
        common_name:
          type: string
        issuer:
          type: string
        valid_from:
          type: string
          format: date-time
        valid_until:
          type: string
          format: date-time
        status:
          type: string
          enum: [active, expired, pending]
        auto_renew:
          type: boolean
        created_at:
          type: string
          format: date-time
    Certificate_Input:
      type: object
      required:
        - domain
      properties:
        domain:
          type: string
        common_name:
          type: string
        organization:
          type: string
        auto_renew:
          type: boolean
    Certificate_ListResponse:
      type: object
      properties:
        success:
          type: boolean
        certificates:
          type: array
          items:
            $ref: '#/components/schemas/Certificate'
        total:
          type: integer
    Certificate_Response:
      type: object
      properties:
        success:
          type: boolean
        certificate:
          $ref: '#/components/schemas/Certificate'
    Certificate_Result:
      type: object
      properties:
        success:
          type: boolean
        error:
          type: string
        message:
          type: string
        certificate:
          $ref: '#/components/schemas/Certificate'
