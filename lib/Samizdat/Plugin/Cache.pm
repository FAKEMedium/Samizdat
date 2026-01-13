package Samizdat::Plugin::Cache;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Cache;
use Mojo::Loader qw(data_section);

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  # Store OpenAPI fragment (parsed centrally in _load_openapi)
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Cache} = $openapi_yaml if $openapi_yaml;

  # Manager routes (HTML pages only - GET)
  my $manager = $r->manager('cache')->to(controller => 'Cache');
  $manager->get('/view')          ->to('#view')   ->name('cache_view');
  $manager->get('/')              ->to('#index')  ->name('cache_index');

  # API routes are defined in OpenAPI spec (__DATA__ section)

  # Helper for accessing the Cache model
  $app->helper(cache => sub ($c) {
    state $model = Samizdat::Model::Cache->new({
      redis  => $c->redis,
      config => $app->config->{manager}->{cache},
    });

    # Update session reference for encryption
    $model->session($c->session) if $c->can('session');

    return $model;
  });
}

=head1 NAME

Samizdat::Plugin::Cache - Redis cache management plugin

=head1 DESCRIPTION

This plugin provides cache management functionality including listing,
viewing, deleting, and purging Redis cache entries.

=head1 ROUTES

=head2 Manager Routes (HTML)

=over 4

=item * GET /manager/cache - Cache management page

=item * GET /manager/cache/view - View entry modal template

=back

=head2 API Routes (OpenAPI)

=over 4

=item * GET /api/cache - List cache entries

=item * GET /api/cache/:key - Get cache entry details

=item * DELETE /api/cache/:key - Delete cache entry

=item * POST /api/cache/purge - Purge cache entries by pattern

=back

=cut

1;

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for Cache API
paths:
  /cache:
    get:
      operationId: Cache.index
      x-mojo-to: Cache#index
      summary: List cache entries
      tags: [Cache]
      parameters:
        - name: pattern
          in: query
          schema:
            type: string
            default: '*'
          description: Key pattern to filter entries
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
          description: List of cache entries
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Cache_ListResponse'

  /cache/purge:
    post:
      operationId: Cache.purge
      x-mojo-to: Cache#purge
      summary: Purge cache entries
      tags: [Cache]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Cache_PurgeInput'
      responses:
        '200':
          description: Cache purged
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Cache_Result'

  /cache/{key}:
    get:
      operationId: Cache.get
      x-mojo-to: Cache#show
      summary: Get cache entry details
      tags: [Cache]
      parameters:
        - name: key
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      responses:
        '200':
          description: Cache entry details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Cache_EntryResponse'
    delete:
      operationId: Cache.delete
      x-mojo-to: Cache#delete
      summary: Delete cache entry
      tags: [Cache]
      parameters:
        - name: key
          in: path
          required: true
          x-mojo-placeholder: "#"
          schema:
            type: string
      responses:
        '200':
          description: Cache entry deleted
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Cache_Result'

components:
  schemas:
    Cache_Entry:
      type: object
      properties:
        key:
          type: string
        type:
          type: string
        ttl:
          type: integer
        value:
          type: string
        preview:
          type: string
    Cache_ListResponse:
      type: object
      properties:
        success:
          type: boolean
        entries:
          type: array
          items:
            $ref: '#/components/schemas/Cache_Entry'
        pagination:
          type: object
          properties:
            page:
              type: integer
            pages:
              type: integer
            total:
              type: integer
    Cache_EntryResponse:
      type: object
      properties:
        success:
          type: boolean
        entry:
          $ref: '#/components/schemas/Cache_Entry'
    Cache_PurgeInput:
      type: object
      properties:
        pattern:
          type: string
          default: '*'
        confirmed:
          type: boolean
    Cache_Result:
      type: object
      properties:
        success:
          type: boolean
        error:
          type: string
        message:
          type: string
