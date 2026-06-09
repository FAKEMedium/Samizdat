package Samizdat::Plugin::BIS;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::BIS;
use Mojo::Loader qw(data_section);

sub register ($self, $app, $config = {}) {

  my $r = $app->routes;

  # Store OpenAPI fragment (parsed centrally in _load_openapi)
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{BIS} = $openapi_yaml if $openapi_yaml;

  # Public routes (for public dashboard - HTML pages)
  my $bis = $r->home('bis')->to(controller => 'BIS');
  $bis->get('/domain/#domain/#to')        ->to('#nav')                  ->name('bis_nav');
  $bis->get('/domain/#domain')            ->to('#domain')               ->name('bis_domain');
  $bis->get('/sector/#sector')            ->to('#sector')               ->name('bis_sector');
  $bis->get('/providers')                 ->to('#providers')            ->name('bis_providers');
  $bis->get('/trends')                    ->to('#trends')               ->name('bis_trends');
  $bis->get('/')                          ->to('#index')                ->name('bis_index');

  # Manager routes (HTML pages only - GET)
  my $manager = $r->manager('bis')->to(controller => 'BIS');
  $manager->get('/domains')               ->to('#domains')              ->name('bis_domains');
  $manager->get('/tags')                  ->to('#tags')                 ->name('bis_tags');
  $manager->get('/runs')                  ->to('#runs')                 ->name('bis_runs');
  $manager->get('/providers')             ->to('#manage_providers')     ->name('bis_manage_providers');
  $manager->get('/')                      ->to('#manager')              ->name('bis_manager');

  # API routes are defined in OpenAPI spec (__DATA__ section)

  # Register model helper
  $app->helper(bis => sub ($c) {
    state $model = Samizdat::Model::BIS->new({
      config => $c->settings->resolve('bis'),
      redis  => $c->app->redis,
      pg     => $c->app->pg,
    });
    return $model;
  });

}

=head1 NAME

Samizdat::Plugin::BIS - Based in Sweden compliance tracking plugin

=head1 SYNOPSIS

  # In your application
  $app->plugin('BIS');

  # Use the helper
  my $bis = $c->bis;

  # Add a domain to track
  my $domain_id = $bis->add_domain(
    domain => 'example.se',
    title => 'Example Organization',
    tags => ['government']
  );

=head1 DESCRIPTION

This plugin integrates BIS (Based in Sweden) functionality into Samizdat, including:

=over 4

=item * DNS record checking (A, AAAA, MX, NS)

=item * IP geolocation and ASN lookup

=item * Hosting provider identification

=item * Compliance scoring and tracking

=item * Public dashboard for viewing compliance status

=item * Manager interface for administering tracked domains

=item * Historical trend analysis

=back

=head1 ROUTES

The plugin registers the following routes:

=head2 Public Routes

=over 4

=item * GET /bis - Public dashboard showing all domains

=item * GET /bis/domain/:domain - Details for a specific domain

=item * GET /bis/sector/:sector - View by sector (e.g., healthcare, government)

=item * GET /bis/providers - Hosting provider statistics

=item * GET /bis/trends - Historical compliance trends

=back

=head2 Manager Routes (HTML)

=over 4

=item * GET /manager/bis - Main management panel

=item * GET /manager/bis/domains - List all tracked domains

=item * GET /manager/bis/tags - Manage tags

=item * GET /manager/bis/runs - View check runs

=item * GET /manager/bis/providers - Manage provider database

=back

=head2 API Routes (OpenAPI)

=over 4

=item * POST /api/bis/domains - Add new domain

=item * PUT /api/bis/domains/:id - Update domain

=item * DELETE /api/bis/domains/:id - Delete domain

=item * POST /api/bis/tags - Add new tag

=item * POST /api/bis/runs/start - Start new check run

=item * POST /api/bis/runs/:id/check - Check all domains in run

=item * POST /api/bis/providers - Add new provider

=back

=head1 HELPERS

=head2 bis

Returns the L<Samizdat::Model::BIS> instance.

  my $bis = $c->bis;
  my $domain_id = $bis->add_domain(domain => 'example.se');

=head1 CONFIGURATION

Configure in samizdat.yml under manager.bis:

  bis:
    cardnumber: 17
    dbtype: postgresql

=head1 SEE ALSO

L<Samizdat::Model::BIS>, L<Samizdat::Controller::BIS>

Based in Sweden initiative: L<https://basedinsweden.se/>

=cut

1;

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for BIS API (Based in Sweden compliance tracking)
paths:
  /bis/domains:
    get:
      operationId: BIS.domains.index
      x-mojo-to: BIS#domains
      summary: List tracked domains
      tags: [BIS]
      responses:
        '200':
          description: List of domains
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BIS_DomainListResponse'
    post:
      operationId: BIS.domains.create
      x-mojo-to: BIS#add_domain
      summary: Add new domain to track
      tags: [BIS]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/BIS_DomainInput'
      responses:
        '200':
          description: Domain added
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BIS_Result'

  /bis/domains/{id}:
    put:
      operationId: BIS.domains.update
      x-mojo-to: BIS#update_domain
      summary: Update domain
      tags: [BIS]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/BIS_DomainInput'
      responses:
        '200':
          description: Domain updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BIS_Result'
    delete:
      operationId: BIS.domains.delete
      x-mojo-to: BIS#delete_domain
      summary: Delete domain
      tags: [BIS]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Domain deleted
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BIS_Result'

  /bis/tags:
    get:
      operationId: BIS.tags.index
      x-mojo-to: BIS#tags
      summary: List tags
      tags: [BIS]
      responses:
        '200':
          description: List of tags
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BIS_TagListResponse'
    post:
      operationId: BIS.tags.create
      x-mojo-to: BIS#add_tag
      summary: Add new tag
      tags: [BIS]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/BIS_TagInput'
      responses:
        '200':
          description: Tag added
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BIS_Result'

  /bis/runs:
    get:
      operationId: BIS.runs.index
      x-mojo-to: BIS#runs
      summary: List check runs
      tags: [BIS]
      responses:
        '200':
          description: List of runs
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BIS_RunListResponse'

  /bis/runs/start:
    post:
      operationId: BIS.runs.start
      x-mojo-to: BIS#start_run
      summary: Start new check run
      tags: [BIS]
      responses:
        '200':
          description: Run started
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BIS_RunResult'

  /bis/runs/{id}/check:
    post:
      operationId: BIS.runs.check
      x-mojo-to: BIS#check_run
      summary: Check all domains in run
      tags: [BIS]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Check completed
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BIS_Result'

  /bis/providers:
    get:
      operationId: BIS.providers.index
      x-mojo-to: BIS#manage_providers
      summary: List providers
      tags: [BIS]
      responses:
        '200':
          description: List of providers
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BIS_ProviderListResponse'
    post:
      operationId: BIS.providers.create
      x-mojo-to: BIS#add_provider
      summary: Add new provider
      tags: [BIS]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/BIS_ProviderInput'
      responses:
        '200':
          description: Provider added
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BIS_Result'

  /bis/manager:
    get:
      operationId: BIS.manager.index
      x-mojo-to: BIS#api_manager
      summary: Manager dashboard data
      tags: [BIS]
      responses:
        '200':
          description: Manager dashboard data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BIS_ManagerResponse'

  # Public API routes (JSON only)
  /bis/public/scores:
    get:
      operationId: BIS.public.scores
      x-mojo-to: BIS#api_scores
      summary: Get compliance scores for public dashboard
      tags: [BIS]
      parameters:
        - name: tag
          in: query
          schema:
            type: string
        - name: search
          in: query
          schema:
            type: string
        - name: compliance
          in: query
          schema:
            type: string
        - name: limit
          in: query
          schema:
            type: integer
            default: 100
        - name: offset
          in: query
          schema:
            type: integer
            default: 0
        - name: lang
          in: query
          schema:
            type: string
            default: en
      responses:
        '200':
          description: Compliance scores
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BIS_ScoresResponse'

  /bis/public/trends:
    get:
      operationId: BIS.public.trends
      x-mojo-to: BIS#api_trends
      summary: Get historical compliance trends
      tags: [BIS]
      parameters:
        - name: days
          in: query
          schema:
            type: integer
            default: 90
      responses:
        '200':
          description: Compliance trends
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BIS_TrendsResponse'

  /bis/public/providers:
    get:
      operationId: BIS.public.providers
      x-mojo-to: BIS#api_public_providers
      summary: Get hosting provider statistics
      tags: [BIS]
      responses:
        '200':
          description: Provider statistics
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BIS_ProviderStatsResponse'

  /bis/public/domain/{domain}:
    get:
      operationId: BIS.public.domain
      x-mojo-to: BIS#api_domain
      summary: Get domain compliance details
      tags: [BIS]
      parameters:
        - name: domain
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
        - name: lang
          in: query
          schema:
            type: string
            default: en
      responses:
        '200':
          description: Domain details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BIS_DomainDetailsResponse'

  /bis/public/sector/{sector}:
    get:
      operationId: BIS.public.sector
      x-mojo-to: BIS#api_sector
      summary: Get sector compliance data
      tags: [BIS]
      parameters:
        - name: sector
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
        - name: limit
          in: query
          schema:
            type: integer
            default: 100
        - name: offset
          in: query
          schema:
            type: integer
            default: 0
        - name: lang
          in: query
          schema:
            type: string
            default: en
      responses:
        '200':
          description: Sector data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BIS_SectorResponse'

components:
  schemas:
    BIS_Domain:
      type: object
      properties:
        id:
          type: integer
        domain:
          type: string
        title:
          type: string
        description:
          type: string
        sector:
          type: string
        score:
          type: number
        is_compliant:
          type: boolean
        tags:
          type: array
          items:
            type: string
    BIS_DomainInput:
      type: object
      properties:
        domain:
          type: string
        title:
          type: string
        description:
          type: string
        sector:
          type: string
        tags:
          type: array
          items:
            type: string
    BIS_DomainListResponse:
      type: object
      properties:
        domains:
          type: array
          items:
            $ref: '#/components/schemas/BIS_Domain'
    BIS_Tag:
      type: object
      properties:
        id:
          type: integer
        name:
          type: string
        display_name:
          type: string
    BIS_TagInput:
      type: object
      properties:
        name:
          type: string
        display_name:
          type: string
    BIS_TagListResponse:
      type: object
      properties:
        tags:
          type: array
          items:
            $ref: '#/components/schemas/BIS_Tag'
    BIS_Run:
      type: object
      properties:
        id:
          type: integer
        status:
          type: string
        started_at:
          type: string
          format: date-time
        completed_at:
          type: string
          format: date-time
        domains_checked:
          type: integer
        statistics:
          type: object
    BIS_RunListResponse:
      type: object
      properties:
        runs:
          type: array
          items:
            $ref: '#/components/schemas/BIS_Run'
    BIS_RunResult:
      type: object
      properties:
        success:
          type: boolean
        run_id:
          type: integer
    BIS_Provider:
      type: object
      properties:
        id:
          type: integer
        name:
          type: string
        asn:
          type: integer
        is_swedish:
          type: boolean
    BIS_ProviderInput:
      type: object
      properties:
        name:
          type: string
        asn:
          type: integer
        as_name_pattern:
          type: string
        is_swedish:
          type: boolean
    BIS_ProviderListResponse:
      type: object
      properties:
        providers:
          type: array
          items:
            $ref: '#/components/schemas/BIS_Provider'
    BIS_ManagerResponse:
      type: object
      properties:
        sector_stats:
          type: array
          items:
            type: object
        recent_runs:
          type: array
          items:
            $ref: '#/components/schemas/BIS_Run'
    BIS_Result:
      type: object
      properties:
        success:
          type: boolean
        error:
          type: string
        message:
          type: string
        id:
          type: integer
    BIS_ScoresResponse:
      type: object
      properties:
        success:
          type: boolean
        scores:
          type: array
          items:
            type: object
        total:
          type: integer
        sector_stats:
          type: array
          items:
            type: object
    BIS_TrendsResponse:
      type: object
      properties:
        success:
          type: boolean
        trends:
          type: array
          items:
            type: object
            properties:
              date:
                type: string
              compliance_rate:
                type: number
              a_compliance_rate:
                type: number
              mx_compliance_rate:
                type: number
              ns_compliance_rate:
                type: number
              avg_score:
                type: number
    BIS_ProviderStatsResponse:
      type: object
      properties:
        success:
          type: boolean
        providers:
          type: array
          items:
            type: object
            properties:
              provider_name:
                type: string
              country_code:
                type: string
              is_swedish:
                type: boolean
              cloud_act_applies:
                type: boolean
              domain_count:
                type: integer
              total_records:
                type: integer
    BIS_DomainDetailsResponse:
      type: object
      properties:
        success:
          type: boolean
        domain:
          type: object
        checks:
          type: array
          items:
            type: object
        tags:
          type: array
          items:
            type: string
    BIS_SectorResponse:
      type: object
      properties:
        success:
          type: boolean
        sector:
          type: string
        sector_info:
          type: object
        scores:
          type: array
          items:
            type: object
        total:
          type: integer
