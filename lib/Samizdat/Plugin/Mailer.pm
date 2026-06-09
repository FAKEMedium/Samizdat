package Samizdat::Plugin::Mailer;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Mailer;
use Mojo::Loader qw(data_section);

sub register ($self, $app, $conf) {
  return if (!(exists($app->config->{manager}->{mailer})));

  my $r = $app->routes;

  # Store OpenAPI fragment
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Mailer} = $openapi_yaml if $openapi_yaml;

  # Manager routes (HTML cacheable, JSON for API)
  my $manager = $r->manager('mailer')->to(controller => 'Mailer');
  $manager->get('/addresses')                        ->to('#addresses')          ->name('mailer_addresses');
  $manager->get('/lists')                            ->to('#lists')              ->name('mailer_lists');
  $manager->get('/lists/:listid')                    ->to('#list_show')          ->name('mailer_list_show');
  $manager->get('/unsubscriptions')                  ->to('#unsubscriptions')    ->name('mailer_unsubscriptions');
  $manager->get('/bounces')                          ->to('#bounces')            ->name('mailer_bounces');
  $manager->get('/configs')                          ->to('#configs_page')       ->name('mailer_configs');
  $manager->get('/search')                           ->to('#search')             ->name('mailer_search');
  $manager->get('/new')                              ->to('#edit')               ->name('mailer_new');
  $manager->get('/unsubscribe/:token')               ->to('#unsubscribe')        ->name('mailer_unsubscribe');
  $manager->get('/unsubscribe')                      ->to('#unsubscribe_form')   ->name('mailer_unsubscribe_form');
  $manager->get('/privacy/:private_id')              ->to('#privacy')            ->name('mailer_privacy');
  $manager->get('/privacy')                          ->to('#privacy_form')       ->name('mailer_privacy_form');
  $manager->get('/:mailid/edit')                     ->to('#edit')               ->name('mailer_edit');
  $manager->get('/:mailid')                          ->to('#show')               ->name('mailer_show');
  $manager->get('/')                                 ->to('#index')              ->name('mailer_index');

  # API routes handled by OpenAPI (POST, PUT, DELETE)

  $app->helper(mailer => sub ($c) {
    state $model = Samizdat::Model::Mailer->new({
      config => $c->settings->resolve('mailer'),
      pg     => $c->pg,
      minion => $c->app->renderer->helpers->{minion} ? $c->minion : undef,
    });
    return $model;
  });
}

=head1 NAME

Samizdat::Plugin::Mailer - Bulk mailer plugin

=head1 DESCRIPTION

This plugin provides bulk email campaigns with:
- Localized content (markdown to HTML via pandoc)
- Mailing lists with address management
- Unsubscribe management
- Delivery tracking via Minion jobs

=head1 ROUTES

  GET  /manager/mailer                       - List mails
  GET  /manager/mailer/new                   - New mail form (modal)
  GET  /manager/mailer/:mailid               - Show mail
  GET  /manager/mailer/:mailid/edit          - Edit mail (modal)
  GET  /manager/mailer/addresses             - List addresses
  GET  /manager/mailer/lists                 - List mailing lists
  GET  /manager/mailer/lists/:listid         - Show list with addresses
  GET  /manager/mailer/unsubscriptions       - List unsubscriptions
  GET  /manager/mailer/bounces               - List bounces
  GET  /manager/mailer/configs               - Config settings page
  GET  /manager/mailer/search                - Search mails/addresses/bounces
  GET  /manager/mailer/unsubscribe/:token    - Unsubscribe page
  GET  /manager/mailer/privacy/:private_id       - Privacy self-service data view
  DELETE /manager/mailer/privacy/:private_id   - Privacy data deletion request

=head1 SEE ALSO

L<Samizdat::Controller::Mailer>, L<Samizdat::Model::Mailer>

=cut

1;

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for Mailer API
paths:
  /mailer:
    get:
      operationId: Mailer.index
      x-mojo-to: Mailer#index
      summary: List mails
      tags: [Mailer]
      parameters:
        - name: status
          in: query
          schema:
            type: string
            enum: [draft, scheduled, sending, completed, cancelled]
        - name: page
          in: query
          schema:
            type: integer
        - name: per_page
          in: query
          schema:
            type: integer
      responses:
        '200':
          description: List of mails
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Mailer_MailListResponse'
    post:
      operationId: Mailer.create
      x-mojo-to: Mailer#create
      summary: Create mail
      tags: [Mailer]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Mailer_MailInput'
      responses:
        '201':
          description: Mail created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Mailer_MailResponse'

  /mailer/new:
    get:
      operationId: Mailer.new
      x-mojo-to: Mailer#edit
      summary: New mail form
      tags: [Mailer]
      responses:
        '200':
          description: New mail form

  /mailer/addresses:
    get:
      operationId: Mailer.addresses
      x-mojo-to: Mailer#addresses
      summary: List addresses
      tags: [Mailer]
      parameters:
        - name: source
          in: query
          schema:
            type: string
            enum: [import, scrape, purchase, manual, signup]
        - name: needs_review
          in: query
          schema:
            type: boolean
      responses:
        '200':
          description: List of addresses
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Mailer_AddressListResponse'

  /mailer/addresses/{addressid}:
    get:
      operationId: Mailer.address
      x-mojo-to: Mailer#address
      summary: Get address details
      tags: [Mailer]
      parameters:
        - name: addressid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Address details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Mailer_AddressResponse'
    put:
      operationId: Mailer.address.update
      x-mojo-to: Mailer#address_update
      summary: Update address
      tags: [Mailer]
      parameters:
        - name: addressid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Mailer_AddressInput'
      responses:
        '200':
          description: Address updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Mailer_AddressResponse'
    delete:
      operationId: Mailer.address.delete
      x-mojo-to: Mailer#address_delete
      summary: Delete address
      tags: [Mailer]
      parameters:
        - name: addressid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Address deleted

  /mailer/addresses/bulk:
    delete:
      operationId: Mailer.addresses.bulk_delete
      x-mojo-to: Mailer#addresses_bulk_delete
      summary: Bulk delete addresses
      tags: [Mailer]
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                addressids:
                  type: array
                  items:
                    type: integer
              required:
                - addressids
      responses:
        '200':
          description: Addresses deleted
          content:
            application/json:
              schema:
                type: object
                properties:
                  success:
                    type: boolean
                  deleted:
                    type: integer
                  toast:
                    type: string

  /mailer/addresses/to-remove:
    get:
      operationId: Mailer.addresses.to_remove
      x-mojo-to: Mailer#addresses_to_remove
      summary: Get addresses suggested for removal (bounces)
      tags: [Mailer]
      responses:
        '200':
          description: Addresses to remove
          content:
            application/json:
              schema:
                type: object
                properties:
                  addresses:
                    type: array
                    items:
                      type: object
                      properties:
                        addressid:
                          type: integer
                        email:
                          type: string
                        first_name:
                          type: string
                        last_name:
                          type: string
                        bounce_type:
                          type: string
                        bounce_count:
                          type: integer

  /mailer/lists:
    get:
      operationId: Mailer.lists
      x-mojo-to: Mailer#lists
      summary: List mailing lists
      tags: [Mailer]
      responses:
        '200':
          description: List of mailing lists
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Mailer_ListListResponse'
    post:
      operationId: Mailer.list.create
      x-mojo-to: Mailer#list_create
      summary: Create mailing list
      tags: [Mailer]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Mailer_ListInput'
      responses:
        '201':
          description: List created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Mailer_ListResponse'

  /mailer/lists/{listid}:
    get:
      operationId: Mailer.list
      x-mojo-to: Mailer#list_show
      summary: Get list details
      tags: [Mailer]
      parameters:
        - name: listid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: List details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Mailer_ListDetailResponse'
    put:
      operationId: Mailer.list.update
      x-mojo-to: Mailer#list_update
      summary: Update mailing list
      tags: [Mailer]
      parameters:
        - name: listid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Mailer_ListInput'
      responses:
        '200':
          description: List updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Mailer_ListResponse'
    delete:
      operationId: Mailer.list.delete
      x-mojo-to: Mailer#list_delete
      summary: Delete mailing list
      tags: [Mailer]
      parameters:
        - name: listid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: List deleted

  /mailer/lists/{listid}/addresses:
    get:
      operationId: Mailer.list.addresses
      x-mojo-to: Mailer#list_addresses
      summary: Get addresses in list
      tags: [Mailer]
      parameters:
        - name: listid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Addresses in list
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Mailer_AddressListResponse'

  /mailer/lists/import:
    post:
      operationId: Mailer.list.import
      x-mojo-to: Mailer#list_import
      summary: Import addresses into a list
      tags: [Mailer]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Mailer_ImportInput'
      responses:
        '200':
          description: Import results
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Mailer_ImportResponse'

  /mailer/unsubscriptions:
    get:
      operationId: Mailer.unsubscriptions
      x-mojo-to: Mailer#unsubscriptions
      summary: List unsubscriptions
      tags: [Mailer]
      responses:
        '200':
          description: List of unsubscriptions
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Mailer_UnsubscriptionListResponse'

  /mailer/unsubscriptions/{unsubscriptionid}:
    delete:
      operationId: Mailer.unsubscription.delete
      x-mojo-to: Mailer#unsubscription_delete
      summary: Remove unsubscription
      tags: [Mailer]
      parameters:
        - name: unsubscriptionid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Unsubscription removed

  /mailer/bounces:
    get:
      operationId: Mailer.bounces
      x-mojo-to: Mailer#bounces
      summary: List bounces
      tags: [Mailer]
      parameters:
        - name: type
          in: query
          schema:
            type: string
            enum: [hard, soft, complaint, delayed]
      responses:
        '200':
          description: List of bounces
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Mailer_BounceListResponse'

  /mailer/bounces/{bounceid}:
    get:
      operationId: Mailer.bounce
      x-mojo-to: Mailer#bounce
      summary: Get bounce details
      tags: [Mailer]
      parameters:
        - name: bounceid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Bounce details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Mailer_BounceResponse'
    delete:
      operationId: Mailer.bounce.delete
      x-mojo-to: Mailer#bounce_delete
      summary: Delete bounce record
      tags: [Mailer]
      parameters:
        - name: bounceid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Bounce deleted

  /mailer/search:
    get:
      operationId: Mailer.search
      x-mojo-to: Mailer#search
      summary: Search mails, addresses, or bounces
      tags: [Mailer]
      parameters:
        - name: q
          in: query
          required: true
          schema:
            type: string
        - name: type
          in: query
          schema:
            type: string
            enum: [mail, address, bounce]
      responses:
        '200':
          description: Search results
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Mailer_SearchResponse'

  /mailer/{mailid}:
    get:
      operationId: Mailer.show
      x-mojo-to: Mailer#show
      summary: Get mail details
      tags: [Mailer]
      parameters:
        - name: mailid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Mail details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Mailer_MailDetailResponse'
    put:
      operationId: Mailer.update
      x-mojo-to: Mailer#update
      summary: Update mail
      tags: [Mailer]
      parameters:
        - name: mailid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Mailer_MailInput'
      responses:
        '200':
          description: Mail updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Mailer_MailResponse'
    delete:
      operationId: Mailer.delete
      x-mojo-to: Mailer#delete
      summary: Delete mail
      tags: [Mailer]
      parameters:
        - name: mailid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Mail deleted

  /mailer/configs:
    get:
      operationId: Mailer.configs
      x-mojo-to: Mailer#configs
      summary: Get config settings
      tags: [Mailer]
      parameters:
        - name: customerid
          in: query
          schema:
            type: integer
      responses:
        '200':
          description: Config settings
          content:
            application/json:
              schema:
                type: object
                properties:
                  configs:
                    type: array
                    items:
                      $ref: '#/components/schemas/Mailer_Config'
                  customerid:
                    type: integer
    post:
      operationId: Mailer.config.upsert
      x-mojo-to: Mailer#config_upsert
      summary: Create or update config setting
      tags: [Mailer]
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                customerid:
                  type: integer
                key:
                  type: string
                value:
                  type: string
              required:
                - key
                - value
      responses:
        '200':
          description: Config saved
          content:
            application/json:
              schema:
                type: object
                properties:
                  success:
                    type: boolean
                  config:
                    $ref: '#/components/schemas/Mailer_Config'
                  toast:
                    type: string

  /mailer/configs/{key}:
    delete:
      operationId: Mailer.config.delete
      x-mojo-to: Mailer#config_delete
      summary: Delete config setting
      tags: [Mailer]
      parameters:
        - name: key
          in: path
          required: true
          schema:
            type: string
        - name: customerid
          in: query
          schema:
            type: integer
      responses:
        '200':
          description: Config deleted

  /mailer/translate:
    post:
      operationId: Mailer.translate
      x-mojo-to: Mailer#translate
      summary: Translate text using AI
      tags: [Mailer]
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                text:
                  type: string
                  description: Text to translate
                source_language:
                  type: string
                  description: Source language code (optional, auto-detected if omitted)
                target_language:
                  type: string
                  description: Target language code (e.g., 'sv', 'en', 'de')
              required:
                - text
                - target_language
      responses:
        '200':
          description: Translation successful
          content:
            application/json:
              schema:
                type: object
                properties:
                  success:
                    type: boolean
                  translated:
                    type: string

  /mailer/{mailid}/copy:
    post:
      operationId: Mailer.copy
      x-mojo-to: Mailer#copy
      summary: Copy mail as draft
      tags: [Mailer]
      parameters:
        - name: mailid
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
                name:
                  type: string
                  description: Name for the copy (defaults to "Copy of [original]")
      responses:
        '201':
          description: Mail copied
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Mailer_MailResponse'

  /mailer/{mailid}/edit:
    get:
      operationId: Mailer.edit
      x-mojo-to: Mailer#edit
      summary: Edit mail form
      tags: [Mailer]
      parameters:
        - name: mailid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Edit form

  /mailer/{mailid}/content:
    post:
      operationId: Mailer.content.upsert
      x-mojo-to: Mailer#content_upsert
      summary: Create or update localized content
      tags: [Mailer]
      parameters:
        - name: mailid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Mailer_ContentInput'
      responses:
        '200':
          description: Content saved
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Mailer_ContentResponse'

  /mailer/{mailid}/queue:
    post:
      operationId: Mailer.queue
      x-mojo-to: Mailer#queue
      summary: Queue mail for sending
      tags: [Mailer]
      parameters:
        - name: mailid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Mailer_QueueInput'
      responses:
        '200':
          description: Mail queued
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Mailer_QueueResponse'

  /mailer/{mailid}/deliveries:
    get:
      operationId: Mailer.deliveries
      x-mojo-to: Mailer#deliveries
      summary: Get delivery status
      tags: [Mailer]
      parameters:
        - name: mailid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Delivery list
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Mailer_DeliveryListResponse'

  /mailer/{mailid}/bounces:
    get:
      operationId: Mailer.mail.bounces
      x-mojo-to: Mailer#mail_bounces
      summary: Get bounces for mail with removal suggestions
      tags: [Mailer]
      parameters:
        - name: mailid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Bounces with suggestions
          content:
            application/json:
              schema:
                type: object
                properties:
                  bounces:
                    type: array
                    items:
                      type: object
                      properties:
                        bounceid:
                          type: integer
                        email:
                          type: string
                        addressid:
                          type: integer
                        bounce_type:
                          type: string
                        bounce_code:
                          type: string
                        diagnostic:
                          type: string
                        suggest_remove:
                          type: boolean

  /manager/mailer/unsubscribe:
    post:
      operationId: Mailer.unsubscribe.request
      x-mojo-to: Mailer#unsubscribe_request
      summary: Request unsubscribe magic link via email
      tags: [Mailer]
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                email:
                  type: string
                  format: email
                customerid:
                  type: integer
              required:
                - email
                - customerid
      responses:
        '200':
          description: Magic link sent if address exists
          content:
            application/json:
              schema:
                type: object
                properties:
                  success:
                    type: boolean
                  toast:
                    type: string

  /manager/mailer/unsubscribe/{token}:
    get:
      operationId: Mailer.unsubscribe
      x-mojo-to: Mailer#unsubscribe
      summary: Unsubscribe page
      tags: [Mailer]
      parameters:
        - name: token
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: Unsubscribe confirmation

  /manager/mailer/privacy:
    post:
      operationId: Mailer.privacy.request
      x-mojo-to: Mailer#privacy_request
      summary: Request privacy magic link via email
      tags: [Mailer]
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                email:
                  type: string
                  format: email
                customerid:
                  type: integer
              required:
                - email
                - customerid
      responses:
        '200':
          description: Magic link sent if address exists
          content:
            application/json:
              schema:
                type: object
                properties:
                  success:
                    type: boolean
                  toast:
                    type: string

  /manager/mailer/privacy/{private_id}:
    get:
      operationId: Mailer.privacy
      x-mojo-to: Mailer#privacy
      summary: Privacy self-service data view
      tags: [Mailer]
      parameters:
        - name: private_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: User data and list memberships
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Mailer_PrivacyResponse'

  /manager/mailer/privacy/{private_id}:
    delete:
      operationId: Mailer.privacy.delete
      x-mojo-to: Mailer#privacy_delete
      summary: Request Privacy data deletion
      tags: [Mailer]
      parameters:
        - name: private_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: Deletion confirmed
          content:
            application/json:
              schema:
                type: object
                properties:
                  success:
                    type: boolean
                  toast:
                    type: string

components:
  schemas:
    Mailer_Mail:
      type: object
      properties:
        mailid:
          type: integer
        customerid:
          type: integer
        name:
          type: string
        is_draft:
          type: boolean
        status:
          type: string
          enum: [draft, scheduled, sending, completed, cancelled]
        scheduled:
          type: string
          format: date-time
        started:
          type: string
          format: date-time
        completed:
          type: string
          format: date-time
        smtp_serverid:
          type: integer
        creator:
          type: integer
        created:
          type: string
          format: date-time
        modified:
          type: string
          format: date-time

    Mailer_MailInput:
      type: object
      properties:
        name:
          type: string
        status:
          type: string
        scheduled:
          type: string
          format: date-time
        smtp_serverid:
          type: integer
      required:
        - name

    Mailer_MailResponse:
      type: object
      properties:
        success:
          type: boolean
        mail:
          $ref: '#/components/schemas/Mailer_Mail'
        toast:
          type: string

    Mailer_MailListResponse:
      type: object
      properties:
        mails:
          type: array
          items:
            $ref: '#/components/schemas/Mailer_Mail'
        page:
          type: integer
        pages:
          type: integer
        total:
          type: integer

    Mailer_MailDetailResponse:
      type: object
      properties:
        mail:
          $ref: '#/components/schemas/Mailer_Mail'
        contents:
          type: array
          items:
            $ref: '#/components/schemas/Mailer_Content'
        stats:
          type: object
          additionalProperties:
            type: integer

    Mailer_Content:
      type: object
      properties:
        contentid:
          type: integer
        mailid:
          type: integer
        languageid:
          type: integer
        from:
          type: string
        organization:
          type: string
        subject:
          type: string
        body_md:
          type: string
        attachments:
          type: array
          items:
            $ref: '#/components/schemas/Mailer_Attachment'

    Mailer_ContentInput:
      type: object
      properties:
        languageid:
          type: integer
        from:
          type: string
        organization:
          type: string
        subject:
          type: string
        body_md:
          type: string
      required:
        - languageid
        - subject
        - body_md

    Mailer_ContentResponse:
      type: object
      properties:
        success:
          type: boolean
        content:
          $ref: '#/components/schemas/Mailer_Content'
        toast:
          type: string

    Mailer_Attachment:
      type: object
      properties:
        attachmentid:
          type: integer
        contentid:
          type: integer
        filename:
          type: string
        filepath:
          type: string
        mimetype:
          type: string

    Mailer_Address:
      type: object
      properties:
        addressid:
          type: integer
        private_id:
          type: string
          format: uuid
        customerid:
          type: integer
        email:
          type: string
        name:
          type: string
        first_name:
          type: string
        last_name:
          type: string
        languageid:
          type: integer
        verified:
          type: boolean
        needs_review:
          type: boolean
        source:
          type: string
          enum: [import, scrape, purchase, manual, signup]
        created:
          type: string
          format: date-time

    Mailer_AddressInput:
      type: object
      properties:
        email:
          type: string
          format: email
        name:
          type: string
        first_name:
          type: string
        last_name:
          type: string
        languageid:
          type: integer
        source:
          type: string
        needs_review:
          type: boolean
      required:
        - email

    Mailer_AddressResponse:
      type: object
      properties:
        success:
          type: boolean
        address:
          $ref: '#/components/schemas/Mailer_Address'
        toast:
          type: string

    Mailer_AddressListResponse:
      type: object
      properties:
        addresses:
          type: array
          items:
            $ref: '#/components/schemas/Mailer_Address'

    Mailer_List:
      type: object
      properties:
        listid:
          type: integer
        customerid:
          type: integer
        name:
          type: string
        description:
          type: string
        is_public:
          type: boolean
        created:
          type: string
          format: date-time

    Mailer_ListInput:
      type: object
      properties:
        name:
          type: string
        description:
          type: string
        is_public:
          type: boolean
      required:
        - name

    Mailer_ListResponse:
      type: object
      properties:
        success:
          type: boolean
        list:
          $ref: '#/components/schemas/Mailer_List'
        toast:
          type: string

    Mailer_ListListResponse:
      type: object
      properties:
        lists:
          type: array
          items:
            $ref: '#/components/schemas/Mailer_List'

    Mailer_ListDetailResponse:
      type: object
      properties:
        list:
          $ref: '#/components/schemas/Mailer_List'
        addresses:
          type: array
          items:
            $ref: '#/components/schemas/Mailer_Address'
        address_count:
          type: integer

    Mailer_ImportInput:
      type: object
      properties:
        listid:
          type: integer
        format:
          type: string
          enum: [text, csv]
        data:
          type: string
        columns:
          type: object
          properties:
            email:
              type: integer
            name:
              type: integer
            first_name:
              type: integer
            last_name:
              type: integer
        source:
          type: string
          enum: [import, scrape, purchase, manual]
      required:
        - listid
        - format
        - data

    Mailer_ImportResponse:
      type: object
      properties:
        success:
          type: boolean
        created:
          type: integer
        linked:
          type: integer
        needs_review:
          type: integer
        results:
          type: array
          items:
            type: object
            properties:
              email:
                type: string
              name:
                type: string
              first_name:
                type: string
              last_name:
                type: string
              is_new:
                type: boolean
              needs_review:
                type: boolean
        toast:
          type: string

    Mailer_Unsubscription:
      type: object
      properties:
        unsubscriptionid:
          type: integer
        email:
          type: string
        reason:
          type: string
        token:
          type: string
          format: uuid
        created:
          type: string
          format: date-time

    Mailer_UnsubscriptionListResponse:
      type: object
      properties:
        unsubscriptions:
          type: array
          items:
            $ref: '#/components/schemas/Mailer_Unsubscription'

    Mailer_QueueInput:
      type: object
      properties:
        listids:
          type: array
          items:
            type: integer
          description: List IDs to include
        customer_filter:
          type: object
          description: Filter for customer selection
        include_addresses:
          type: boolean
          description: Include list addresses

    Mailer_QueueResponse:
      type: object
      properties:
        success:
          type: boolean
        queued:
          type: integer
        skipped:
          type: integer
        toast:
          type: string

    Mailer_Delivery:
      type: object
      properties:
        deliveryid:
          type: integer
        mailid:
          type: integer
        email:
          type: string
        languageid:
          type: integer
        customerid:
          type: integer
        addressid:
          type: integer
        status:
          type: string
          enum: [pending, queued, sent, failed]
        queued:
          type: string
          format: date-time
        sent:
          type: string
          format: date-time
        error:
          type: string

    Mailer_DeliveryListResponse:
      type: object
      properties:
        deliveries:
          type: array
          items:
            $ref: '#/components/schemas/Mailer_Delivery'

    Mailer_Bounce:
      type: object
      properties:
        bounceid:
          type: integer
        deliveryid:
          type: integer
        email:
          type: string
        bounce_type:
          type: string
          enum: [hard, soft, complaint, delayed]
        bounce_code:
          type: string
        diagnostic:
          type: string
        raw_message:
          type: string
        processed:
          type: boolean
        received:
          type: string
          format: date-time

    Mailer_BounceListResponse:
      type: object
      properties:
        bounces:
          type: array
          items:
            $ref: '#/components/schemas/Mailer_Bounce'

    Mailer_BounceResponse:
      type: object
      properties:
        bounce:
          $ref: '#/components/schemas/Mailer_Bounce'

    Mailer_SearchResponse:
      type: object
      properties:
        results:
          type: array
          items:
            type: object
        type:
          type: string

    Mailer_Config:
      type: object
      properties:
        configid:
          type: integer
        customerid:
          type: integer
        key:
          type: string
        value:
          type: string

    Mailer_PrivacyResponse:
      type: object
      properties:
        address:
          $ref: '#/components/schemas/Mailer_Address'
        lists:
          type: array
          items:
            type: object
            properties:
              listid:
                type: integer
              name:
                type: string
              description:
                type: string
              subscribed:
                type: string
                format: date-time
        deliveries:
          type: array
          items:
            type: object
            properties:
              mailid:
                type: integer
              mail_name:
                type: string
              status:
                type: string
              sent:
                type: string
                format: date-time
