package Samizdat::Plugin::Domain;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Domain;
use Mojo::Loader qw(data_section);

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  # Store OpenAPI fragment (parsed centrally in _load_openapi)
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Domain} = $openapi_yaml if $openapi_yaml;

  my $manager = $r->manager('domain')->to(controller => 'Domain');
  $manager->get('/')                                           ->to('#index')                    ->name('domain_index');

  my $customers = $r->manager('customers/:customerid/domains')->to(controller => 'Domain');
  $customers->get('/open')                                     ->to('#edit')                     ->name('domain_edit');
  $customers->put('/open')                                     ->to('#update')                   ->name('domain_update');
  $customers->post('/open')                                    ->to('#create')                   ->name('domain_create');
  $customers->get('/:domainid')                                ->to('#get')                      ->name('domain_get');
  $customers->get('/')                                         ->to('#index')                    ->name('customer_domains');

  $app->helper(domain => sub ($self) {
    state $model = Samizdat::Model::Domain->new({
      config => $self->config->{manager}->{domain},
      pg     => $self->pg,
      mysql  => $self->mysql,
    });
    return $model;
  });
}

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

  /customers/{customerid}/domains/open:
    get:
      operationId: Domain.customer.edit
      x-mojo-to: Domain#edit
      summary: Edit domain form
      tags: [Domain]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Domain edit form
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Domain_Domain'
    post:
      operationId: Domain.customer.create
      x-mojo-to: Domain#create
      summary: Create domain
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
              $ref: '#/components/schemas/Domain_Input'
      responses:
        '201':
          description: Domain created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Domain_Domain'
    put:
      operationId: Domain.customer.update
      x-mojo-to: Domain#update
      summary: Update domain
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
              $ref: '#/components/schemas/Domain_Input'
      responses:
        '200':
          description: Domain updated
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

components:
  schemas:
    Domain_Domain:
      type: object
      properties:
        id:
          type: integer
        name:
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
        name:
          type: string
        curexpiry:
          type: string
          format: date
        dontrenew:
          type: boolean
      required:
        - name
    Domain_ListResponse:
      type: object
      properties:
        success:
          type: boolean
        domains:
          type: array
          items:
            $ref: '#/components/schemas/Domain_Domain'