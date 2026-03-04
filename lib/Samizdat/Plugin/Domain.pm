package Samizdat::Plugin::Domain;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Domain;
use Mojo::Loader qw(data_section);

sub register ($self, $app, $conf) {
  return if (!(exists($app->config->{manager}->{domain})));

  my $r = $app->routes;

  # Store OpenAPI fragment (parsed centrally in _load_openapi)
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Domain} = $openapi_yaml if $openapi_yaml;

  # Cacheable HTML pages (content negotiation - HTML for browsers, JSON for API)
  my $manager = $r->manager('domain')->to(controller => 'Domain');
  $manager->get('/register')                                   ->to('#register')        ->name('domain_register');
  $manager->get('/transfer')                                   ->to('#transfer')        ->name('domain_transfer');
  $manager->get('/')                                           ->to('#index')           ->name('domain_index');

  my $customers = $r->manager('customers/:customerid/domains') ->to(controller => 'Domain');
  $customers->get('/register')                                 ->to('#register')        ->name('customer_domain_register');
  $customers->get('/transfer')                                 ->to('#transfer')        ->name('customer_domain_transfer');
  $customers->get('/#domainid')                                ->to('#get')             ->name('domain_get');
  $customers->get('/')                                         ->to('#index')           ->name('customer_domains');

  my $contacts = $r->manager('domain/contacts')->to(controller => 'Domain');
  $contacts->get('/new')                                       ->to('#contact_edit')    ->name('domain_contact_new');
  $contacts->get('/:handle')                                   ->to('#contact')         ->name('domain_contact');
  $contacts->get('/')                                          ->to('#contacts')        ->name('domain_contacts');

  # API-only routes handled by OpenAPI (POST, PUT, DELETE)

  $app->helper(domain => sub ($self) {
    state $model = Samizdat::Model::Domain->new({
      config            => $self->config->{manager}->{domain},
      pg                => $self->pg,
      mysql             => $self->mysql,
      epp               => $app->renderer->helpers->{epp} ? $self->epp : undef,
      realtimeregister  => $app->renderer->helpers->{realtimeregister} ? $self->realtimeregister : undef,
    });
    return $model;
  });
}

=head1 NAME

Samizdat::Plugin::Domain - Domain management plugin

=head1 DESCRIPTION

This plugin provides domain registration management, integrating with
EPP registrars and RealtimeRegister when available.

=head1 NGINX CONFIGURATION

Domain routes use dynamic parameters. The controller sets C<docpath>
to ensure shared cached templates.

=head2 Regex Routes

    # Customer domains list
    location ~ ^/manager/customers/\d+/domains/?$ {
        root /path/to/public;
        try_files /manager/customers/domains/index.html @backend;
    }

    # Domain details
    location ~ ^/manager/customers/\d+/domains/\d+$ {
        root /path/to/public;
        try_files /manager/customers/domains/domain/index.html @backend;
    }

    location @backend {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

=head1 SEE ALSO

L<Samizdat::Controller::Domain>, L<Samizdat::Model::Domain>

=cut

1;

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for Domain API
paths:
  /domain:
    get:
      operationId: Domain.index
      x-mojo-to: Domain#index
      summary: List all domains
      tags: [Domain]
      responses:
        '200':
          description: List of domains
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Domain_ListResponse'

  /customers/{customerid}/domains:
    get:
      operationId: Domain.customer.index
      x-mojo-to: Domain#index
      summary: List customer domains
      tags: [Domain]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: List of customer domains
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Domain_ListResponse'

  /domain/register:
    get:
      operationId: Domain.register
      x-mojo-to: Domain#register
      summary: Domain registration form
      tags: [Domain]
      responses:
        '200':
          description: Domain registration form
    post:
      operationId: Domain.register.create
      x-mojo-to: Domain#register_create
      summary: Register domain
      tags: [Domain]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Domain_RegisterInput'
      responses:
        '201':
          description: Domain registered
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Domain_Domain'

  /customers/{customerid}/domains/register:
    get:
      operationId: Domain.customer.register
      x-mojo-to: Domain#register
      summary: Domain registration form for customer
      tags: [Domain]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Domain registration form
    post:
      operationId: Domain.customer.register.create
      x-mojo-to: Domain#register_create
      summary: Register domain for customer
      tags: [Domain]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Domain_RegisterInput'
      responses:
        '201':
          description: Domain registered
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Domain_Domain'

  /customers/{customerid}/domains/{domainid}:
    get:
      operationId: Domain.customer.get
      x-mojo-to: Domain#get
      summary: Get domain details
      tags: [Domain]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
        - name: domainid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Domain details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Domain_Domain'

  /domain/transfer:
    get:
      operationId: Domain.transfer
      x-mojo-to: Domain#transfer
      summary: Domain transfer form
      tags: [Domain]
      responses:
        '200':
          description: Domain transfer form
    post:
      operationId: Domain.transfer.create
      x-mojo-to: Domain#transfer_create
      summary: Transfer domain
      tags: [Domain]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Domain_TransferInput'
      responses:
        '201':
          description: Domain transfer initiated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Domain_TransferResponse'

  /customers/{customerid}/domains/transfer:
    get:
      operationId: Domain.customer.transfer
      x-mojo-to: Domain#transfer
      summary: Domain transfer form for customer
      tags: [Domain]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Domain transfer form
    post:
      operationId: Domain.customer.transfer.create
      x-mojo-to: Domain#transfer_create
      summary: Transfer domain for customer
      tags: [Domain]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Domain_TransferInput'
      responses:
        '201':
          description: Domain transfer initiated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Domain_TransferResponse'

  /domain/contacts:
    get:
      operationId: Domain.contacts
      x-mojo-to: Domain#contacts
      summary: List contacts
      tags: [Domain]
      parameters:
        - name: search
          in: query
          schema:
            type: string
        - name: page
          in: query
          schema:
            type: integer
        - name: per_page
          in: query
          schema:
            type: integer
      responses:
        '200':
          description: List of contacts
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Domain_ContactListResponse'

  /domain/contacts/new:
    get:
      operationId: Domain.contact.edit
      x-mojo-to: Domain#contact_edit
      summary: New contact form
      tags: [Domain]
      responses:
        '200':
          description: Contact form
    post:
      operationId: Domain.contact.create
      x-mojo-to: Domain#contact_create
      summary: Create contact
      tags: [Domain]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Domain_ContactInput'
      responses:
        '201':
          description: Contact created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Domain_Contact'

  /domain/contacts/{handle}:
    get:
      operationId: Domain.contact.get
      x-mojo-to: Domain#contact
      summary: Get contact details
      tags: [Domain]
      parameters:
        - name: handle
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Contact details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Domain_Contact'
    put:
      operationId: Domain.contact.update
      x-mojo-to: Domain#contact_update
      summary: Update contact
      tags: [Domain]
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
              $ref: '#/components/schemas/Domain_ContactInput'
      responses:
        '200':
          description: Contact updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Domain_Contact'
    delete:
      operationId: Domain.contact.delete
      x-mojo-to: Domain#contact_delete
      summary: Delete contact
      tags: [Domain]
      parameters:
        - name: handle
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Contact deleted

components:
  schemas:
    Domain_Domain:
      type: object
      properties:
        domainid:
          type: integer
        domainname:
          type: string
        curexpiry:
          type: string
          format: date
        dontrenew:
          type: boolean
        due:
          type: boolean
        customerid:
          type: integer
    Domain_Input:
      type: object
      properties:
        domainname:
          type: string
        curexpiry:
          type: string
          format: date
        dontrenew:
          type: boolean
      required:
        - domainname
    Domain_RegisterInput:
      type: object
      properties:
        domainname:
          type: string
        period:
          type: integer
          description: Registration period in years
        registrant:
          type: string
          description: Registrant contact handle
        admin:
          type: string
          description: Admin contact handle
        tech:
          type: string
          description: Tech contact handle
        nameservers:
          type: array
          items:
            type: string
      required:
        - domainname
        - registrant
    Domain_TransferInput:
      type: object
      properties:
        domainname:
          type: string
        authcode:
          type: string
          description: Authorization code from current registrar
        period:
          type: integer
          description: Registration period in years
        registrant:
          type: string
          description: Registrant contact handle
        admin:
          type: string
          description: Admin contact handle
        tech:
          type: string
          description: Tech contact handle
      required:
        - domainname
        - registrant
    Domain_TransferResponse:
      type: object
      properties:
        success:
          type: boolean
        domain:
          $ref: '#/components/schemas/Domain_Domain'
        error:
          type: string
    Domain_ListResponse:
      type: object
      properties:
        success:
          type: boolean
        domains:
          type: array
          items:
            $ref: '#/components/schemas/Domain_Domain'
    Domain_Contact:
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
        fax:
          type: string
        street:
          type: array
          items:
            type: string
        city:
          type: string
        postalCode:
          type: string
        country:
          type: string
        orgno:
          type: string
        vatno:
          type: string
        source:
          type: string
          description: Source system (epp or realtimeregister)
    Domain_ContactInput:
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
        fax:
          type: string
        street:
          type: array
          items:
            type: string
        city:
          type: string
        postalCode:
          type: string
        country:
          type: string
        orgno:
          type: string
        vatno:
          type: string
      required:
        - handle
        - name
        - email
    Domain_ContactListResponse:
      type: object
      properties:
        contacts:
          type: array
          items:
            $ref: '#/components/schemas/Domain_Contact'
        page:
          type: integer
        pages:
          type: integer
        total:
          type: integer