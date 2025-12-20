package Samizdat::Plugin::Email;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Email;
use Mojo::Loader qw(data_section);

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  # Store OpenAPI fragment (parsed centrally in _load_openapi)
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Email} = $openapi_yaml if $openapi_yaml;

  # Email management routes (HTML pages only - GET)
  my $manager = $r->manager('email')->to(controller => 'Email');

  # Domain routes
  $manager->get('/domains/:domain')                          ->to('#domain')                    ->name('email_domain');
  $manager->get('/domains')                                  ->to('#index', type => 'domains')  ->name('email_domains');

  # Mailbox routes (nested under domains)
  $manager->get('/domains/:domain/mailboxes/:username')      ->to('#mailbox')                   ->name('email_mailbox');
  $manager->get('/domains/:domain/mailboxes')                ->to('#index', type => 'mailboxes')->name('email_domain_mailboxes');

  # Alias routes
  $manager->get('/aliases/:address')                         ->to('#alias')                     ->name('email_alias');
  $manager->get('/aliases')                                  ->to('#index', type => 'aliases')  ->name('email_aliases');

  # Quota routes
  $manager->get('/quotas/:username')                         ->to('#quota')                     ->name('email_quota');
  $manager->get('/quotas')                                   ->to('#index', type => 'quotas')   ->name('email_quotas');

  $manager->get('/')                                         ->to('#index')                     ->name('email_index');

  # Customer-specific email routes (HTML pages only - GET)
  my $customer = $r->manager('customers/:customerid/email')->to(controller => 'Email');
  $customer->get('/')                                        ->to('#index')                     ->name('email_customer_index');
  $customer->get('/domains')                                 ->to('#index', type => 'domains')  ->name('email_customer_domains');
  $customer->get('/mailboxes')                               ->to('#index', type => 'mailboxes')->name('email_customer_mailboxes');
  $customer->get('/aliases')                                 ->to('#index', type => 'aliases')  ->name('email_customer_aliases');

  # API routes are defined in OpenAPI spec (__DATA__ section)

  # Helper to access email model
  $app->helper(email => sub ($self) {
    state $model = Samizdat::Model::Email->new({
      config => $self->config->{manager}->{email} || {},
      pg     => $self->pg,
      mysql  => $self->mysql,
    });
    return $model;
  });
}

=head1 NAME

Samizdat::Plugin::Email - Email management plugin for domains, mailboxes, aliases

=head1 DESCRIPTION

This plugin provides email management functionality including domain management,
mailbox creation, alias configuration, and quota management.

=head1 ROUTES

=head2 Manager Routes (HTML)

=over 4

=item * GET /manager/email - Email management dashboard

=item * GET /manager/email/domains - List email domains

=item * GET /manager/email/domains/:domain - Domain details

=item * GET /manager/email/domains/:domain/mailboxes - List mailboxes

=item * GET /manager/email/domains/:domain/mailboxes/:username - Mailbox details

=item * GET /manager/email/aliases - List aliases

=item * GET /manager/email/aliases/:address - Alias details

=item * GET /manager/email/quotas - List quotas

=item * GET /manager/email/quotas/:username - Quota details

=back

=head2 API Routes (OpenAPI)

=over 4

=item * POST/PUT/DELETE /api/email/domains - Domain CRUD

=item * POST/PUT/DELETE /api/email/domains/:domain/mailboxes - Mailbox CRUD

=item * POST/PUT/DELETE /api/email/aliases - Alias CRUD

=item * PUT /api/email/quotas/:username - Update quota

=back

=head1 NGINX CONFIGURATION

Email routes use dynamic parameters for domains, mailboxes, aliases, and quotas.
Domain names contain dots, so relaxed placeholder matching is used (C<#>).
The controller sets C<docpath> to ensure shared cached templates.

=head2 Regex Routes

    # Email domain details - matches domain names with dots
    location ~ ^/manager/email/domains/[^/]+\.[^/]+$ {
        root /path/to/public;
        try_files /manager/email/domains/domain/index.html @backend;
    }

    # Domain mailboxes list
    location ~ ^/manager/email/domains/[^/]+\.[^/]+/mailboxes/?$ {
        root /path/to/public;
        try_files /manager/email/domains/mailboxes/index.html @backend;
    }

    # Mailbox details (nested under domain)
    location ~ ^/manager/email/domains/[^/]+\.[^/]+/mailboxes/[^/]+$ {
        root /path/to/public;
        try_files /manager/email/mailbox/index.html @backend;
    }

    # Alias details (email address format)
    location ~ ^/manager/email/aliases/[^/]+$ {
        root /path/to/public;
        try_files /manager/email/alias/index.html @backend;
    }

    # Quota details
    location ~ ^/manager/email/quotas/[^/]+$ {
        root /path/to/public;
        try_files /manager/email/quota/index.html @backend;
    }

    location @backend {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

=head1 SEE ALSO

L<Samizdat::Controller::Email>, L<Samizdat::Model::Email>

=cut

1;

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for Email API
paths:
  /email/domains:
    get:
      operationId: Email.domains.index
      x-mojo-to: Email#index
      x-mojo-params:
        type: domains
      summary: List email domains
      tags: [Email]
      responses:
        '200':
          description: List of domains
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_DomainListResponse'
    post:
      operationId: Email.domains.create
      x-mojo-to: Email#domain
      summary: Create email domain
      tags: [Email]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Email_DomainInput'
      responses:
        '200':
          description: Domain created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Result'

  /email/domains/{domain}:
    get:
      operationId: Email.domains.get
      x-mojo-to: Email#domain
      summary: Get domain details
      tags: [Email]
      parameters:
        - name: domain
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      responses:
        '200':
          description: Domain details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Domain'
    put:
      operationId: Email.domains.update
      x-mojo-to: Email#domain
      summary: Update domain
      tags: [Email]
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
              $ref: '#/components/schemas/Email_DomainInput'
      responses:
        '200':
          description: Domain updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Result'
    delete:
      operationId: Email.domains.delete
      x-mojo-to: Email#domain
      summary: Delete domain
      tags: [Email]
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
                $ref: '#/components/schemas/Email_Result'

  /email/domains/{domain}/mailboxes:
    get:
      operationId: Email.mailboxes.index
      x-mojo-to: Email#index
      x-mojo-params:
        type: mailboxes
      summary: List mailboxes for domain
      tags: [Email]
      parameters:
        - name: domain
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      responses:
        '200':
          description: List of mailboxes
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_MailboxListResponse'
    post:
      operationId: Email.mailboxes.create
      x-mojo-to: Email#mailbox
      summary: Create mailbox
      tags: [Email]
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
              $ref: '#/components/schemas/Email_MailboxInput'
      responses:
        '200':
          description: Mailbox created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Result'

  /email/domains/{domain}/mailboxes/{username}:
    get:
      operationId: Email.mailboxes.get
      x-mojo-to: Email#mailbox
      summary: Get mailbox details
      tags: [Email]
      parameters:
        - name: domain
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
        - name: username
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Mailbox details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Mailbox'
    put:
      operationId: Email.mailboxes.update
      x-mojo-to: Email#mailbox
      summary: Update mailbox
      tags: [Email]
      parameters:
        - name: domain
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
        - name: username
          in: path
          required: true
          schema:
            type: string
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Email_MailboxInput'
      responses:
        '200':
          description: Mailbox updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Result'
    delete:
      operationId: Email.mailboxes.delete
      x-mojo-to: Email#mailbox
      summary: Delete mailbox
      tags: [Email]
      parameters:
        - name: domain
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
        - name: username
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Mailbox deleted
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Result'

  /email/aliases:
    get:
      operationId: Email.aliases.index
      x-mojo-to: Email#index
      x-mojo-params:
        type: aliases
      summary: List email aliases
      tags: [Email]
      responses:
        '200':
          description: List of aliases
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_AliasListResponse'
    post:
      operationId: Email.aliases.create
      x-mojo-to: Email#alias
      summary: Create alias
      tags: [Email]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Email_AliasInput'
      responses:
        '200':
          description: Alias created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Result'

  /email/aliases/{address}:
    get:
      operationId: Email.aliases.get
      x-mojo-to: Email#alias
      summary: Get alias details
      tags: [Email]
      parameters:
        - name: address
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Alias details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Alias'
    put:
      operationId: Email.aliases.update
      x-mojo-to: Email#alias
      summary: Update alias
      tags: [Email]
      parameters:
        - name: address
          in: path
          required: true
          schema:
            type: string
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Email_AliasInput'
      responses:
        '200':
          description: Alias updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Result'
    delete:
      operationId: Email.aliases.delete
      x-mojo-to: Email#alias
      summary: Delete alias
      tags: [Email]
      parameters:
        - name: address
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Alias deleted
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Result'

  /email/quotas:
    get:
      operationId: Email.quotas.index
      x-mojo-to: Email#index
      x-mojo-params:
        type: quotas
      summary: List email quotas
      tags: [Email]
      responses:
        '200':
          description: List of quotas
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_QuotaListResponse'

  /email/quotas/{username}:
    get:
      operationId: Email.quotas.get
      x-mojo-to: Email#quota
      summary: Get quota details
      tags: [Email]
      parameters:
        - name: username
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Quota details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Quota'
    put:
      operationId: Email.quotas.update
      x-mojo-to: Email#quota
      summary: Update quota
      tags: [Email]
      parameters:
        - name: username
          in: path
          required: true
          schema:
            type: string
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Email_QuotaInput'
      responses:
        '200':
          description: Quota updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Result'

components:
  schemas:
    Email_Domain:
      type: object
      properties:
        domain:
          type: string
        description:
          type: string
        active:
          type: boolean
        mailbox_count:
          type: integer
        alias_count:
          type: integer
    Email_DomainInput:
      type: object
      required:
        - domain
      properties:
        domain:
          type: string
        description:
          type: string
        active:
          type: boolean
    Email_DomainListResponse:
      type: object
      properties:
        success:
          type: boolean
        domains:
          type: array
          items:
            $ref: '#/components/schemas/Email_Domain'
    Email_Mailbox:
      type: object
      properties:
        username:
          type: string
        domain:
          type: string
        name:
          type: string
        quota:
          type: integer
        active:
          type: boolean
    Email_MailboxInput:
      type: object
      required:
        - username
      properties:
        username:
          type: string
        password:
          type: string
        name:
          type: string
        quota:
          type: integer
        active:
          type: boolean
    Email_MailboxListResponse:
      type: object
      properties:
        success:
          type: boolean
        mailboxes:
          type: array
          items:
            $ref: '#/components/schemas/Email_Mailbox'
    Email_Alias:
      type: object
      properties:
        address:
          type: string
        goto:
          type: string
        active:
          type: boolean
    Email_AliasInput:
      type: object
      required:
        - address
        - goto
      properties:
        address:
          type: string
        goto:
          type: string
        active:
          type: boolean
    Email_AliasListResponse:
      type: object
      properties:
        success:
          type: boolean
        aliases:
          type: array
          items:
            $ref: '#/components/schemas/Email_Alias'
    Email_Quota:
      type: object
      properties:
        username:
          type: string
        quota:
          type: integer
        used:
          type: integer
    Email_QuotaInput:
      type: object
      properties:
        quota:
          type: integer
    Email_QuotaListResponse:
      type: object
      properties:
        success:
          type: boolean
        quotas:
          type: array
          items:
            $ref: '#/components/schemas/Email_Quota'
    Email_Result:
      type: object
      properties:
        success:
          type: boolean
        error:
          type: string
        message:
          type: string