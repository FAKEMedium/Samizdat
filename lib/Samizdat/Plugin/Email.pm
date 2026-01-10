package Samizdat::Plugin::Email;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Email;
use Mojo::Loader qw(data_section);

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  # Store OpenAPI fragment (parsed centrally in _load_openapi)
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Email} = $openapi_yaml if $openapi_yaml;

  # Email management routes (HTML pages)
  # Route order: most specific first
  my $manager = $r->manager('email')->to(controller => 'Email');

  # Admin routes (modal) - under /admins
  $manager->get('/admins/admin/#username')                   ->to('#admin_page')                ->name('email_admin');
  $manager->get('/admins/admin')                             ->to('#admin_page')                ->name('email_admin_new');

  # Domain routes (full page)
  $manager->get('/domain')                                   ->to('#domain_page')               ->name('email_domain_new');

  # List pages (before /#domain to avoid capture)
  $manager->get('/admins')                                   ->to('#admins_page')               ->name('email_admins');
  $manager->get('/mailboxes')                                ->to('#mailboxes_page')            ->name('email_mailboxes');

  # Domain-specific routes (most specific first)
  $manager->get('/#domain/admins/#admin')                    ->to('#domain_admin')              ->name('email_domain_admin');
  $manager->get('/#domain/admins')                           ->to('#domain_admins')             ->name('email_domain_admins');
  $manager->get('/#domain/alias/#address')                   ->to('#alias_page')                ->name('email_alias');
  $manager->get('/#domain/alias')                            ->to('#alias_page')                ->name('email_alias_new');
  $manager->get('/#domain/mailbox/#username')                ->to('#mailbox_page')              ->name('email_mailbox');
  $manager->get('/#domain/mailbox')                          ->to('#mailbox_page')              ->name('email_mailbox_new');
  $manager->get('/#domain')                                  ->to('#domain_page')               ->name('email_domain');

  # Main index
  $manager->get('/')                                         ->to('#index')                     ->name('email_index');

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
      x-mojo-to: Email#domains_index
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

  /email/domains/available-targets:
    get:
      operationId: Email.domains.available_targets
      x-mojo-to: Email#available_targets
      summary: Get domains available as alias targets
      tags: [Email]
      parameters:
        - name: customerid
          in: query
          required: true
          schema:
            type: integer
          description: Customer ID to filter domains
      responses:
        '200':
          description: List of available target domains
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_DomainListResponse'

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

  /email/mailboxes:
    get:
      operationId: Email.mailboxes.all
      x-mojo-to: Email#mailboxes_index
      summary: List all mailboxes
      tags: [Email]
      responses:
        '200':
          description: List of mailboxes
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_MailboxListResponse'

  /email/domains/{domain}/mailboxes:
    get:
      operationId: Email.mailboxes.index
      x-mojo-to: Email#mailboxes_index
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
          x-mojo-placeholder: "#"
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
          x-mojo-placeholder: "#"
          schema:
            type: string
      responses:
        '200':
          description: Mailbox deleted
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Result'

  /email/domains/{domain}/aliases:
    get:
      operationId: Email.aliases.index
      x-mojo-to: Email#aliases_index
      summary: List email aliases for domain
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
              $ref: '#/components/schemas/Email_AliasInput'
      responses:
        '200':
          description: Alias created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Result'

  /email/domains/{domain}/aliases/{address}:
    get:
      operationId: Email.aliases.get
      x-mojo-to: Email#alias
      summary: Get alias details
      tags: [Email]
      parameters:
        - name: domain
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
        - name: address
          in: path
          required: true
          x-mojo-placeholder: "#"
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
        - name: domain
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
        - name: address
          in: path
          required: true
          x-mojo-placeholder: "#"
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
        - name: domain
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
        - name: address
          in: path
          required: true
          x-mojo-placeholder: "#"
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
      x-mojo-to: Email#quotas_index
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
          x-mojo-placeholder: "#"
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
          x-mojo-placeholder: "#"
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

  /email/admins:
    get:
      operationId: Email.admins.index
      x-mojo-to: Email#admins_index
      summary: List email admins
      tags: [Email]
      responses:
        '200':
          description: List of admins
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_AdminListResponse'
    post:
      operationId: Email.admins.create
      x-mojo-to: Email#admin
      summary: Create admin
      tags: [Email]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Email_AdminInput'
      responses:
        '200':
          description: Admin created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Result'

  /email/admins/{username}:
    get:
      operationId: Email.admins.get
      x-mojo-to: Email#admin
      summary: Get admin details
      tags: [Email]
      parameters:
        - name: username
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      responses:
        '200':
          description: Admin details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Admin'
    put:
      operationId: Email.admins.update
      x-mojo-to: Email#admin
      summary: Update admin
      tags: [Email]
      parameters:
        - name: username
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Email_AdminInput'
      responses:
        '200':
          description: Admin updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Result'
    delete:
      operationId: Email.admins.delete
      x-mojo-to: Email#admin
      summary: Delete admin
      tags: [Email]
      parameters:
        - name: username
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      responses:
        '200':
          description: Admin deleted
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
    Email_Admin:
      type: object
      properties:
        username:
          type: string
        phone:
          type: string
        email_other:
          type: string
        active:
          type: boolean
        superadmin:
          type: boolean
        created:
          type: string
        modified:
          type: string
    Email_AdminInput:
      type: object
      required:
        - username
      properties:
        username:
          type: string
        password:
          type: string
        phone:
          type: string
        email_other:
          type: string
        active:
          type: boolean
        superadmin:
          type: boolean
    Email_AdminListResponse:
      type: object
      properties:
        success:
          type: boolean
        data:
          type: array
          items:
            $ref: '#/components/schemas/Email_Admin'
    Email_Result:
      type: object
      properties:
        success:
          type: boolean
        error:
          type: string
        message:
          type: string