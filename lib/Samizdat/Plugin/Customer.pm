package Samizdat::Plugin::Customer;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Customer;
use Mojo::Loader qw(data_section);
use YAML::XS qw(Load);
use JSON::PP ();

# Deep clone and convert YAML booleans to JSON booleans for OpenAPI compatibility
sub _fix_booleans {
  my ($data) = @_;
  return $data unless ref $data;

  if (ref $data eq 'HASH') {
    my %new;
    for my $key (keys %$data) {
      if ($key eq 'required' && defined $data->{$key} && !ref $data->{$key}) {
        $new{$key} = $data->{$key} ? JSON::PP::true : JSON::PP::false;
      } else {
        $new{$key} = _fix_booleans($data->{$key});
      }
    }
    return \%new;
  } elsif (ref $data eq 'ARRAY') {
    return [ map { _fix_booleans($_) } @$data ];
  }
  return $data;
}


sub register ($self, $app, $conf) {
  my $r = $app->routes;

  # Load OpenAPI fragment from __DATA__ section and store in config
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  if ($openapi_yaml) {
    $app->config->{openapi_fragments}{Customer} = _fix_booleans(Load($openapi_yaml));
  }

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

1;

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for Customer API
paths:
  /customers/:
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
