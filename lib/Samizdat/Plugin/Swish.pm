package Samizdat::Plugin::Swish;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Swish;
use Mojo::Loader qw(data_section);
use Mojo::File;

sub register ($self, $app, $config = {}) {

  my $r = $app->routes;

  # Store OpenAPI fragment (parsed centrally in _load_openapi)
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Swish} = $openapi_yaml if $openapi_yaml;

  # Public routes (non-API)
  my $swish = $r->home('/swish')->to(controller => 'Swish');
  $swish->post('/callback')             ->to('#callback')             ->name('swish_callback');
  $swish->get('/success')               ->to('#success')              ->name('swish_success');
  $swish->get('/cancel')                ->to('#cancel')               ->name('swish_cancel');
  $swish->get('/qr')                    ->to('#qr')                   ->name('swish_qr');

  # API routes are defined in OpenAPI spec (__DATA__ section)

  # Manager routes
  my $manager = $r->manager('swish')->to(controller => 'Swish');
  $manager->get('/')                    ->to('#index')                ->name('swish_index');


  # Register model helper following the established pattern
  $app->helper(swish => sub ($c) {
    state $model;
    return $model if $model;

    eval {
      $model = Samizdat::Model::Swish->new(
        config => $c->app->config->{manager}->{swish},
        redis  => $c->app->redis,
        pg     => $c->app->pg,
      );
    };
    if ($@) {
      $c->app->log->error("Failed to create Swish model: $@");
    }
    return $model;
  });


  # Register swishbutton helper for generating payment button
  $app->helper(swishbutton => sub ($c, %params) {
    return $c->render_to_string(
      template => 'swish/chunks/swishbutton',
      format => 'html',
      params => \%params
    );
  });

  # Register helper for Swish button JavaScript
  $app->helper(swishbutton_script => sub ($c) {
    return $c->render_to_string(
      template => 'swish/chunks/swishbutton',
      format => 'js'
    );
  });

  # Register helper for Swish payment URL (web format)
  $app->helper(swish_payment_url => sub ($c, %params) {
    my $payee = $params{payee} || $c->app->config->{manager}->{swish}->{env}->{$c->app->config->{manager}->{swish}->{default_env} || 'test'}->{payee_alias} || '';
    my $amount = $params{amount} // 0;
    my $message = $params{message} // '';

    # Format: https://app.swish.nu/1/p/sw/?sw=46701234567&amt=170.0&msg=Hot%20Dog
    require Mojo::URL;
    my $url = Mojo::URL->new('https://app.swish.nu/1/p/sw/');
    $url->query(
      sw => $payee,
      amt => sprintf('%.2f', $amount / 100),  # Convert öre to SEK
      msg => $message
    );
    return $url->to_string;
  });

  # Register helper for QR code URL using Swish app scheme
  $app->helper(swish_qr_url => sub ($c, $token) {
    return "swish://paymentrequest?token=$token";
  });

  # Register helper for SVG QR code generation with optional center logo
  $app->helper(qr_svg => sub ($c, $data, %opts) {
    my $size = $opts{size} || 200;
    my $margin = $opts{margin} // 4;
    my $logo = $opts{logo};        # SVG content for center logo
    my $logo_image = $opts{logo_image};  # Data URI for PNG/JPG image
    my $logo_ratio = $opts{logo_ratio} // 0.25;  # Logo takes 25% of QR code
    my $has_logo = $logo || $logo_image;

    eval { require Text::QRCode };
    if ($@) {
      $c->app->log->error("Text::QRCode not installed: $@");
      return '';
    }

    # Use high error correction when embedding a logo
    my $level = $has_logo ? 'H' : ($opts{level} || 'M');

    my $qr = Text::QRCode->new(
      level => $level,
      version => $opts{version} || 0,
      mode => $opts{mode} || '8-bit',
    );

    my $matrix = $qr->plot($data);
    return '' unless $matrix && @$matrix;

    my $rows = scalar @$matrix;
    my $cols = scalar @{$matrix->[0]};
    my $total = $rows + ($margin * 2);
    my $cell_size = $size / $total;

    # Calculate logo exclusion zone (center area where logo will be placed)
    my $logo_size = $size * $logo_ratio;
    my $logo_x = ($size - $logo_size) / 2;
    my $logo_y = ($size - $logo_size) / 2;

    my @rects;
    for my $y (0 .. $rows - 1) {
      for my $x (0 .. $cols - 1) {
        if ($matrix->[$y][$x] eq '*') {
          my $px = ($x + $margin) * $cell_size;
          my $py = ($y + $margin) * $cell_size;

          # Skip cells that would be covered by the logo
          if ($has_logo) {
            my $cell_center_x = $px + $cell_size / 2;
            my $cell_center_y = $py + $cell_size / 2;
            next if $cell_center_x >= $logo_x && $cell_center_x <= $logo_x + $logo_size &&
                    $cell_center_y >= $logo_y && $cell_center_y <= $logo_y + $logo_size;
          }

          push @rects, qq{<rect x="$px" y="$py" width="$cell_size" height="$cell_size"/>};
        }
      }
    }

    my $rects_str = join("\n    ", @rects);

    # Build logo element if provided
    my $logo_element = '';
    if ($logo_image) {
      # Embed as image element with data URI
      $logo_element = qq{
  <image x="$logo_x" y="$logo_y" width="$logo_size" height="$logo_size" href="$logo_image"/>};
    }
    elsif ($logo) {
      # Extract inner content from SVG (remove outer svg tags)
      my $logo_inner = $logo;
      $logo_inner =~ s/<\?xml[^>]*\?>//g;
      $logo_inner =~ s/<svg[^>]*>//g;
      $logo_inner =~ s/<\/svg>//g;

      # Get viewBox from original SVG for proper scaling
      my ($vb) = $logo =~ /viewBox="([^"]+)"/;
      $vb //= "0 0 512 512";

      $logo_element = qq{
  <svg x="$logo_x" y="$logo_y" width="$logo_size" height="$logo_size" viewBox="$vb">
    $logo_inner
  </svg>};
    }

    return qq{<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $size $size" width="$size" height="$size">
  <rect width="100%" height="100%" fill="white"/>
  <g fill="black">
    $rects_str
  </g>$logo_element
</svg>};
  });

  # Register helper for Swish QR code SVG with Swish logo (PNG embedded as base64)
  $app->helper(swish_qr_svg => sub ($c, %params) {
    my $url = $c->swish_payment_url(%params);

    # Read Swish logo PNG and encode as base64 data URI
    my $logo_path = $c->app->home->child('src/swish/Swish icon qr-code.png');
    my $logo_data_uri = '';
    if (-f $logo_path) {
      require MIME::Base64;
      my $png_data = Mojo::File->new($logo_path)->slurp;
      my $base64 = MIME::Base64::encode_base64($png_data, '');
      $logo_data_uri = "data:image/png;base64,$base64";
    }

    return $c->qr_svg($url,
      size => $params{size} || 200,
      logo_image => $logo_data_uri,
      logo_ratio => 0.25,
    );
  });

}


1;

=head1 NAME

Samizdat::Plugin::Swish - Swish mobile payment integration plugin

=head1 SYNOPSIS

  # In your application
  $app->plugin('Swish');

  # Use the model helper
  my $swish = $c->swish;

  # In a template - generate payment button container
  <%== swishbutton %>

  # In page JavaScript - initialize Swish button
  <% $web->{script} = swishbutton_script(); %>

  # Or use REST API directly in Perl
  my $payment = $c->swish->create_payment(
    amount => 10000,
    payer_alias => '46701234567',
    message => 'Order #123',
    callback_url => $c->url_for('swish_callback')->to_abs,
  );

=head1 DESCRIPTION

This plugin integrates Swish mobile payment functionality into Samizdat, including:

=over 4

=item * mTLS certificate authentication

=item * E-commerce flow (phone number push notification)

=item * M-commerce flow (QR code / app link)

=item * Callback handling for payment status updates

=item * Refund support

=item * Helper for accessing the Swish model

=item * Helpers for generating payment button HTML and JavaScript

=back

=head1 ROUTES

The plugin registers the following routes:

=head2 Public Routes

=over 4

=item * POST /swish/callback - Callback endpoint for Swish notifications

=item * GET /swish/success - Success return URL

=item * GET /swish/cancel - Cancel return URL

=item * GET /swish/config - Get client configuration (JSON)

=item * POST /swish/payments/create - Create payment request (JSON)

=item * GET /swish/payments/:id - Get payment status (JSON)

=item * POST /swish/refunds/create - Create refund request (JSON)

=back

=head2 Manager Routes

=over 4

=item * GET /manager/swish - Swish payments panel

=back

=head1 HELPERS

=head2 swish

Returns the L<Samizdat::Model::Swish> instance.

  my $swish = $c->swish;
  my $payment = $swish->create_payment(amount => 10000);

=head2 swishbutton

Generates an HTML container for the Swish payment button.

  my $button_html = $c->swishbutton(
    amount => 10000,
    message => 'Order #123',
  );

=head2 swishbutton_script

Returns JavaScript code for initializing the Swish payment button.

  $web->{script} = $c->swishbutton_script();

=head2 swish_qr_url

Generate a Swish app URL from a payment token.

  my $url = $c->swish_qr_url($token);

=head1 CONFIGURATION

Configure in samizdat.yml under manager.swish:

  swish:
    cardnumber: 18
    dbtype: postgresql
    currency: SEK
    default_env: test
    payee_alias: '1231181189'
    cert:
      client_cert: /path/to/swish_client.pem
      client_key: /path/to/swish_client.key
      ca_cert: /path/to/swish_ca.pem
    env:
      test:
        api: https://mss.cpc.getswish.net/swish-cpcapi/api/v2
      production:
        api: https://cpc.getswish.net/swish-cpcapi/api/v2

=head1 PAYMENT FLOWS

=head2 E-commerce

1. User enters phone number
2. POST to /swish/payments/create with payer_alias
3. Swish sends push notification to user's phone
4. User opens Swish app and confirms payment
5. Swish sends callback to /swish/callback
6. Payment status updated

=head2 M-commerce

1. POST to /swish/payments/create without payer_alias
2. Response includes payment_request_token
3. Display QR code or redirect to Swish app
4. User scans QR or opens app link
5. User confirms payment in Swish app
6. Swish sends callback to /swish/callback
7. Payment status updated

=head1 SEE ALSO

L<Samizdat::Model::Swish>, L<Samizdat::Controller::Swish>

Swish Developer Documentation: L<https://developer.swish.nu/>

=cut

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for Swish API
paths:
  /swish:
    get:
      operationId: Swish.index
      x-mojo-to: Swish#index
      summary: Swish payments panel
      tags: [Swish]
      responses:
        '200':
          description: Payment statistics and recent payments
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Swish_IndexResponse'

  /swish/config:
    get:
      operationId: Swish.config
      x-mojo-to: Swish#swish_config
      summary: Get Swish client configuration
      tags: [Swish]
      responses:
        '200':
          description: Swish configuration
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Swish_ConfigResponse'

  /swish/payments/create:
    post:
      operationId: Swish.payments.create
      x-mojo-to: Swish#create_payment
      summary: Create payment request
      tags: [Swish]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Swish_PaymentInput'
      responses:
        '201':
          description: Payment created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Swish_Payment'

  /swish/payments/{id}:
    get:
      operationId: Swish.payments.get
      x-mojo-to: Swish#get_payment
      summary: Get payment status
      tags: [Swish]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Payment details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Swish_Payment'

  /swish/refunds/create:
    post:
      operationId: Swish.refunds.create
      x-mojo-to: Swish#create_refund
      summary: Create refund request
      tags: [Swish]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Swish_RefundInput'
      responses:
        '201':
          description: Refund created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Swish_Refund'

  /swish/callback:
    post:
      operationId: Swish.callback
      x-mojo-to: Swish#callback
      summary: Swish callback endpoint
      tags: [Swish]
      requestBody:
        content:
          application/json:
            schema:
              type: object
      responses:
        '200':
          description: Callback processed
          content:
            text/plain:
              schema:
                type: string

  /swish/success:
    get:
      operationId: Swish.success
      x-mojo-to: Swish#success
      summary: Payment success return URL
      tags: [Swish]
      parameters:
        - name: id
          in: query
          schema:
            type: string
      responses:
        '200':
          description: Payment successful
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Swish_SuccessResponse'

  /swish/cancel:
    get:
      operationId: Swish.cancel
      x-mojo-to: Swish#cancel
      summary: Payment cancel return URL
      tags: [Swish]
      responses:
        '200':
          description: Payment cancelled
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Swish_CancelResponse'

  /swish/qr:
    get:
      operationId: Swish.qr
      x-mojo-to: Swish#qr
      summary: Generate Swish QR code SVG
      tags: [Swish]
      parameters:
        - name: payee
          in: query
          schema:
            type: string
          description: Payee alias (phone number)
        - name: amount
          in: query
          schema:
            type: integer
          description: Amount in ore (smallest currency unit)
        - name: message
          in: query
          schema:
            type: string
          description: Payment message
      responses:
        '200':
          description: SVG QR code
          content:
            image/svg+xml:
              schema:
                type: string

components:
  schemas:
    Swish_ConfigResponse:
      type: object
      properties:
        currency:
          type: string
        env:
          type: string
        payee_alias:
          type: string
    Swish_PaymentInput:
      type: object
      properties:
        amount:
          type: integer
          description: Amount in ore (smallest currency unit)
        customerid:
          type: integer
        payer_alias:
          type: string
          description: Phone number for e-commerce flow
        message:
          type: string
          maxLength: 50
        reference:
          type: string
        callback_url:
          type: string
        custom_data:
          type: object
      required:
        - amount
    Swish_Payment:
      type: object
      properties:
        instruction_id:
          type: string
        status:
          type: string
          enum: [CREATED, PAID, DECLINED, ERROR, CANCELLED]
        flow_type:
          type: string
          enum: [ecommerce, mcommerce]
        payment_request_token:
          type: string
        swish_url:
          type: string
        payer_alias:
          type: string
        payer_name:
          type: string
        amount:
          type: integer
        message:
          type: string
        created_at:
          type: string
        error:
          type: boolean
        error_message:
          type: string
    Swish_RefundInput:
      type: object
      properties:
        original_payment_reference:
          type: string
        amount:
          type: integer
        message:
          type: string
        reference:
          type: string
        callback_url:
          type: string
      required:
        - original_payment_reference
        - amount
    Swish_Refund:
      type: object
      properties:
        instruction_id:
          type: string
        status:
          type: string
        error:
          type: boolean
        error_message:
          type: string
    Swish_SuccessResponse:
      type: object
      properties:
        success:
          type: boolean
    Swish_CancelResponse:
      type: object
      properties:
        cancelled:
          type: boolean
    Swish_Stats:
      type: object
      properties:
        total_paid:
          type: number
        count_paid:
          type: integer
        total_pending:
          type: number
        count_pending:
          type: integer
        total_declined:
          type: number
        count_declined:
          type: integer
        total_error:
          type: number
        count_error:
          type: integer
    Swish_IndexResponse:
      type: object
      properties:
        success:
          type: boolean
        payments:
          type: array
          items:
            $ref: '#/components/schemas/Swish_Payment'
        stats:
          $ref: '#/components/schemas/Swish_Stats'
