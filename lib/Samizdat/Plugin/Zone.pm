package Samizdat::Plugin::Zone;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Zone;
use Mojo::Pg;
use Mojo::Loader qw(data_section);

sub register($self, $app, $conf) {
  return if (!(exists($app->config->{manager}->{zone})));

  my $r = $app->routes;

  # Store OpenAPI fragment (parsed centrally in _load_openapi)
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Zone} = $openapi_yaml if $openapi_yaml;

  # Manager routes (HTML pages only - GET)
  my $manager = $r->manager('zones')->to(controller => 'Zone');
  $manager->get('/check')                                        ->to('#check_index')             ->name('zone_check_index');
  $manager->get('/#zone_id/records/new')                         ->to('#new_record')              ->name('zone_record_new');
  $manager->get('/#zone_id/records/#record_id')                  ->to('#edit_record')             ->name('zone_record_edit');
  $manager->get('/#zone_id/records')                             ->to('#records')                 ->name('zone_record_index');
  $manager->get('/#zone_id/cryptokeys')                          ->to('#cryptokeys')              ->name('zone_cryptokeys');
  $manager->get('/templates/:template_id/records/#record_id')    ->to('#get_template_record')     ->name('zone_template_record_get');
  $manager->get('/templates/:template_id')                       ->to('#get_template')            ->name('zone_template_get');
  $manager->get('/templates')                                    ->to('#templates')               ->name('zone_templates');
  $manager->get('/#zone_id/edit')                                ->to('#edit_zone')               ->name('zone_edit');
  $manager->get('/#zone_id/export')                              ->to('#export_zone')             ->name('zone_export');
  $manager->get('/new')                                          ->to('#new_zone')                ->name('zone_new');
  $manager->get('/import')                                       ->to('#import_zone_form')        ->name('zone_import_form');
  $manager->get('/')                                             ->to('#index')                   ->name('zone_index');

  # Customer specific zone routes (HTML)
  my $customer = $r->manager('customers/:customerid/zones')->to(controller => 'Zone');
  $customer->get('/')                                            ->to('#index')                   ->name('customer_zones');

  # API routes are defined in OpenAPI spec (__DATA__ section)

  # Helper for PowerDNS database connection
  $app->helper(pdns => sub($c) {
    state $db = do {
      my $config = $c->config->{manager}->{zone};
      my $env = $config->{default_env} || 'production';
      my $dsn = $config->{env}->{$env}->{dsn};

      my $pg = Mojo::Pg->new($dsn);
      $pg->max_connections(5);
      $pg;
    };
    return $db;
  });

  # Helper for accessing the Zone API model.
  $app->helper(zone => sub($c) {
    state $model = Samizdat::Model::Zone->new({
      config => $c->settings->resolve('zone'),
      cache  => $c->cache,
      pdns   => $c->pdns,   # PowerDNS database
      pg     => $c->pg,     # Main Samizdat database (for templates)
    });
    return $model;
  });

  # Minion task for background zone checks (supports wildcards)
  $app->minion->add_task(zone_check => sub ($job, $zone) {
    my $result = $job->app->zone->check_zones($zone);
    $job->finish($result);
  });
}


=head1 NAME

Samizdat::Plugin::Zone - DNS zone management plugin

=head1 NGINX CONFIGURATION

The zone manager routes use dynamic C<#zone_id> parameters. To serve cached
HTML pages regardless of which zone is requested, configure nginx with a
regex location that rewrites all zone IDs to a single cached path:

    location ~ ^/manager/zones/[^/]+/records$ {
        root /path/to/public;
        try_files /manager/zones/_zone_id/records/index.html @backend;
    }

    location ~ ^/manager/zones/[^/]+/records/new$ {
        root /path/to/public;
        try_files /manager/zones/_zone_id/records/new/index.html @backend;
    }

    location ~ ^/manager/zones/[^/]+/edit$ {
        root /path/to/public;
        try_files /manager/zones/_zone_id/edit/index.html @backend;
    }

    location @backend {
        proxy_pass http://127.0.0.1:3000;
    }

The C<docpath> in F<samizdat.yml> controls where cached files are written.
Ensure nginx's C<root> matches this path. The placeholder C<_zone_id> directory
contains the generic cached template that works for any zone.

=cut

1;

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for Zone API (DNS management)
paths:
  /zones:
    get:
      operationId: Zone.index
      x-mojo-to: Zone#index
      summary: List all DNS zones
      tags: [Zones]
      responses:
        '200':
          description: List of zones
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Zone_ListResponse'
    post:
      operationId: Zone.create
      x-mojo-to: Zone#create_zone
      summary: Create a new zone
      tags: [Zones]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Zone_Input'
      responses:
        '200':
          description: Created zone
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Zone_Zone'

  /zones/check:
    get:
      operationId: Zone.check.index
      x-mojo-to: Zone#check_index
      summary: Zone check interface
      tags: [Zone Check]
      responses:
        '200':
          description: Check interface
          content:
            text/html:
              schema:
                type: string
    post:
      operationId: Zone.check.run
      x-mojo-to: Zone#check_run
      summary: Run zone check
      tags: [Zone Check]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Zone_CheckRequest'
      responses:
        '200':
          description: Check results
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Zone_CheckResponse'

  /zones/check/{job_id}:
    get:
      operationId: Zone.check.status
      x-mojo-to: Zone#check_status
      summary: Get check job status
      tags: [Zone Check]
      parameters:
        - name: job_id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Job status
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Zone_CheckJobStatus'

  /zones/import:
    post:
      operationId: Zone.import
      x-mojo-to: Zone#import_zone
      summary: Import zone from zone file
      tags: [Zones]
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                name:
                  type: string
                zone:
                  type: string
                kind:
                  type: string
                account:
                  type: string
      responses:
        '200':
          description: Import result
          content:
            application/json:
              schema:
                type: object

  /zones/{zone_id}:
    get:
      operationId: Zone.get
      x-mojo-to: Zone#edit_zone
      summary: Get zone details
      tags: [Zones]
      parameters:
        - name: zone_id
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      responses:
        '200':
          description: Zone data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Zone_Zone'
    patch:
      operationId: Zone.update
      x-mojo-to: Zone#update_zone
      summary: Update zone
      tags: [Zones]
      parameters:
        - name: zone_id
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Zone_Input'
      responses:
        '200':
          description: Updated zone
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Zone_Zone'
    delete:
      operationId: Zone.delete
      x-mojo-to: Zone#delete_zone
      summary: Delete zone
      tags: [Zones]
      parameters:
        - name: zone_id
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      responses:
        '200':
          description: Zone deleted
          content:
            application/json:
              schema:
                type: object

  /zones/{zone_id}/export:
    get:
      operationId: Zone.export
      x-mojo-to: Zone#export_zone
      summary: Export zone as zone file
      tags: [Zones]
      parameters:
        - name: zone_id
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      responses:
        '200':
          description: Zone file content
          content:
            text/plain:
              schema:
                type: string

  /zones/{zone_id}/records:
    get:
      operationId: Zone.records.index
      x-mojo-to: Zone#records
      summary: List zone records
      tags: [Zone Records]
      parameters:
        - name: zone_id
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      responses:
        '200':
          description: List of records
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Zone_RecordListResponse'
    post:
      operationId: Zone.records.create
      x-mojo-to: Zone#create_record
      summary: Create zone record
      tags: [Zone Records]
      parameters:
        - name: zone_id
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Zone_RecordInput'
      responses:
        '200':
          description: Created record
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Zone_Record'

  /zones/{zone_id}/records/{record_id}:
    get:
      operationId: Zone.records.get
      x-mojo-to: Zone#edit_record
      summary: Get zone record
      tags: [Zone Records]
      parameters:
        - name: zone_id
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
        - name: record_id
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
            description: Record identifier (TYPE_name format)
      responses:
        '200':
          description: Record data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Zone_Record'
    patch:
      operationId: Zone.records.update
      x-mojo-to: Zone#update_record
      summary: Update zone record
      tags: [Zone Records]
      parameters:
        - name: zone_id
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
        - name: record_id
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
            description: Record identifier (TYPE_name format)
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Zone_RecordInput'
      responses:
        '200':
          description: Updated record
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Zone_Record'
    delete:
      operationId: Zone.records.delete
      x-mojo-to: Zone#delete_record
      summary: Delete zone record
      tags: [Zone Records]
      parameters:
        - name: zone_id
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
        - name: record_id
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
            description: Record identifier (TYPE_name format)
      responses:
        '200':
          description: Record deleted
          content:
            application/json:
              schema:
                type: object

  /zones/{zone_id}/cryptokeys:
    get:
      operationId: Zone.cryptokeys.index
      x-mojo-to: Zone#cryptokeys
      summary: List DNSSEC keys
      tags: [Zone DNSSEC]
      parameters:
        - name: zone_id
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      responses:
        '200':
          description: List of cryptokeys
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Zone_Cryptokey'
    post:
      operationId: Zone.cryptokeys.create
      x-mojo-to: Zone#create_cryptokey
      summary: Create DNSSEC key
      tags: [Zone DNSSEC]
      parameters:
        - name: zone_id
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
          description: Created cryptokey
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Zone_Cryptokey'

  /zones/{zone_id}/cryptokeys/{key_id}:
    delete:
      operationId: Zone.cryptokeys.delete
      x-mojo-to: Zone#delete_cryptokey
      summary: Delete DNSSEC key
      tags: [Zone DNSSEC]
      parameters:
        - name: zone_id
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
        - name: key_id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Key deleted
          content:
            application/json:
              schema:
                type: object

  /zones/templates:
    get:
      operationId: Zone.templates.index
      x-mojo-to: Zone#templates
      summary: List zone templates
      tags: [Zone Templates]
      responses:
        '200':
          description: List of templates
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Zone_Template'
    post:
      operationId: Zone.templates.create
      x-mojo-to: Zone#create_template
      summary: Create zone template
      tags: [Zone Templates]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Zone_TemplateInput'
      responses:
        '200':
          description: Created template
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Zone_Template'

  /zones/templates/{template_id}:
    get:
      operationId: Zone.templates.get
      x-mojo-to: Zone#get_template
      summary: Get zone template
      tags: [Zone Templates]
      parameters:
        - name: template_id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Template data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Zone_Template'
    patch:
      operationId: Zone.templates.update
      x-mojo-to: Zone#update_template
      summary: Update zone template
      tags: [Zone Templates]
      parameters:
        - name: template_id
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Zone_TemplateInput'
      responses:
        '200':
          description: Updated template
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Zone_Template'
    delete:
      operationId: Zone.templates.delete
      x-mojo-to: Zone#delete_template
      summary: Delete zone template
      tags: [Zone Templates]
      parameters:
        - name: template_id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Template deleted
          content:
            application/json:
              schema:
                type: object

  /zones/templates/{template_id}/duplicate:
    post:
      operationId: Zone.templates.duplicate
      x-mojo-to: Zone#duplicate_template
      summary: Duplicate zone template
      tags: [Zone Templates]
      parameters:
        - name: template_id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Duplicated template
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Zone_Template'

  /zones/templates/{template_id}/records:
    post:
      operationId: Zone.templates.records.create
      x-mojo-to: Zone#create_template_record
      summary: Create template record
      tags: [Zone Templates]
      parameters:
        - name: template_id
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Zone_RecordInput'
      responses:
        '200':
          description: Created record
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Zone_Record'

  /zones/templates/{template_id}/records/{record_id}:
    get:
      operationId: Zone.templates.records.get
      x-mojo-to: Zone#get_template_record
      summary: Get template record
      tags: [Zone Templates]
      parameters:
        - name: template_id
          in: path
          required: true
          schema:
            type: integer
        - name: record_id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Record data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Zone_Record'
    patch:
      operationId: Zone.templates.records.update
      x-mojo-to: Zone#update_template_record
      summary: Update template record
      tags: [Zone Templates]
      parameters:
        - name: template_id
          in: path
          required: true
          schema:
            type: integer
        - name: record_id
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Zone_RecordInput'
      responses:
        '200':
          description: Updated record
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Zone_Record'
    delete:
      operationId: Zone.templates.records.delete
      x-mojo-to: Zone#delete_template_record
      summary: Delete template record
      tags: [Zone Templates]
      parameters:
        - name: template_id
          in: path
          required: true
          schema:
            type: integer
        - name: record_id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Record deleted
          content:
            application/json:
              schema:
                type: object

  /customers/{customerid}/zones:
    get:
      operationId: Zone.customer.index
      x-mojo-to: Zone#index
      summary: List customer zones
      tags: [Zones]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Customer zones
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Zone_ListResponse'

components:
  schemas:
    Zone_Zone:
      type: object
      properties:
        id:
          type: string
        name:
          type: string
        kind:
          type: string
          enum: [Native, Master, Slave]
        account:
          type: string
        serial:
          type: integer
        notified_serial:
          type: integer
        dnssec:
          type: boolean
    Zone_Input:
      type: object
      properties:
        name:
          type: string
        kind:
          type: string
        account:
          type: string
        nameservers:
          type: array
          items:
            type: string
    Zone_ListResponse:
      type: object
      properties:
        zones:
          type: array
          items:
            $ref: '#/components/schemas/Zone_Zone'
    Zone_Record:
      type: object
      properties:
        id:
          type: integer
        name:
          type: string
        type:
          type: string
        content:
          type: string
        ttl:
          type: integer
        prio:
          type: integer
        disabled:
          type: boolean
    Zone_RecordInput:
      type: object
      properties:
        name:
          type: string
        type:
          type: string
        content:
          type: string
        ttl:
          type: integer
        prio:
          type: integer
        disabled:
          type: boolean
    Zone_RecordListResponse:
      type: object
      properties:
        records:
          type: array
          items:
            $ref: '#/components/schemas/Zone_Record'
    Zone_Cryptokey:
      type: object
      properties:
        id:
          type: integer
        type:
          type: string
        active:
          type: boolean
        published:
          type: boolean
        dnskey:
          type: string
        ds:
          type: array
          items:
            type: string
    Zone_Template:
      type: object
      properties:
        id:
          type: integer
        name:
          type: string
        description:
          type: string
        records:
          type: array
          items:
            $ref: '#/components/schemas/Zone_Record'
    Zone_TemplateInput:
      type: object
      properties:
        name:
          type: string
        description:
          type: string
    Zone_CheckRequest:
      type: object
      required:
        - zone
      properties:
        zone:
          type: string
          description: Zone name to check
        async:
          type: boolean
          description: Run check as background job
          default: false
    Zone_CheckResponse:
      type: object
      properties:
        success:
          type: boolean
        zone:
          type: string
        whois:
          type: object
          properties:
            nameservers:
              type: array
              items:
                type: string
            registrar:
              type: string
            status:
              type: array
              items:
                type: string
        checks:
          type: array
          items:
            $ref: '#/components/schemas/Zone_NSCheck'
        errors:
          type: array
          items:
            type: string
    Zone_NSCheck:
      type: object
      properties:
        nameserver:
          type: string
        ip:
          type: string
        source_ip:
          type: string
        reachable:
          type: boolean
        soa:
          type: object
          properties:
            serial:
              type: integer
            primary:
              type: string
            admin:
              type: string
            match:
              type: boolean
        ns_records:
          type: array
          items:
            type: string
        ns_match:
          type: boolean
        response_time_ms:
          type: integer
        error:
          type: string
    Zone_CheckJobStatus:
      type: object
      properties:
        job_id:
          type: integer
        status:
          type: string
          enum: [inactive, active, finished, failed]
        result:
          $ref: '#/components/schemas/Zone_CheckResponse'
