package Samizdat::Plugin::Website;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Website;
use Mojo::Loader qw(data_section);

sub register ($self, $app, $conf) {
  return unless (exists($app->config->{manager}->{website}));

  my $r = $app->routes;

  # Store OpenAPI fragment
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Website} = $openapi_yaml if $openapi_yaml;

  # Manager routes for websites (HTML pages)
  my $manager = $r->manager('websites')->to(controller => 'Website');
  $manager->get('/servers')             ->to('#servers')  ->name('website_servers');
  $manager->get('/domains')             ->to('#domains')  ->name('website_domains');
  $manager->get('/new')                 ->to('#edit', websiteid => 'new')->name('website_new');
  $manager->get('/:websiteid')          ->to('#edit')     ->name('website_edit');
  $manager->get('/')                    ->to('#index')    ->name('website_index');

  # Customer-specific website routes (HTML pages)
  my $customers = $r->manager('customers/:customerid/websites')->to(controller => 'Website');
  $customers->get('/')                  ->to('#index')    ->name('customer_websites');
  $customers->get('/:websiteid')        ->to('#get')      ->name('customer_website_get');

  # API routes are defined in OpenAPI spec (__DATA__ section)

  # Helper
  $app->helper(website => sub ($c) {
    state $model = Samizdat::Model::Website->new(
      pg     => $app->pg,
      config => $app->settings->resolve('website'),
    );
    return $model;
  });
}

1;

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for Website API (hosting infrastructure)
paths:
  /websites:
    get:
      operationId: Website.index
      x-mojo-to: Website#index
      summary: List all websites
      tags: [Website]
      parameters:
        - name: customerid
          in: query
          schema:
            type: integer
          description: Filter by customer ID
        - name: active
          in: query
          schema:
            type: boolean
          description: Filter by active status
      responses:
        '200':
          description: List of websites
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Website_ListResponse'
    post:
      operationId: Website.create
      x-mojo-to: Website#create
      summary: Create new website
      tags: [Website]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Website_Input'
      responses:
        '201':
          description: Website created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Website_Response'

  /websites/{websiteid}:
    get:
      operationId: Website.get
      x-mojo-to: Website#get
      summary: Get website details
      tags: [Website]
      parameters:
        - name: websiteid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Website details with domains
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Website_DetailResponse'
    put:
      operationId: Website.update
      x-mojo-to: Website#update
      summary: Update website
      tags: [Website]
      parameters:
        - name: websiteid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Website_Input'
      responses:
        '200':
          description: Website updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Website_Response'
    delete:
      operationId: Website.delete
      x-mojo-to: Website#delete
      summary: Delete website
      tags: [Website]
      parameters:
        - name: websiteid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Website deleted
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Website_Result'

  /websites/{websiteid}/domains:
    get:
      operationId: Website.domains.list
      x-mojo-to: Website#domains
      summary: List domains for website
      tags: [Website]
      parameters:
        - name: websiteid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: List of domains
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Website_DomainListResponse'
    post:
      operationId: Website.domains.create
      x-mojo-to: Website#add_domain
      summary: Add domain to website
      tags: [Website]
      parameters:
        - name: websiteid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Website_DomainInput'
      responses:
        '201':
          description: Domain added
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Website_Result'

  /websites/{websiteid}/domains/{domainid}:
    delete:
      operationId: Website.domains.delete
      x-mojo-to: Website#delete_domain
      summary: Remove domain from website
      tags: [Website]
      parameters:
        - name: websiteid
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
          description: Domain removed
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Website_Result'

  /websites/{websiteid}/primary-domain:
    put:
      operationId: Website.primaryDomain
      x-mojo-to: Website#set_primary_domain
      summary: Set primary domain for website
      tags: [Website]
      parameters:
        - name: websiteid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                domainid:
                  type: integer
              required:
                - domainid
      responses:
        '200':
          description: Primary domain set
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Website_Result'

  /websites/{websiteid}/phpconfig:
    get:
      operationId: Website.phpconfig.get
      x-mojo-to: Website#get_phpconfig
      summary: Get PHP configuration for website
      tags: [Website]
      parameters:
        - name: websiteid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: PHP configuration
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Website_ConfigResponse'
    put:
      operationId: Website.phpconfig.update
      x-mojo-to: Website#update_phpconfig
      summary: Update PHP configuration for website
      tags: [Website]
      parameters:
        - name: websiteid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Website_ConfigInput'
      responses:
        '200':
          description: PHP configuration updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Website_Result'
    delete:
      operationId: Website.phpconfig.delete
      x-mojo-to: Website#delete_phpconfig
      summary: Delete PHP configuration for website
      tags: [Website]
      parameters:
        - name: websiteid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: PHP configuration deleted
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Website_Result'

  /websites/{websiteid}/serverextra:
    get:
      operationId: Website.serverextra.get
      x-mojo-to: Website#get_serverextra
      summary: Get server extra configuration for website
      tags: [Website]
      parameters:
        - name: websiteid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Server extra configuration
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Website_ConfigResponse'
    put:
      operationId: Website.serverextra.update
      x-mojo-to: Website#update_serverextra
      summary: Update server extra configuration for website
      tags: [Website]
      parameters:
        - name: websiteid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Website_ConfigInput'
      responses:
        '200':
          description: Server extra configuration updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Website_Result'
    delete:
      operationId: Website.serverextra.delete
      x-mojo-to: Website#delete_serverextra
      summary: Delete server extra configuration for website
      tags: [Website]
      parameters:
        - name: websiteid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Server extra configuration deleted
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Website_Result'

  /domains:
    get:
      operationId: Website.allDomains
      x-mojo-to: Website#domains
      summary: List all domains
      tags: [Website]
      parameters:
        - name: customerid
          in: query
          schema:
            type: integer
          description: Filter by customer ID
      responses:
        '200':
          description: List of domains
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Website_DomainListResponse'

  /servers:
    get:
      operationId: Website.servers
      x-mojo-to: Website#servers
      summary: List all servers
      tags: [Website]
      responses:
        '200':
          description: List of servers
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Website_ServerListResponse'

  /servers/types:
    get:
      operationId: Website.serverTypes
      x-mojo-to: Website#server_types
      summary: List server types
      tags: [Website]
      responses:
        '200':
          description: List of server types
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Website_ServerTypeListResponse'

  /servers/shells:
    get:
      operationId: Website.shells
      x-mojo-to: Website#shells
      summary: List available shells
      tags: [Website]
      responses:
        '200':
          description: List of shells
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Website_ShellListResponse'

  /customers/{customerid}/websites:
    get:
      operationId: Website.customer.index
      x-mojo-to: Website#index
      summary: List customer websites
      tags: [Website]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: List of customer websites
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Website_ListResponse'

components:
  schemas:
    Website:
      type: object
      properties:
        websiteid:
          type: integer
        customerid:
          type: integer
        home:
          type: string
          description: Home directory path
        serverid:
          type: integer
        servername:
          type: string
        servertypename:
          type: string
        passwordid:
          type: integer
        certificateid:
          type: integer
        shellid:
          type: integer
        shell:
          type: string
        ip4:
          type: string
          format: ipv4
          description: IPv4 address override (null = use server default)
        ip6:
          type: string
          format: ipv6
          description: IPv6 address override (null = use server default)
        ip_only:
          type: boolean
          description: Bind to IP only, no hostname (catch-all for domain parking)
        redirecturl:
          type: string
        active:
          type: integer
        web_usage:
          type: integer
        primarydomain:
          type: integer
        domainname:
          type: string
    Website_Input:
      type: object
      properties:
        customerid:
          type: integer
        domainname:
          type: string
          description: Primary domain name (creates domain record)
        home:
          type: string
        serverid:
          type: integer
        shellid:
          type: integer
        ip4:
          type: string
          format: ipv4
        ip6:
          type: string
          format: ipv6
        ip_only:
          type: boolean
        redirecturl:
          type: string
        active:
          type: integer
      required:
        - customerid
    Website_Domain:
      type: object
      properties:
        domainid:
          type: integer
        domainname:
          type: string
        websiteid:
          type: integer
        customerid:
          type: integer
        incert:
          type: boolean
          description: Include in multi-SAN certificate
        home:
          type: string
        active:
          type: integer
    Website_DomainInput:
      type: object
      properties:
        domainname:
          type: string
        customerid:
          type: integer
        incert:
          type: boolean
      required:
        - domainname
    Website_Server:
      type: object
      properties:
        serverid:
          type: integer
        hostname:
          type: string
        jailname:
          type: string
        servertypeid:
          type: integer
        servertypename:
          type: string
        default_ip4:
          type: string
          format: ipv4
        default_ip6:
          type: string
          format: ipv6
    Website_ServerType:
      type: object
      properties:
        servertypeid:
          type: integer
        servertypename:
          type: string
    Website_Shell:
      type: object
      properties:
        shellid:
          type: integer
        shell:
          type: string
    Website_ListResponse:
      type: object
      properties:
        websites:
          type: array
          items:
            $ref: '#/components/schemas/Website'
    Website_Response:
      type: object
      properties:
        website:
          $ref: '#/components/schemas/Website'
    Website_DetailResponse:
      type: object
      properties:
        website:
          $ref: '#/components/schemas/Website'
        domains:
          type: array
          items:
            $ref: '#/components/schemas/Website_Domain'
    Website_DomainListResponse:
      type: object
      properties:
        domains:
          type: array
          items:
            $ref: '#/components/schemas/Website_Domain'
    Website_ServerListResponse:
      type: object
      properties:
        servers:
          type: array
          items:
            $ref: '#/components/schemas/Website_Server'
    Website_ServerTypeListResponse:
      type: object
      properties:
        types:
          type: array
          items:
            $ref: '#/components/schemas/Website_ServerType'
    Website_ShellListResponse:
      type: object
      properties:
        shells:
          type: array
          items:
            $ref: '#/components/schemas/Website_Shell'
    Website_Result:
      type: object
      properties:
        success:
          type: boolean
        error:
          type: string
        message:
          type: string
    Website_ConfigResponse:
      type: object
      properties:
        config:
          type: string
          description: Configuration content (PHP-FPM pool or server extra directives)
        active:
          type: boolean
          description: Whether configuration is enabled
    Website_ConfigInput:
      type: object
      properties:
        config:
          type: string
          description: Configuration content
        active:
          type: boolean
          description: Enable or disable the configuration
