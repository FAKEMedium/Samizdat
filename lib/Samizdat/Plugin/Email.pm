package Samizdat::Plugin::Email;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Email;
use Mojo::Loader qw(data_section);

sub register ($self, $app, $conf) {
  return if (!(exists($app->config->{manager}->{email})));

  my $r = $app->routes;

  # Store OpenAPI fragment (parsed centrally in _load_openapi)
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Email} = $openapi_yaml if $openapi_yaml;

  # Email management routes (HTML pages)
  # Route order: most specific first
  my $manager = $r->manager('email')->to(controller => 'Email');

  # Admin routes (modal) - under /admins
  $manager->get('/admins/admin/#username')                   ->to('#admin_page')                ->name('email_admin');
  $manager->get('/admins/admin')                             ->to('#admin_page')                ->name('email_admin_edit');

  # Domain routes (full page)
  $manager->get('/domain')                                   ->to('#domain_page')               ->name('email_domain_edit');

  # List pages (before /#domain to avoid capture)
  $manager->get('/admins')                                   ->to('#admins_page')               ->name('email_admins');
  $manager->get('/mailboxes')                                ->to('#mailboxes_page')            ->name('email_mailboxes');
  $manager->get('/log')                                      ->to('#log_page')                  ->name('email_log');

  # Postfix mail-queue management (superadmin-only; HTML pages, JSON via OpenAPI)
  $manager->get('/mailq/message/#id')                        ->to('#mailq_show_page')           ->name('email_mailq_show');
  $manager->get('/mailq')                                    ->to('#mailq_index_page')          ->name('email_mailq_index');

  # Domain-specific routes (most specific first)
  $manager->get('/#domain/admins/#admin')                    ->to('#domain_admin')              ->name('email_domain_admin');
  $manager->get('/#domain/admins')                           ->to('#domain_admins')             ->name('email_domain_admins');
  $manager->get('/#domain/alias/#address')                   ->to('#alias_page')                ->name('email_alias');
  $manager->get('/#domain/alias')                            ->to('#alias_page')                ->name('email_alias_edit');
  $manager->get('/#domain/mailbox/#username/sync')           ->to('#mailbox_sync_page')         ->name('email_mailbox_sync');
  $manager->get('/#domain/mailbox/#username')                ->to('#mailbox_page')              ->name('email_mailbox');
  $manager->get('/#domain/mailbox')                          ->to('#mailbox_page')              ->name('email_mailbox_edit');
  $manager->get('/#domain')                                  ->to('#domain_page')               ->name('email_domain');

  # Main index
  $manager->get('/')                                         ->to('#index')                     ->name('email_index');

  # API routes are defined in OpenAPI spec (__DATA__ section)

  # Helper to access email model
  $app->helper(email => sub ($self) {
    state $model = Samizdat::Model::Email->new({
      config       => $self->settings->resolve('email'),
      fallback_dsn => $self->config->{dsn}{pg},
    });
    # Set current user for logging
    my $username = $self->session('user');
    if ($username) {
      my $superadmins = $self->config->{manager}->{account}->{superadmins} // {};
      $model->current_user(exists $superadmins->{$username} ? 'superadmin' : $username);
    } else {
      $model->current_user('system');
    }
    return $model;
  });

  # Minion task: IMAP sync via imapsync. The job args carry full connection
  # details; passwords are written to a temporary file and passed with
  # --passfile1/--passfile2 so they don't appear in the process list.
  $app->minion->add_task(email_imap_sync => sub ($job, $args) {
    require File::Temp;
    require IPC::Run3;

    my $src = $args->{source} || {};
    my $dst = $args->{dest}   || {};

    my $src_pw = File::Temp->new(UNLINK => 1, TEMPLATE => 'imapsync-src-XXXXXX', TMPDIR => 1);
    my $dst_pw = File::Temp->new(UNLINK => 1, TEMPLATE => 'imapsync-dst-XXXXXX', TMPDIR => 1);
    chmod 0600, $src_pw->filename, $dst_pw->filename;
    print $src_pw $src->{password} // ''; close $src_pw;
    print $dst_pw $dst->{password} // ''; close $dst_pw;

    my @cmd = (
      'imapsync',
      '--host1'     => $src->{host},
      '--port1'     => $src->{port} || 993,
      '--user1'     => $src->{user},
      '--passfile1' => $src_pw->filename,
      '--host2'     => $dst->{host},
      '--port2'     => $dst->{port} || 993,
      '--user2'     => $dst->{user},
      '--passfile2' => $dst_pw->filename,
      '--nofoldersizes',
    );
    push @cmd, '--ssl1'    if $src->{ssl};
    push @cmd, '--ssl2'    if $dst->{ssl};
    push @cmd, '--dry'     if $args->{dry_run};
    push @cmd, '--delete'  if $args->{delete_source};
    push @cmd, '--useuid'  if $args->{skip_existing};

    my ($out, $err);
    my $ok = eval { IPC::Run3::run3(\@cmd, \undef, \$out, \$err); 1 };
    my $exit = $?;

    if (!$ok) {
      return $job->fail({ error => "imapsync failed to run: $@", stdout => $out // '', stderr => $err // '' });
    }
    if ($exit != 0) {
      return $job->fail({
        error  => "imapsync exited with code " . ($exit >> 8),
        stdout => $out // '',
        stderr => $err // '',
      });
    }

    return $job->finish({
      success => 1,
      domain   => $args->{domain},
      username => $args->{username},
      dry_run  => $args->{dry_run},
      stdout   => $out // '',
    });
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

  /email/log:
    get:
      operationId: Email.logs.index
      x-mojo-to: Email#logs_index
      summary: List email management logs
      tags: [Email]
      parameters:
        - name: username
          in: query
          schema:
            type: string
          description: Filter by username
        - name: domain
          in: query
          schema:
            type: string
          description: Filter by domain
        - name: action
          in: query
          schema:
            type: string
          description: Filter by action type
        - name: page
          in: query
          schema:
            type: integer
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            default: 50
      responses:
        '200':
          description: List of log entries
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_LogListResponse'

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

  /email/domains/{domain}/mailboxes/{username}/sync:
    post:
      operationId: Email.mailboxes.sync
      x-mojo-to: Email#mailbox_sync
      summary: Enqueue IMAP sync job for this mailbox
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
              $ref: '#/components/schemas/Email_MailboxSyncInput'
      responses:
        '200':
          description: Sync job enqueued
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_MailboxSyncResult'

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

  /email/{domain}/admins:
    get:
      operationId: Email.domain_admins.index
      x-mojo-to: Email#domain_admins
      summary: List domain admins
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
          description: List of domain admins
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Result'

  /email/vacation/{email}:
    get:
      operationId: Email.vacation.get
      x-mojo-to: Email#vacation
      summary: Get vacation settings
      tags: [Email]
      parameters:
        - name: email
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      responses:
        '200':
          description: Vacation settings
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Result'
    put:
      operationId: Email.vacation.update
      x-mojo-to: Email#vacation
      summary: Update vacation settings
      tags: [Email]
      parameters:
        - name: email
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      requestBody:
        content:
          application/json:
            schema:
              type: object
      responses:
        '200':
          description: Vacation updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Result'
    delete:
      operationId: Email.vacation.delete
      x-mojo-to: Email#vacation
      summary: Delete vacation settings
      tags: [Email]
      parameters:
        - name: email
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      responses:
        '200':
          description: Vacation deleted
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Result'

  /email/{domain}/admins/{admin}:
    post:
      operationId: Email.domain_admins.add
      x-mojo-to: Email#domain_admin
      summary: Add admin to domain
      tags: [Email]
      parameters:
        - name: domain
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
        - name: admin
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      responses:
        '200':
          description: Admin added to domain
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Result'
    delete:
      operationId: Email.domain_admins.remove
      x-mojo-to: Email#domain_admin
      summary: Remove admin from domain
      tags: [Email]
      parameters:
        - name: domain
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
        - name: admin
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      responses:
        '200':
          description: Admin removed from domain
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Result'

  /email/mailq:
    get:
      operationId: Email.mailq.index
      x-mojo-to: Email#mailq_index
      summary: List queued postfix messages (superadmin)
      tags: [Email Mailq]
      responses:
        '200':
          description: Queue listing
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_MailqListResponse'

  /email/mailq/flush:
    post:
      operationId: Email.mailq.flush
      x-mojo-to: Email#mailq_flush
      summary: Flush deferred queue (superadmin)
      tags: [Email Mailq]
      responses:
        '200':
          description: Flush result
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Result'

  /email/mailq/purge:
    post:
      operationId: Email.mailq.purge
      x-mojo-to: Email#mailq_purge
      summary: Purge queued messages by filter (superadmin)
      tags: [Email Mailq]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Email_MailqPurgeInput'
      responses:
        '200':
          description: Purge result
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_MailqPurgeResult'

  /email/mailq/{id}:
    get:
      operationId: Email.mailq.show
      x-mojo-to: Email#mailq_show
      summary: View queued message (superadmin)
      tags: [Email Mailq]
      parameters:
        - name: id
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      responses:
        '200':
          description: Message content
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_MailqMessage'
    delete:
      operationId: Email.mailq.delete
      x-mojo-to: Email#mailq_delete
      summary: Delete queued message (superadmin)
      tags: [Email Mailq]
      parameters:
        - name: id
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      responses:
        '200':
          description: Delete result
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Result'

  /email/mailq/{id}/hold:
    post:
      operationId: Email.mailq.hold
      x-mojo-to: Email#mailq_hold
      summary: Hold queued message (superadmin)
      tags: [Email Mailq]
      parameters:
        - name: id
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      responses:
        '200':
          description: Hold result
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Email_Result'

  /email/mailq/{id}/release:
    post:
      operationId: Email.mailq.release
      x-mojo-to: Email#mailq_release
      summary: Release queued message (superadmin)
      tags: [Email Mailq]
      parameters:
        - name: id
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      responses:
        '200':
          description: Release result
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
    Email_MailboxSyncEndpoint:
      type: object
      required:
        - host
        - user
        - password
      properties:
        host:
          type: string
        port:
          type: integer
          default: 993
        user:
          type: string
        password:
          type: string
        ssl:
          type: boolean
          default: true
    Email_MailboxSyncInput:
      type: object
      required:
        - source
        - dest
      properties:
        source:
          $ref: '#/components/schemas/Email_MailboxSyncEndpoint'
        dest:
          $ref: '#/components/schemas/Email_MailboxSyncEndpoint'
        dry_run:
          type: boolean
        delete_source:
          type: boolean
        skip_existing:
          type: boolean
    Email_MailboxSyncResult:
      type: object
      properties:
        success:
          type: boolean
        job_id:
          type: integer
        message:
          type: string
        error:
          type: string
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
    Email_Log:
      type: object
      properties:
        id:
          type: integer
        timestamp:
          type: string
          format: date-time
        username:
          type: string
        domain:
          type: string
        action:
          type: string
        data:
          type: string
    Email_LogListResponse:
      type: object
      properties:
        success:
          type: boolean
        data:
          type: array
          items:
            $ref: '#/components/schemas/Email_Log'
        actions:
          type: array
          items:
            type: object
            properties:
              action:
                type: string
        pagination:
          type: object
          properties:
            page:
              type: integer
            limit:
              type: integer
            total:
              type: integer
            pages:
              type: integer
    Email_MailqEntry:
      type: object
      properties:
        queue_id:
          type: string
        queue_name:
          type: string
          description: Queue (incoming/active/deferred/hold/corrupt)
        arrival_time:
          type: integer
        message_size:
          type: integer
        sender:
          type: string
        recipients:
          type: array
          items:
            type: object
            properties:
              address:
                type: string
              delay_reason:
                type: string
    Email_MailqListResponse:
      type: object
      properties:
        success:
          type: boolean
        data:
          type: array
          items:
            $ref: '#/components/schemas/Email_MailqEntry'
        total:
          type: integer
    Email_MailqMessage:
      type: object
      properties:
        success:
          type: boolean
        id:
          type: string
        content:
          type: string
          description: Raw message text from postcat
    Email_MailqPurgeInput:
      type: object
      description: |
        At least one filter regex must be set, OR confirm must be 'all' to
        purge every queued message. Use dry_run=true to preview.
      properties:
        filter:
          type: object
          properties:
            sender:
              type: string
              description: Regex matched against sender address
            recipient:
              type: string
              description: Regex matched against any recipient address
            queue:
              type: string
              description: Regex matched against queue name (deferred/active/hold/...)
        confirm:
          type: string
          enum: [all]
          description: Required when no filter is given
        dry_run:
          type: boolean
    Email_MailqPurgeResult:
      type: object
      properties:
        ok:
          type: boolean
        matched:
          type: integer
        deleted:
          type: integer
        dry_run:
          type: boolean
        ids:
          type: array
          items:
            type: string
        error:
          type: string