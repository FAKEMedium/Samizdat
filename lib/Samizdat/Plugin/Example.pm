package Samizdat::Plugin::Example;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Example;
use Mojo::Loader qw(data_section);

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  # Store OpenAPI fragment (parsed centrally in _load_openapi)
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Example} = $openapi_yaml if $openapi_yaml;

  # Manager routes (HTML pages only - GET)
  my $manager = $r->manager('examples')->to(controller => 'Example');
  $manager->get('/:id/edit')              ->to('#edit')                             ->name('example_edit');
  $manager->get('/new')                   ->to('#edit', id => 'new')                ->name('example_new');
  $manager->get('/:id')                   ->to('#show')                             ->name('example_show');
  $manager->get('/')                      ->to('#index')                            ->name('example_index');

  # API routes are defined in OpenAPI spec (__DATA__ section)

  $app->helper(example => sub {
    state $model = Samizdat::Model::Example->new({
      pg => $app->pg,
      config => $app->config->{manager}->{example}
    });
    return $model;
  });

}

=head1 NAME

Samizdat::Plugin::Example - Example CRUD plugin

=head1 DESCRIPTION

This plugin demonstrates a standard CRUD pattern for Samizdat plugins.
Use it as a template when creating new plugins.

=head1 NGINX CONFIGURATION

Example routes use dynamic C<:id> parameters. The controller sets
C<docpath> to ensure all example IDs share the same cached template.

=head2 Regex Routes

    # Example show - any ID uses same cached template
    location ~ ^/manager/examples/\d+$ {
        root /path/to/public;
        try_files /manager/examples/show/index.html @backend;
    }

    # Example edit form
    location ~ ^/manager/examples/\d+/edit$ {
        root /path/to/public;
        try_files /manager/examples/edit/index.html @backend;
    }

    location @backend {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

=head1 SEE ALSO

L<Samizdat::Controller::Example>, L<Samizdat::Model::Example>

=cut

1;

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for Example API
paths:
  /examples:
    get:
      operationId: Example.index
      x-mojo-to: Example#index
      summary: List all examples
      tags: [Examples]
      responses:
        '200':
          description: List of examples
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Example_ListResponse'
    post:
      operationId: Example.create
      x-mojo-to: Example#create
      summary: Create a new example
      tags: [Examples]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Example_Input'
      responses:
        '200':
          description: Created example
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Example_Example'

  /examples/{id}:
    get:
      operationId: Example.get
      x-mojo-to: Example#show
      summary: Get example details
      tags: [Examples]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Example data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Example_Example'
    put:
      operationId: Example.update
      x-mojo-to: Example#update
      summary: Update example
      tags: [Examples]
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
              $ref: '#/components/schemas/Example_Input'
      responses:
        '200':
          description: Updated example
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Example_Example'
    delete:
      operationId: Example.delete
      x-mojo-to: Example#delete
      summary: Delete example
      tags: [Examples]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Example deleted
          content:
            application/json:
              schema:
                type: object

components:
  schemas:
    Example_Example:
      type: object
      properties:
        id:
          type: integer
        name:
          type: string
        description:
          type: string
        created_at:
          type: string
          format: date-time
        updated_at:
          type: string
          format: date-time
    Example_Input:
      type: object
      properties:
        name:
          type: string
        description:
          type: string
    Example_ListResponse:
      type: object
      properties:
        examples:
          type: array
          items:
            $ref: '#/components/schemas/Example_Example'
