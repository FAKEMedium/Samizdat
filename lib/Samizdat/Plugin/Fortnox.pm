package Samizdat::Plugin::Fortnox;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Cache;
use Samizdat::Model::Fortnox;
use Mojo::Loader qw(data_section);

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  # Store OpenAPI fragment (parsed centrally in _load_openapi)
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Fortnox} = $openapi_yaml if $openapi_yaml;

  # For service accounts, use a dedicated Fortnox session cookie
  my $fortnox_config = $app->config->{manager}->{fortnox} // {};
  my $is_service = ($fortnox_config->{account_type} // '') eq 'service';
  if ($is_service) {
    $app->sessions->cookie_name('fortnox');
    $app->sessions->cookie_path('/');
    $app->sessions->default_expiration(7200);  # 2 hours
  }

  # Manager routes (HTML pages only - GET)
  my $manager = $r->manager('fortnox')->to(controller => 'Fortnox');
  $manager->get('/customers/:customerid')   ->to('#customers')    ->name('fortnox_customer');
  $manager->get('/customers')               ->to('#customers')    ->name('fortnox_customers');
  $manager->get('/invoices/:invoiceid/:to') ->to('#invoicenav')   ->name('fortnox_invoice_nav');
  $manager->get('/invoices/:invoiceid')     ->to('#invoices')     ->name('fortnox_invoice');
  $manager->get('/invoices')                ->to('#invoices')     ->name('fortnox_invoices');
  $manager->get('/payments/:number')        ->to('#payments')     ->name('fortnox_payment');
  $manager->get('/payments')                ->to('#payments')     ->name('fortnox_payments');
  $manager->get('/')                        ->to('#manager')      ->name('fortnox_manager');

  # API routes are defined in OpenAPI spec (__DATA__ section)

  # Integration routes (for Fortnox marketplace etc.)
  my $fortnox = $r->home('fortnox')->to(controller => 'Fortnox');
  $fortnox->any('/auth')                    ->to('#auth')         ->name('fortnox_auth');  # OAuth callback (GET/POST)
  $fortnox->get('/logout')                  ->to('#logout')       ->name('fortnox_logout');
  $fortnox->get('/start')                   ->to('#start')        ->name('fortnox_start');
  $fortnox->get('/activate')                ->to('#activate')     ->name('fortnox_activate');
  $fortnox->get('/')                        ->to('#index')        ->name('fortnox_index');

  # Helper for accessing the Fortnox API model
  # Always use global cache - OAuth tokens are app-level credentials
  my $global_cache;
  $app->helper(fortnox => sub ($c) {
    $global_cache //= Samizdat::Model::Cache->new({
      redis  => $c->redis,
      config => $app->config->{manager}->{cache},
      # No session = global cache key (fortnox:cache, not fortnox:cache:session:xxx)
    });
    state $model = Samizdat::Model::Fortnox->new({
      config => $fortnox_config,
      cache  => $global_cache,
    });
    return $model;
  });
}

=head1 NAME

Samizdat::Plugin::Fortnox - Fortnox accounting integration plugin

=head1 DESCRIPTION

This plugin provides integration with Fortnox accounting software including
customer management, invoice handling, and payment tracking.

=head1 ROUTES

=head2 Manager Routes (HTML)

=over 4

=item * GET /manager/fortnox - Fortnox dashboard

=item * GET /manager/fortnox/customers - Customer list page

=item * GET /manager/fortnox/customers/:customerid - Customer details page

=item * GET /manager/fortnox/invoices - Invoice list page

=item * GET /manager/fortnox/invoices/:invoiceid - Invoice details page

=item * GET /manager/fortnox/invoices/:invoiceid/:to - Invoice navigation

=item * GET /manager/fortnox/payments - Payment list page

=item * GET /manager/fortnox/payments/:number - Payment details page

=back

=head2 API Routes (OpenAPI)

=over 4

=item * GET /api/fortnox/customers - List customers

=item * GET /api/fortnox/customers/:customerid - Get customer details

=item * POST /api/fortnox/customers - Create customer

=item * PUT /api/fortnox/customers/:customerid - Update customer

=item * GET /api/fortnox/invoices - List invoices

=item * GET /api/fortnox/invoices/:invoiceid - Get invoice details

=item * POST /api/fortnox/invoices - Create invoice

=item * GET /api/fortnox/payments - List payments

=item * GET /api/fortnox/payments/:number - Get payment details

=back

=head2 Public Routes (OAuth/Integration)

=over 4

=item * /fortnox/auth - OAuth authentication

=item * /fortnox/logout - Logout

=item * /fortnox/start - Start integration

=item * /fortnox/activate - Activate integration

=back

=head1 NGINX CONFIGURATION

Fortnox routes use dynamic parameters for customers, invoices, and payments.
The controller sets C<docpath> to ensure shared cached templates.

=head2 Regex Routes

    # Fortnox customer details
    location ~ ^/manager/fortnox/customers/[^/]+$ {
        root /path/to/public;
        try_files /manager/fortnox/customers/single/index.html @backend;
    }

    # Fortnox invoice details
    location ~ ^/manager/fortnox/invoices/\d+$ {
        root /path/to/public;
        try_files /manager/fortnox/invoices/single/index.html @backend;
    }

    # Invoice navigation - always proxy (returns redirect/data)
    location ~ ^/manager/fortnox/invoices/\d+/(prev|next)$ {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
    }

    # Fortnox payment details
    location ~ ^/manager/fortnox/payments/\d+$ {
        root /path/to/public;
        try_files /manager/fortnox/payments/single/index.html @backend;
    }

    # OAuth routes - always proxy (stateful)
    location /fortnox/auth {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location @backend {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

=head1 SEE ALSO

L<Samizdat::Controller::Fortnox>, L<Samizdat::Model::Fortnox>

=cut

1;

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for Fortnox API
paths:
  /fortnox/customers:
    get:
      operationId: Fortnox.customers.index
      x-mojo-to: Fortnox#customers
      summary: List customers
      tags: [Fortnox]
      parameters:
        - name: page
          in: query
          schema:
            type: integer
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            default: 100
      responses:
        '200':
          description: List of customers
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Fortnox_CustomerListResponse'
    post:
      operationId: Fortnox.customers.create
      x-mojo-to: Fortnox#customers
      summary: Create customer
      tags: [Fortnox]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Fortnox_CustomerInput'
      responses:
        '200':
          description: Customer created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Fortnox_Result'

  /fortnox/customers/{customerid}:
    get:
      operationId: Fortnox.customers.get
      x-mojo-to: Fortnox#customers
      summary: Get customer details
      tags: [Fortnox]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Customer details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Fortnox_CustomerResponse'
    put:
      operationId: Fortnox.customers.update
      x-mojo-to: Fortnox#customers
      summary: Update customer
      tags: [Fortnox]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: string
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Fortnox_CustomerInput'
      responses:
        '200':
          description: Customer updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Fortnox_Result'

  /fortnox/invoices:
    get:
      operationId: Fortnox.invoices.index
      x-mojo-to: Fortnox#invoices
      summary: List invoices
      tags: [Fortnox]
      parameters:
        - name: page
          in: query
          schema:
            type: integer
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            default: 25
      responses:
        '200':
          description: List of invoices
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Fortnox_InvoiceListResponse'
    post:
      operationId: Fortnox.invoices.create
      x-mojo-to: Fortnox#postinvoice
      summary: Create invoice
      tags: [Fortnox]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Fortnox_InvoiceInput'
      responses:
        '200':
          description: Invoice created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Fortnox_Result'

  /fortnox/invoices/{invoiceid}:
    get:
      operationId: Fortnox.invoices.get
      x-mojo-to: Fortnox#invoices
      summary: Get invoice details
      tags: [Fortnox]
      parameters:
        - name: invoiceid
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Invoice details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Fortnox_InvoiceResponse'

  /fortnox/invoices/{invoiceid}/{direction}:
    get:
      operationId: Fortnox.invoices.navigate
      x-mojo-to: Fortnox#invoicenav
      summary: Navigate to previous/next invoice
      tags: [Fortnox]
      parameters:
        - name: invoiceid
          in: path
          required: true
          schema:
            type: string
        - name: direction
          in: path
          required: true
          schema:
            type: string
            enum: [prev, next]
      responses:
        '302':
          description: Redirect to invoice

  /fortnox/payments:
    get:
      operationId: Fortnox.payments.index
      x-mojo-to: Fortnox#payments
      summary: List payments
      tags: [Fortnox]
      parameters:
        - name: page
          in: query
          schema:
            type: integer
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            default: 25
      responses:
        '200':
          description: List of payments
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Fortnox_PaymentListResponse'

  /fortnox/payments/{number}:
    get:
      operationId: Fortnox.payments.get
      x-mojo-to: Fortnox#payments
      summary: Get payment details
      tags: [Fortnox]
      parameters:
        - name: number
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Payment details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Fortnox_PaymentResponse'

components:
  schemas:
    Fortnox_Customer:
      type: object
      properties:
        CustomerNumber:
          type: string
        Name:
          type: string
        OrganisationNumber:
          type: string
        Email:
          type: string
        Phone:
          type: string
        Address1:
          type: string
        City:
          type: string
        ZipCode:
          type: string
        Country:
          type: string
        Active:
          type: boolean
    Fortnox_CustomerInput:
      type: object
      properties:
        Name:
          type: string
        OrganisationNumber:
          type: string
        Email:
          type: string
        Phone:
          type: string
        Address1:
          type: string
        City:
          type: string
        ZipCode:
          type: string
    Fortnox_CustomerListResponse:
      type: object
      properties:
        success:
          type: boolean
        fortnox:
          type: object
          properties:
            customers:
              type: array
              items:
                $ref: '#/components/schemas/Fortnox_Customer'
    Fortnox_CustomerResponse:
      type: object
      properties:
        success:
          type: boolean
        fortnox:
          type: object
          properties:
            customer:
              $ref: '#/components/schemas/Fortnox_Customer'
    Fortnox_Invoice:
      type: object
      properties:
        DocumentNumber:
          type: string
        CustomerNumber:
          type: string
        CustomerName:
          type: string
        InvoiceDate:
          type: string
        DueDate:
          type: string
        Total:
          type: number
        Balance:
          type: number
        Currency:
          type: string
    Fortnox_InvoiceInput:
      type: object
      properties:
        CustomerNumber:
          type: string
        InvoiceRows:
          type: array
          items:
            type: object
            properties:
              ArticleNumber:
                type: string
              Description:
                type: string
              DeliveredQuantity:
                type: number
              Price:
                type: number
    Fortnox_InvoiceListResponse:
      type: object
      properties:
        success:
          type: boolean
        fortnox:
          type: object
          properties:
            invoice:
              type: object
              properties:
                Invoices:
                  type: array
                  items:
                    $ref: '#/components/schemas/Fortnox_Invoice'
            perpage:
              type: integer
    Fortnox_InvoiceResponse:
      type: object
      properties:
        success:
          type: boolean
        fortnox:
          type: object
          properties:
            invoice:
              $ref: '#/components/schemas/Fortnox_Invoice'
    Fortnox_Payment:
      type: object
      properties:
        Number:
          type: string
        InvoiceNumber:
          type: string
        CustomerName:
          type: string
        PaymentDate:
          type: string
        Amount:
          type: number
    Fortnox_PaymentListResponse:
      type: object
      properties:
        success:
          type: boolean
        fortnox:
          type: object
          properties:
            payment:
              type: object
              properties:
                InvoicePayments:
                  type: array
                  items:
                    $ref: '#/components/schemas/Fortnox_Payment'
            perpage:
              type: integer
    Fortnox_PaymentResponse:
      type: object
      properties:
        success:
          type: boolean
        fortnox:
          type: object
          properties:
            payment:
              $ref: '#/components/schemas/Fortnox_Payment'
    Fortnox_Result:
      type: object
      properties:
        success:
          type: boolean
        error:
          type: string
        message:
          type: string
