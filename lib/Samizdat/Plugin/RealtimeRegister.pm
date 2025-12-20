package Samizdat::Plugin::RealtimeRegister;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::RealtimeRegister;
use Mojo::Loader qw(data_section);

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  # Store OpenAPI fragment (parsed centrally in _load_openapi)
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{RealtimeRegister} = $openapi_yaml if $openapi_yaml;

  # Manager routes (HTML pages only - GET)
  my $manager = $r->manager('realtimeregister')->to(controller => 'RealtimeRegister');
  $manager->get('domains/#domain')          ->to('#domain')           ->name('rtr_domain');
  $manager->get('domains')                  ->to('#domains')          ->name('rtr_domains');
  $manager->get('contacts/:handle')         ->to('#contact')          ->name('rtr_contact');
  $manager->get('contacts')                 ->to('#contacts')         ->name('rtr_contacts');
  $manager->get('/')                        ->to('#index')            ->name('rtr_index');

  # API routes are defined in OpenAPI spec (__DATA__ section)

  # Helper for accessing the RealtimeRegister API model
  $app->helper(realtimeregister => sub ($c) {
    state $model = Samizdat::Model::RealtimeRegister->new({
      config => $app->config->{manager}->{realtimeregister},
    });
    return $model;
  });
}

=head1 NAME

Samizdat::Plugin::RealtimeRegister - RealtimeRegister API plugin

=head1 DESCRIPTION

This plugin provides RealtimeRegister domain registrar integration for Samizdat.
It includes routes for managing domains and contacts, plus a helper for API access.

=head1 ROUTES

All routes require admin access. API routes are defined in the OpenAPI spec.

=head2 Manager Routes (HTML)

=over 4

=item GET /manager/realtimeregister/domains - List domains page

=item GET /manager/realtimeregister/domains/:domain - Domain detail page

=item GET /manager/realtimeregister/contacts - List contacts page

=item GET /manager/realtimeregister/contacts/:handle - Contact detail page

=back

=head2 API Routes (via OpenAPI at /api/realtimeregister/...)

Domain and contact CRUD operations are available via the REST API.

=head1 HELPERS

=head2 realtimeregister

  my $rtr = $c->realtimeregister;
  my $domains = $rtr->getDomains();

Returns the RealtimeRegister model instance for API operations.

=head1 NGINX CONFIGURATION

RealtimeRegister routes use dynamic parameters for domains and contacts.
Domain names contain dots, so relaxed placeholder matching is used (C<#>).
The controller sets C<docpath> to ensure shared cached templates.

=head2 Regex Routes

    # Domain details - matches domain names with dots (e.g., example.com)
    location ~ ^/manager/realtimeregister/domains/[^/]+\.[^/]+$ {
        root /path/to/public;
        try_files /manager/realtimeregister/domains/domain/index.html @backend;
    }

    # Contact details
    location ~ ^/manager/realtimeregister/contacts/[^/]+$ {
        root /path/to/public;
        try_files /manager/realtimeregister/contacts/contact/index.html @backend;
    }

    location @backend {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

=head1 SEE ALSO

L<Samizdat::Controller::RealtimeRegister>, L<Samizdat::Model::RealtimeRegister>

=cut

1;

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for RealtimeRegister API
paths:
  /realtimeregister/domains:
    get:
      operationId: RTR.domains.index
      x-mojo-to: RealtimeRegister#domains
      summary: List all domains
      tags: [RealtimeRegister]
      parameters:
        - name: limit
          in: query
          schema:
            type: integer
        - name: offset
          in: query
          schema:
            type: integer
        - name: q
          in: query
          schema:
            type: string
      responses:
        '200':
          description: List of domains
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/RTR_DomainListResponse'
    post:
      operationId: RTR.domains.create
      x-mojo-to: RealtimeRegister#create_domain
      summary: Register a new domain
      tags: [RealtimeRegister]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/RTR_DomainInput'
      responses:
        '200':
          description: Created domain
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/RTR_Domain'

  /realtimeregister/domains/{domain}:
    get:
      operationId: RTR.domains.get
      x-mojo-to: RealtimeRegister#domain
      summary: Get domain details
      tags: [RealtimeRegister]
      parameters:
        - name: domain
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      responses:
        '200':
          description: Domain data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/RTR_Domain'
    put:
      operationId: RTR.domains.update
      x-mojo-to: RealtimeRegister#update_domain
      summary: Update domain
      tags: [RealtimeRegister]
      parameters:
        - name: domain
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/RTR_DomainInput'
      responses:
        '200':
          description: Updated domain
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/RTR_Domain'
    delete:
      operationId: RTR.domains.delete
      x-mojo-to: RealtimeRegister#delete_domain
      summary: Delete/cancel domain
      tags: [RealtimeRegister]
      parameters:
        - name: domain
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      responses:
        '200':
          description: Domain deleted
          content:
            application/json:
              schema:
                type: object

  /realtimeregister/contacts:
    get:
      operationId: RTR.contacts.index
      x-mojo-to: RealtimeRegister#contacts
      summary: List all contacts
      tags: [RealtimeRegister]
      parameters:
        - name: limit
          in: query
          schema:
            type: integer
        - name: offset
          in: query
          schema:
            type: integer
        - name: q
          in: query
          schema:
            type: string
      responses:
        '200':
          description: List of contacts
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/RTR_ContactListResponse'
    post:
      operationId: RTR.contacts.create
      x-mojo-to: RealtimeRegister#create_contact
      summary: Create a new contact
      tags: [RealtimeRegister]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/RTR_ContactInput'
      responses:
        '200':
          description: Created contact
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/RTR_Contact'

  /realtimeregister/contacts/{handle}:
    get:
      operationId: RTR.contacts.get
      x-mojo-to: RealtimeRegister#contact
      summary: Get contact details
      tags: [RealtimeRegister]
      parameters:
        - name: handle
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Contact data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/RTR_Contact'
    put:
      operationId: RTR.contacts.update
      x-mojo-to: RealtimeRegister#update_contact
      summary: Update contact
      tags: [RealtimeRegister]
      parameters:
        - name: handle
          in: path
          required: true
          schema:
            type: string
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/RTR_ContactInput'
      responses:
        '200':
          description: Updated contact
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/RTR_Contact'
    delete:
      operationId: RTR.contacts.delete
      x-mojo-to: RealtimeRegister#delete_contact
      summary: Delete contact
      tags: [RealtimeRegister]
      parameters:
        - name: handle
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Contact deleted
          content:
            application/json:
              schema:
                type: object

components:
  schemas:
    RTR_Domain:
      type: object
      properties:
        domainName:
          type: string
        registrant:
          type: string
        status:
          type: string
        expiryDate:
          type: string
          format: date-time
        autoRenew:
          type: boolean
        nameservers:
          type: array
          items:
            type: string
    RTR_DomainInput:
      type: object
      properties:
        domainName:
          type: string
        registrant:
          type: string
        period:
          type: integer
        nameservers:
          type: array
          items:
            type: string
    RTR_DomainListResponse:
      type: object
      properties:
        domains:
          type: array
          items:
            $ref: '#/components/schemas/RTR_Domain'
        pagination:
          $ref: '#/components/schemas/RTR_Pagination'
    RTR_Contact:
      type: object
      properties:
        handle:
          type: string
        name:
          type: string
        organization:
          type: string
        email:
          type: string
        phone:
          type: string
        address:
          type: object
    RTR_ContactInput:
      type: object
      properties:
        handle:
          type: string
        name:
          type: string
        organization:
          type: string
        email:
          type: string
        phone:
          type: string
        address:
          type: object
    RTR_ContactListResponse:
      type: object
      properties:
        contacts:
          type: array
          items:
            $ref: '#/components/schemas/RTR_Contact'
        pagination:
          $ref: '#/components/schemas/RTR_Pagination'
    RTR_Pagination:
      type: object
      properties:
        limit:
          type: integer
        offset:
          type: integer
        total:
          type: integer
