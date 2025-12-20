package Samizdat::Plugin::Customer;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Customer;
use Mojo::Loader qw(data_section);

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  # Store OpenAPI fragment (parsed centrally in _load_openapi)
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Customer} = $openapi_yaml if $openapi_yaml;

  # Manager routes (HTML pages only - GET)
  my $manager = $r->manager('customers')->to(controller => 'Customer');
  $manager->get('vatno/:vatno')           ->to('Customer#vatno')                        ->name('customer_vatno');
  $manager->get('sync')                   ->to('#sync')                                 ->name('customer_sync');
  $manager->get('first')                  ->to('Customer#first')                        ->name('customer_first');
  $manager->get('newest')                 ->to('Customer#newest')                       ->name('customer_newest');
  $manager->get('new')                    ->to('#edit', customerid => 0)                ->name('customer_new');
  $manager->get('/:customerid/prev')      ->to('#prev')                                 ->name('customer_prev');
  $manager->get('/:customerid/next')      ->to('#next')                                 ->name('customer_next');
  $manager->get('/:customerid')           ->to('#edit')                                 ->name('customer_edit');
  $manager->get('/')                      ->to('#index')                                ->name('customer_index');

  # API routes are defined in OpenAPI spec (__DATA__ section)

  $app->helper(customer => sub {
    state $model = Samizdat::Model::Customer->new({app => shift});
    return $model;
  });

}

=head1 NAME

Samizdat::Plugin::Customer - Customer management plugin

=head1 DESCRIPTION

This plugin provides customer management functionality including listing,
creating, editing, and navigating between customers.

=head1 NGINX CONFIGURATION

Customer routes use dynamic C<:customerid> parameters. The controller sets
C<docpath> to ensure all customer IDs share the same cached template.

=head2 Regex Routes

    # Customer edit - any customerid uses same cached template
    location ~ ^/manager/customers/\d+$ {
        root /path/to/public;
        try_files /manager/customers/customer/edit/index.html @backend;
    }

    # Customer billing tab
    location ~ ^/manager/customers/\d+/billing$ {
        root /path/to/public;
        try_files /manager/customers/customer/billing/index.html @backend;
    }

    # Customer products tab
    location ~ ^/manager/customers/\d+/products$ {
        root /path/to/public;
        try_files /manager/customers/customer/products/index.html @backend;
    }

    # Navigation routes - always proxy (returns redirect)
    location ~ ^/manager/customers/\d+/(prev|next)$ {
        proxy_pass http://127.0.0.1:3000;
    }

    location @backend {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

=head1 SEE ALSO

L<Samizdat::Controller::Customer>, L<Samizdat::Model::Customer>

=cut

1;

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for Customer API
paths:
  /customers:
    get:
      operationId: Customer.index
      x-mojo-to: Customer#index
      summary: List all customers
      tags: [Customers]
      parameters:
        - name: searchterm
          in: query
          schema:
            type: string
      responses:
        '200':
          description: List of customers
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Customer_ListResponse'
    post:
      operationId: Customer.create
      x-mojo-to: Customer#create
      summary: Create new customer
      tags: [Customers]
      requestBody:
        content:
          application/x-www-form-urlencoded:
            schema:
              $ref: '#/components/schemas/Customer_Input'
      responses:
        '200':
          description: Created customer
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Customer_Customer'

  /customers/vatno/{vatno}:
    get:
      operationId: Customer.vatno
      x-mojo-to: Customer#vatno
      summary: Lookup customer by VAT number
      tags: [Customers]
      parameters:
        - name: vatno
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Customer data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Customer_Customer'

  /customers/sync:
    post:
      operationId: Customer.sync
      x-mojo-to: Customer#sync
      summary: Sync customers with external system
      tags: [Customers]
      responses:
        '200':
          description: Sync result
          content:
            application/json:
              schema:
                type: object

  /customers/first:
    get:
      operationId: Customer.first
      x-mojo-to: Customer#first
      summary: Get first customer
      tags: [Customers]
      responses:
        '200':
          description: Customer data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Customer_Customer'

  /customers/newest:
    get:
      operationId: Customer.newest
      x-mojo-to: Customer#newest
      summary: Get newest customer
      tags: [Customers]
      responses:
        '200':
          description: Customer data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Customer_Customer'

  /customers/{customerid}:
    get:
      operationId: Customer.get
      x-mojo-to: Customer#edit
      summary: Get customer by ID
      tags: [Customers]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Customer data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Customer_Customer'
    put:
      operationId: Customer.update
      x-mojo-to: Customer#update
      summary: Update customer
      tags: [Customers]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/x-www-form-urlencoded:
            schema:
              $ref: '#/components/schemas/Customer_Input'
      responses:
        '200':
          description: Updated customer
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Customer_Customer'

  /customers/{customerid}/prev:
    get:
      operationId: Customer.prev
      x-mojo-to: Customer#prev
      summary: Navigate to previous customer
      tags: [Customers]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Previous customer data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Customer_Customer'

  /customers/{customerid}/next:
    get:
      operationId: Customer.next
      x-mojo-to: Customer#next
      summary: Navigate to next customer
      tags: [Customers]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Next customer data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Customer_Customer'

components:
  schemas:
    Customer_Customer:
      type: object
      properties:
        customerid:
          type: integer
        company:
          type: string
        firstname:
          type: string
        lastname:
          type: string
        email:
          type: string
        billingemail:
          type: string
        billingaddress:
          type: string
        billingzip:
          type: string
        billingcity:
          type: string
        billingcountry:
          type: string
        billinglang:
          type: string
        currency:
          type: string
        vat:
          type: number
        vatno:
          type: string
        invoicetype:
          type: string
          enum: [email, snailmail]
    Customer_Input:
      type: object
      properties:
        company:
          type: string
        firstname:
          type: string
        lastname:
          type: string
        email:
          type: string
        billingemail:
          type: string
        billingaddress:
          type: string
        billingzip:
          type: string
        billingcity:
          type: string
        billingcountry:
          type: string
        billinglang:
          type: string
        currency:
          type: string
        vat:
          type: number
        vatno:
          type: string
    Customer_ListResponse:
      type: object
      properties:
        customers:
          type: array
          items:
            $ref: '#/components/schemas/Customer_Customer'
