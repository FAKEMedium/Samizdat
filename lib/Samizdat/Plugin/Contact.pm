package Samizdat::Plugin::Contact;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::Loader qw(data_section);

sub register ($self, $app, $conf = {}) {
  # Store OpenAPI fragment
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Contact} = $openapi_yaml if $openapi_yaml;

  my $r = $app->routes;
  # GET for HTML page, API routes handled by OpenAPI
  $r->any(['GET', 'POST'] => '/contact')->to(controller => 'Contact', action => 'index')->name('contact_index');
}

1;

__DATA__
@@ openapi.yaml
# OpenAPI 3.0 fragment for Contact API
paths:
  /contact:
    get:
      tags:
        - Contact
      summary: Get contact form data
      description: Returns pre-filled form data if user is logged in. Returns HTML page or JSON based on Accept header.
      operationId: Contact.get
      responses:
        '200':
          description: Form data with pre-filled values
          content:
            application/json:
              schema:
                type: object
                properties:
                  ip:
                    type: string
                    description: Client IP address
                  name:
                    type: string
                    description: Pre-filled name from user profile
                  email:
                    type: string
                    description: Pre-filled email from user profile
                  errors:
                    type: object
                    description: Field validation errors
                  valid:
                    type: object
                    description: Field validation status
    post:
      tags:
        - Contact
      summary: Submit contact form
      description: Validates and sends contact message via email
      operationId: Contact.submit
      requestBody:
        required: true
        content:
          application/x-www-form-urlencoded:
            schema:
              type: object
              required:
                - name
                - email
                - subject
                - message
                - captcha
              properties:
                name:
                  type: string
                  description: Sender name
                email:
                  type: string
                  format: email
                  description: Sender email address
                subject:
                  type: string
                  description: Message subject
                message:
                  type: string
                  description: Message body
                captcha:
                  type: string
                  description: Captcha response
      responses:
        '200':
          description: Form submission result
          content:
            application/json:
              schema:
                type: object
                properties:
                  success:
                    type: integer
                    enum: [0, 1]
                    description: 1 if message sent successfully, 0 if validation failed
                  errors:
                    type: object
                    description: Field-specific error messages
                  valid:
                    type: object
                    description: Field validation CSS classes (is-valid/is-invalid)
                  sent:
                    type: string
                    description: HTML confirmation message (when success=1)