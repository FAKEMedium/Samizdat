package Samizdat::Plugin::Database;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Database;
use Mojo::Loader qw(data_section);

sub register ($self, $app, $conf) {
  return if (!(exists($app->config->{manager}->{database})));

  my $r = $app->routes;

  # Store OpenAPI fragment
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Database} = $openapi_yaml if $openapi_yaml;

  # Cacheable HTML pages
  my $manager = $r->manager('databases')->to(controller => 'Database');
  $manager->get('/new')                                      ->to('#add')       ->name('database_new');
  $manager->get('/:databaseid/edit')                         ->to('#edit')      ->name('database_edit');
  $manager->get('/:databaseid')                              ->to('#get')       ->name('database_get');
  $manager->get('/')                                         ->to('#index')     ->name('database_index');

  my $customers = $r->manager('customers/:customerid/databases')->to(controller => 'Database');
  $customers->get('/new')                                    ->to('#add')       ->name('customer_database_new');
  $customers->get('/:databasename/edit')                     ->to('#edit')      ->name('customer_database_edit');
  $customers->get('/:databasename')                          ->to('#get')       ->name('customer_database_get');
  $customers->get('/')                                       ->to('#index')     ->name('customer_databases');

  # API routes handled by OpenAPI

  $app->helper(database => sub ($self) {
    state $model = do {
      my $opts = { config => $self->config->{manager}->{database} // {} };
      $opts->{pg}    = $self->pg    if $app->renderer->helpers->{pg};
      $opts->{mysql} = $self->mysql if $app->renderer->helpers->{mysql};
      Samizdat::Model::Database->new($opts);
    };
    return $model;
  });
}

1;

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for Database API
paths:
  /databases:
    get:
      operationId: Database.index
      x-mojo-to: Database#index
      summary: List all databases
      tags: [Database]
      parameters:
        - name: customerid
          in: query
          schema:
            type: integer
      responses:
        '200':
          description: List of databases
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Database_ListResponse'
    post:
      operationId: Database.create
      x-mojo-to: Database#create
      summary: Create database
      tags: [Database]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Database_Input'
      responses:
        '201':
          description: Database created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Database_Database'

  /databases/new:
    get:
      operationId: Database.new
      x-mojo-to: Database#add
      summary: New database form
      tags: [Database]
      responses:
        '200':
          description: Form data for new database
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Database_FormData'

  /databases/types:
    get:
      operationId: Database.types
      x-mojo-to: Database#types
      summary: List database types
      tags: [Database]
      responses:
        '200':
          description: List of database types
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Database_TypesResponse'

  /databases/{databaseid}/edit:
    get:
      operationId: Database.edit
      x-mojo-to: Database#edit
      summary: Edit database form
      tags: [Database]
      parameters:
        - name: databaseid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Form data for editing database
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Database_FormData'

  /databases/{databaseid}:
    get:
      operationId: Database.get
      x-mojo-to: Database#get
      summary: Get database details
      tags: [Database]
      parameters:
        - name: databaseid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Database details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Database_Database'
    put:
      operationId: Database.update
      x-mojo-to: Database#update
      summary: Update database
      tags: [Database]
      parameters:
        - name: databaseid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Database_Input'
      responses:
        '200':
          description: Database updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Database_Database'
    delete:
      operationId: Database.delete
      x-mojo-to: Database#delete
      summary: Delete database
      tags: [Database]
      parameters:
        - name: databaseid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Database deleted

  /customers/{customerid}/databases:
    get:
      operationId: Database.customer.index
      x-mojo-to: Database#index
      summary: List customer databases
      tags: [Database]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: List of customer databases
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Database_ListResponse'

  /customers/{customerid}/databases/new:
    get:
      operationId: Database.customer.new
      x-mojo-to: Database#add
      summary: New database form for customer
      tags: [Database]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Form data for new database
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Database_FormData'

  /customers/{customerid}/databases/{databasename}/edit:
    get:
      operationId: Database.customer.edit
      x-mojo-to: Database#edit
      summary: Edit database form for customer
      tags: [Database]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
        - name: databasename
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Form data for editing database
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Database_FormData'

  /customers/{customerid}/databases/{databasename}:
    get:
      operationId: Database.customer.get
      x-mojo-to: Database#get
      summary: Get customer database details
      tags: [Database]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
        - name: databasename
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Database details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Database_Database'

components:
  schemas:
    Database_Database:
      type: object
      properties:
        databaseid:
          type: integer
        customerid:
          type: integer
        databasetypeid:
          type: integer
        databasetypename:
          type: string
        databasename:
          type: string
        username:
          type: string
        db_usage:
          type: integer
        created:
          type: string
          format: date-time
        creator:
          type: string
        updated:
          type: string
          format: date-time
        updater:
          type: string
    Database_Input:
      type: object
      properties:
        customerid:
          type: integer
        databasetypeid:
          type: integer
        databasename:
          type: string
        username:
          type: string
        password:
          type: string
      required:
        - databasename
        - customerid
    Database_ListResponse:
      type: object
      properties:
        databases:
          type: array
          items:
            $ref: '#/components/schemas/Database_Database'
    Database_TypesResponse:
      type: object
      properties:
        types:
          type: array
          items:
            type: object
            properties:
              databasetypeid:
                type: integer
              databasetypename:
                type: string
    Database_FormData:
      type: object
      properties:
        database:
          $ref: '#/components/schemas/Database_Database'
        types:
          type: array
          items:
            type: object
            properties:
              databasetypeid:
                type: integer
              databasetypename:
                type: string
        customerid:
          type: integer
