package Samizdat::Plugin::Invoice;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Invoice;
use Mojo::Home;
use Mojo::File;
use Mojo::Template;
use Mojo::Loader qw(data_section);
use Data::Dumper;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  # Store OpenAPI fragment (parsed centrally in _load_openapi)
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Invoice} = $openapi_yaml if $openapi_yaml;

  # Customer specific invoice routes (HTML pages only - GET)
  my $customer = $r->manager('customers/:customerid/invoices')->to(controller => 'Invoice');
  $customer->get('open')                                            ->to('#edit')                 ->name('invoice_edit');
  $customer->get('/:invoiceid')                                     ->to('#handle')               ->name('invoice_customer_handle');
  $customer->get('/:invoiceid/payment')                             ->to('#payment')              ->name('invoice_payment');
  $customer->get('/:invoiceid/remind')                              ->to('#remind')               ->name('invoice_remind');
  $customer->get('/')                                               ->to('#index')                ->name('invoice_customer_index');

  # Invoice root routes (HTML pages, can be cached)
  my $manager = $r->manager('invoices')->to(controller => 'Invoice');
  $manager->get('/open')                                            ->to('#open')                 ->name('invoice_open');
  $manager->get('/payment-modal')                                   ->to('#paymentModal')         ->name('invoice_payment_modal');
  $manager->get('/:invoiceid')                                      ->to('#handle')               ->name('invoice_handle');
  # PUT /invoices/{invoiceid} is defined in OpenAPI spec (operationId: Invoice.update)
  $manager->get('/')                                                ->to('#index')                ->name('invoice_index');

  # Customer specific product routes
  my $products = $r->manager('customers/:customerid/products')->to(controller => 'Invoice');
  $products->get('/subscribe')                                      ->to('Customer#products');


  $app->helper(invoice => sub ($self) {
    state $model = Samizdat::Model::Invoice->new({
      config   => $self->config->{manager}->{invoice},
      pg       => $self->app->pg,
      mysql    => $self->app->mysql,
      customer => $self->app->customer,  # Pass customer helper
    });
    return $model;
  });


  # Helper for PDF generation from LaTeX
  $app->helper(
    generate_pdf_from_tex => sub($self, $tex, $uuid) {
      my $config = $self->app->config;
      my $texpath = Mojo::Home->new()->rel_file(sprintf('src/tmp/%s.tex', $uuid));
      my $pdfpath = Mojo::File->new(sprintf('%s/%s.pdf',
        $config->{manager}->{invoice}->{invoicedir},
        $uuid)
      );

      # Ensure temp directory exists
      $texpath->dirname->make_path unless -d $texpath->dirname;

      $texpath->spew($tex);

      # Clean up any previous compilation artifacts for this specific tex file
      my $basename = $texpath->basename('.tex');
      for my $ext (qw(aux log fls fdb_latexmk pdf)) {
        my $file = $texpath->dirname->child("$basename.$ext");
        $file->remove if -e $file;
      }

      my $command = [
        'latexmk',
        '-pdf',
        sprintf('-auxdir=%s', $texpath->dirname),
        '-interaction=nonstopmode',
        '-silent',
        sprintf('-outdir=%s', $texpath->dirname),
        $texpath->to_string
      ];
      system(@{$command});

      $texpath->dirname->rel_file(sprintf('%s.pdf', $uuid))->move_to($pdfpath);
      my $pdf = $pdfpath->slurp || 0;
      if (!$config->{test}->{invoice}) {
        $texpath->dirname->remove_tree({ keep_root => 1 });
      }
      return $pdf;
    }
  );


  # Helper to escape text for LaTeX
  $app->helper(
    tex_escape => sub($self, $text) {
      return '' unless defined $text;

      # Make a copy if passed by reference
      my $escaped = ref $text ? $$text : $text;

      # Escape LaTeX special characters
      $escaped =~ s/\\/\\textbackslash{}/g;
      $escaped =~ s/\{/\\\{/g;
      $escaped =~ s/\}/\\\}/g;
      $escaped =~ s/\$/\\\$/g;
      $escaped =~ s/\&/\\\&/g;
      $escaped =~ s/\#/\\\#/g;
      $escaped =~ s/\_/\\\_/g;
      $escaped =~ s/\%/\\\%/g;
      $escaped =~ s/\^/\\textasciicircum{}/g;
      $escaped =~ s/\~/\\textasciitilde{}/g;

      # Update reference if passed
      if (ref $text) {
        $$text = $escaped;
      }

      return $escaped;
    }
  );

  # Helper to convert HTML to plain text
  $app->helper(
    html_to_text => sub($self, $html) {
      return '' unless $html;

      require HTML::FormatText;
      require HTML::TreeBuilder;

      # Parse HTML
      my $tree = HTML::TreeBuilder->new();
      $tree->parse($html);
      $tree->eof();

      # Convert to text with formatting options
      my $formatter = HTML::FormatText->new(
        leftmargin => 0,
        rightmargin => 72
      );
      my $text = $formatter->format($tree);
      $tree->delete();

      # Clean up excessive whitespace
      $text =~ s/\n{3,}/\n\n/g;  # Max 2 newlines
      $text =~ s/^\s+|\s+$//g;   # Trim start and end

      return $text;
    }
  );

  # Helper to send invoice email
  $app->helper(
    send_invoice_email => sub($self, $invoicedata, $options = {}) {
      require MIME::Lite;
      require Mojo::Util;

      my $config = $self->app->config;

      # Clean language variant suffixes (_XX) from billinglang
      $invoicedata->{customer}->{billinglang} =~ s/_[A-Z]{2}$// if $invoicedata->{customer}->{billinglang};
      $self->language($invoicedata->{customer}->{billinglang} || $config->{locale}->{default_language});

      my $action = $options->{action} || 'send';

      # Add logo if not present
      if (!$invoicedata->{svglogotype}) {
        my $logo_path = Mojo::Home->new()->child('src/public/' . $config->{logotype});
        if (-e $logo_path) {
          my $svg = $logo_path->slurp;
          $svg = Mojo::Util::b64_encode($svg);
          $svg =~ s/[\r\n\s]+//g;
          chomp $svg;
          $invoicedata->{svglogotype} = $svg;
        }
      }

      # Render email templates
      my ($htmldata, $txtdata);

      # Add custom message if provided
      my $message = $options->{message} || '';

      # Ensure VAT percentage is set in invoice data
      if (!exists $invoicedata->{vat}) {
        # Try to get VAT from invoice or customer
        my $vat_decimal = $invoicedata->{invoice}->{vat} || $invoicedata->{customer}->{vat} || 0.25;
        $invoicedata->{vat} = $self->invoice->formatvat($vat_decimal);
      }

      # Use different templates based on action
      if ($invoicedata->{invoice}->{kreditfakturaavser} || $action eq 'credit') {
        $htmldata = $self->render_mail(template => 'invoice/credit/mailhtml', layout => 'default', invoicedata => $invoicedata);
      } elsif ($action eq 'reminder' || $action eq 'reminder_mild' || $action eq 'reminder_tough') {
        # For reminders, just render the message with the default layout
        $htmldata = $self->render_mail(template => 'invoice/remind/message', layout => 'default', message => $message);
      } else {
        $htmldata = $self->render_mail(template => 'invoice/create/mailhtml', layout => 'default', invoicedata => $invoicedata);
      }

      # Always convert HTML to text for plain text version
      $txtdata = $self->html_to_text($htmldata);

      # Set subject based on action
      my $subject;

      # Try to use localization if in app context, otherwise use simple strings
      if ($action eq 'credit') {
        $subject = $self->app->__x('Credited invoice: {number}',
          number => $invoicedata->{invoice}->{kreditfakturaavser});
      } elsif ($action eq 'reminder' || $action eq 'reminder_mild') {
        $subject = $self->app->__x('Payment reminder: Invoice {number}',
          number => $invoicedata->{invoice}->{fakturanummer});
      } elsif ($action eq 'reminder_tough') {
        $subject = $self->app->__x('Final payment reminder - Invoice {number}',
          number => $invoicedata->{invoice}->{fakturanummer});
      } else {
        $subject = $self->app->__x('Invoice {number}',
          number => $invoicedata->{invoice}->{fakturanummer});
      }

      # Determine recipient email
      # For snailmail customers, send to accountant instead of customer
      my $is_snailmail = ($invoicedata->{customer}->{invoicetype} // '') eq 'snailmail';
      my $to_email;

      if ($config->{test}->{invoice}) {
        $to_email = $config->{mail}->{to};
      } elsif ($is_snailmail) {
        # For snailmail: send to accountant (they need to print it)
        $to_email = $config->{mail}->{from};
      } else {
        # Regular email invoice: send to customer
        $to_email = $invoicedata->{customer}->{billingemail};
      }

      # Create email
      my $mail = MIME::Lite->new(
        From         => $config->{mail}->{from},
        Bcc          => $config->{test}->{invoice} || $is_snailmail ? undef : $config->{mail}->{from},
        To           => $to_email,
        Organization => Encode::encode("MIME-Q", $config->{organization}),
        Subject      => Encode::encode("MIME-Q", $subject),
        'X-Mailer'   => "Samizdat",
        Type         => 'multipart/mixed',
      );

      # Attach plain text and html variants
      my $alternative = MIME::Lite->new(Type => 'multipart/alternative');
      $alternative->attach(Data => $txtdata, Type => 'text/plain; charset=UTF-8');
      $alternative->attach(Data => $htmldata, Type => 'text/html; charset=UTF-8');
      $mail->attach($alternative);

      # Attach PDF if it exists
      if ($invoicedata->{invoice}->{uuid}) {
        my $pdf_path = sprintf('%s/%s.pdf', $config->{manager}->{invoice}->{invoicedir}, $invoicedata->{invoice}->{uuid});
        $mail->attach(
          Path        => $pdf_path,
          Filename    => sprintf('%s.pdf', $invoicedata->{invoice}->{uuid}),
          Type        => 'application/pdf',
          Disposition => 'attachment'
        );
      }

      # Send email
      eval {
        $mail->send($config->{mail}->{how}, @{$config->{mail}->{howargs}});
      };

      if ($@) {
        return { success => 0, error => $@ };
      }

      return { success => 1 };
    }
  );


  # Helper to process invoice (fetch data → escape → tex → pdf)
  # Enhanced to handle both reprint and create operations with obehandlad state
  $app->helper(
    process_invoice => sub($self, $invoiceid = 0, $customerid = undef, $options = {}) {
      require Mojo::Util;
      require Date::Format;

      # Determine operation mode
      my $is_create = $options->{create} || 0;
      my $is_credit = $options->{credit} || 0;
      my $original_invoiceid = $options->{original_invoiceid};

      # Handle credit invoice creation
      if ($is_credit && $original_invoiceid) {
        # Get original invoice
        my $original_invoice = $self->invoice->get({
          where => { invoiceid => $original_invoiceid }
        })->[0];
        return { error => 'Original invoice not found', status => 404 } unless $original_invoice;

        # Get customer data but override with original invoice's currency and VAT
        my $customer = $self->customer->get({
          where => { customerid => $original_invoice->{customerid} }
        })->[0];
        return { error => 'Customer not found', status => 404 } unless $customer;

        # Use original invoice's currency and VAT for the credit invoice
        $customer->{currency} = $original_invoice->{currency};
        $customer->{vat} = $original_invoice->{vat};

        # Create new invoice for credit with original invoice's currency and VAT
        my $credit_invoiceid = $self->invoice->addinvoice($customer);

        # Copy all items from original invoice
        my $original_items = $self->invoice->invoiceitems({
          where => { 'invoice.invoiceid' => $original_invoiceid }
        });
        for my $itemid (keys %{$original_items}) {
          my $item = $original_items->{$itemid};
          # Copy item to credit invoice (don't negate - the invoice state handles that)
          $item->{invoiceid} = $credit_invoiceid;
          delete $item->{invoiceitemid};
          $self->invoice->addinvoiceitem($item, $credit_invoiceid);
        }

        # Process the credit invoice with the original invoice number
        my $result = $self->process_invoice($credit_invoiceid, $original_invoice->{customerid}, {
          create => 1,
          credit => 1,
          credited_invoice => $original_invoice->{fakturanummer}
        });

        if ($result->{error}) {
          return $result;
        }

        # Mark original invoice as credited (state = 'raderad')
        $self->invoice->updateinvoice($original_invoiceid, { state => 'raderad' });

        # Get the updated credit invoice with kreditfakturaavser
        my $credit_invoice = $self->invoice->get({ where => { invoiceid => $credit_invoiceid } })->[0];
        $result->{invoice} = $credit_invoice;

        return $result;
      }

      # Fetch data from database
      my $invoice;
      if (!$invoiceid && $customerid) {
        # If no invoiceid, fetch the obehandlad (unprocessed) invoice for the customer
        $invoice = $self->invoice->get({
          where => { state => 'obehandlad', customerid => $customerid }
        })->[0];
      } else {
        # Fetch specific invoice by ID
        $invoice = $self->invoice->get({
          where => { invoiceid => $invoiceid }
        })->[0];
      }
      return { error => 'Invoice not found', status => 404 } unless $invoice;

      $customerid ||= $invoice->{customerid};
      my $customer = $self->customer->get({
        where => { customerid => $customerid }
      })->[0];
      return { error => 'Customer not found', status => 404 } unless $customer;

      # Get customer name
      $customer->{name} = $self->customer->name($customer);

      # Get invoice items
      my $invoiceitems = $self->invoice->invoiceitems({
        where => { 'invoice.invoiceid' => $invoice->{invoiceid} }
      });

      # Check if there are invoice items
      return { error => 'No invoice items', status => 400 } if (!$invoiceitems || keys %{$invoiceitems} < 1);

      # Ensure invoice uses customer's VAT and currency (customer is source of truth)
      # Exceptions:
      # 1. For already-issued invoices (fakturerad, bokford, raderad, krediterad),
      #    use the VAT/currency from the invoice record to maintain historical accuracy
      # 2. For credit invoices, use the VAT/currency already set in the invoice record
      #    (which was copied from the original invoice being credited)
      if ($invoice->{state} eq 'obehandlad' && !$is_credit) {
        $invoice->{vat} = $customer->{vat};
        $invoice->{currency} = $customer->{currency};
      }

      # Set language based on customer billing language preference
      $customer->{billinglang} =~ s/_[A-Z]{2}$// if $customer->{billinglang};
      $self->language($customer->{billinglang} || $self->app->config->{locale}->{default_language} || 'sv');

      # Handle obehandlad state - assign invoice number and dates
      if ($invoice->{state} eq 'obehandlad' && $is_create) {
        # Get next invoice number
        my $nextnumber = $self->invoice->nextnumber;
        $invoice->{fakturanummer} = $nextnumber;

        # Generate UUID
        require UUID;
        my $uuid = sprintf('%s_%s_%s',
          $nextnumber,
          $customer->{customerid},
          UUID::uuid()
        );
        $invoice->{uuid} = $uuid;

        # Set invoice date and due date
        $invoice->{invoicedate} = sprintf('%4d-%02d-%02d %02d:%02d:%02d',
          (localtime(time))[5] + 1900,
          (localtime(time))[4] + 1,
          (localtime(time))[3],
          (localtime(time))[2],
          (localtime(time))[1],
          (localtime(time))[0]
        );

        my $duedays = $self->config->{manager}->{invoice}->{duedays} || 30;
        $invoice->{duedate} = Date::Format::time2str("%Y-%m-%d", time + $duedays*24*3600, 'CET');
        $invoice->{pdfdate} = Date::Format::time2str("%Y%m%d%H%M%S", time, 'CET');

        # Set kreditfakturaavser for credit invoices
        if ($is_credit && $options->{credited_invoice}) {
          $invoice->{kreditfakturaavser} = $options->{credited_invoice};
        }
      }

      # Set title for all invoices (not just obehandlad)
      if (!$invoice->{title} && $invoice->{fakturanummer}) {
        # Check if this is a credit invoice
        if ($invoice->{kreditfakturaavser} || $invoice->{state} eq 'krediterad' || $is_credit) {
          $invoice->{title} = $self->__x('Credit invoice {number}', number => $invoice->{fakturanummer});
        } else {
          $invoice->{title} = $self->__x('Invoice {number}', number => $invoice->{fakturanummer});
        }
      }

      # Escape customer fields for LaTeX first (but not billingcity yet if Swedish)
      my $is_swedish = ('SE' eq uc($customer->{billingcountry} || ''));

      for my $field (qw(company firstname lastname address billingaddress city lang)) {
        if ($customer->{$field}) {
          $customer->{$field} = $self->tex_escape($customer->{$field});
        }
      }

      # Escape billingcity only if not Swedish (Swedish formatting comes after)
      if (!$is_swedish && $customer->{billingcity}) {
        $customer->{billingcity} = $self->tex_escape($customer->{billingcity});
      }

      # Format Swedish postal code and city after other escaping
      if ($is_swedish) {
        # First escape the city name
        if ($customer->{billingcity}) {
          $customer->{billingcity} = $self->tex_escape($customer->{billingcity});
        }

        # Then format the postal code
        $customer->{billingzip} =~ s/\s+//g if $customer->{billingzip};
        if ($customer->{billingzip} && length($customer->{billingzip}) >= 5) {
          $customer->{billingzip} = sprintf('%s\ %s',
            substr($customer->{billingzip}, 0, 3),
            substr($customer->{billingzip}, 3, 2)
          );
        }
        # Add LaTeX double space before city (after escaping)
        $customer->{billingcity} = '\ \ ' . $customer->{billingcity} if $customer->{billingcity};
      }

      # Process invoice items - validate and escape
      for my $itemid (keys %$invoiceitems) {
        my $item = $invoiceitems->{$itemid};

        # Skip items not included
        next unless $item->{include};

        # Escape description for LaTeX
        my $description = $item->{invoiceitemtext} || $item->{description} || '';
        $item->{invoiceitemtext} = $self->tex_escape($description);
        # Handle double dashes after escaping to avoid issues with IDN domains like xn--t-1ga.se
        $item->{invoiceitemtext} =~ s/--/-\\mbox{}-/g;
      }

      # Calculate all invoice amounts using model method
      my $amounts = $self->invoice->calculate_amounts(
        $invoiceitems,
        $invoice->{vat},
        $invoice->{currency}
      );

      # Update invoice with calculated amounts
      $invoice->{net_amount} = $amounts->{net_amount};
      $invoice->{vatcost} = $amounts->{vatcost};
      $invoice->{totalcost} = $amounts->{totalcost};
      $invoice->{diff} = $amounts->{diff};

      # Remove non-included items from the hash - they'll be handled later
      my $unincluded_items = {};
      for my $itemid (keys %$invoiceitems) {
        unless ($invoiceitems->{$itemid}->{include}) {
          $unincluded_items->{$itemid} = delete $invoiceitems->{$itemid};
        }
      }

      # Check if we have any included items - can't create invoice without items
      if (!keys %$invoiceitems && $is_create) {
        return { error => 'No items selected for invoice', status => 400 };
      }

      # Prepare formdata for template (now only has included items)
      my $formdata = {
        invoice => $invoice,
        customer => $customer,
        invoiceitems => $invoiceitems,
        vat => $amounts->{vat_percent},
        unincluded_items => $unincluded_items,  # Keep track for later processing
      };

      # Set formdata in stash for template access
      $self->stash(formdata => $formdata);

      # Render LaTeX template with layout
      my $tex = $self->render_to_string(format => 'tex', template => 'invoice/create/index');

      # Encode and generate PDF
      $tex = Mojo::Util::encode('UTF-8', $tex);
      my $pdf = $self->generate_pdf_from_tex($tex, $invoice->{uuid});

      # Update database if creating from obehandlad
      if ($invoice->{state} eq 'obehandlad' && $is_create) {
        # Update invoice state and metadata
        my $update_data = {
          fakturanummer => $invoice->{fakturanummer},
          uuid => $invoice->{uuid},
          invoicedate => $invoice->{invoicedate},
          duedate => $invoice->{duedate},
          totalcost => ($invoice->{totalcost} =~ s/\,/./r),
          debt => ($invoice->{totalcost} =~ s/\,/./r),
          state => $is_credit ? 'raderad' : 'fakturerad',
        };

        if ($is_credit && $options->{credited_invoice}) {
          $update_data->{kreditfakturaavser} = $options->{credited_invoice};
        }
        $self->invoice->updateinvoice($invoice->{invoiceid}, $update_data);

        # If not a credit invoice, update subscription dates for included items
        if (!$is_credit) {
          for my $itemid (keys %$invoiceitems) {
            my $item = $invoiceitems->{$itemid};
            if ($item->{include} && $item->{productid}) {
              $self->invoice->updatesubscription($customerid, $item->{productid});
            }
          }

          # Create new open invoice for unincluded items if needed
          if ($options->{handle_unincluded}) {
            # Use the unincluded items we already identified
            my $unincluded_items = $formdata->{unincluded_items} || {};

            if (keys %$unincluded_items) {
              # Create new invoice and move unincluded items to it
              my $newinvoiceid = $self->invoice->addinvoice($customer);
              for my $itemid (keys %$unincluded_items) {
                $self->invoice->updateinvoiceitem($itemid, { invoiceid => $newinvoiceid });
              }
            } else {
              # No unincluded items - create empty obehandlad invoice for future use
              $self->invoice->addinvoice($customer);
            }
          }
        }
      }

      return {
        success => 1,
        pdf => $pdf,
        invoice => $invoice,
        customer => $customer,
        formdata => $formdata
      };
    }
  );
}

=head1 NAME

Samizdat::Plugin::Invoice - Invoice management plugin

=head1 DESCRIPTION

This plugin provides invoice management functionality including creating,
viewing, paying, and reminding invoices. It supports both customer-specific
and global invoice routes.

=head1 NGINX CONFIGURATION

Invoice routes use nested dynamic parameters (C<:customerid> and C<:invoiceid>).
The controller sets C<docpath> to ensure shared cached templates.

=head2 Regex Routes

    # Customer invoices list
    location ~ ^/manager/customers/\d+/invoices/?$ {
        root /path/to/public;
        try_files /manager/customers/invoices/index.html @backend;
    }

    # Customer open invoice editor
    location ~ ^/manager/customers/\d+/invoices/open$ {
        root /path/to/public;
        try_files /manager/customers/invoices/open/index.html @backend;
    }

    # Customer specific invoice
    location ~ ^/manager/customers/\d+/invoices/\d+$ {
        root /path/to/public;
        try_files /manager/customers/invoices/handle/index.html @backend;
    }

    # Invoice payment page
    location ~ ^/manager/customers/\d+/invoices/\d+/payment$ {
        root /path/to/public;
        try_files /manager/customers/invoices/payment/index.html @backend;
    }

    # Invoice reminder page
    location ~ ^/manager/customers/\d+/invoices/\d+/remind$ {
        root /path/to/public;
        try_files /manager/customers/invoices/remind/index.html @backend;
    }

    # Global invoice routes
    location ~ ^/manager/invoices/\d+$ {
        root /path/to/public;
        try_files /manager/invoices/handle/index.html @backend;
    }

    location @backend {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

=head1 SEE ALSO

L<Samizdat::Controller::Invoice>, L<Samizdat::Model::Invoice>

=cut

1;

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for Invoice API
# This is merged with other plugin fragments in the main app
paths:
  /invoices/open:
    get:
      operationId: Invoice.open
      x-mojo-to: Invoice#open
      summary: List open (unhandled) invoices
      tags: [Invoices]
      responses:
        '200':
          description: Open invoices grouped by customer
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Invoice_OpenInvoicesResponse'

  /invoices/{invoiceid}/{to}:
    get:
      operationId: Invoice.nav
      x-mojo-to: Invoice#nav
      summary: Navigate to previous or next invoice
      tags: [Invoices]
      parameters:
        - name: invoiceid
          in: path
          required: true
          schema:
            type: integer
        - name: to
          in: path
          required: true
          schema:
            type: string
            enum: [prev, next]
      responses:
        '200':
          description: Invoice data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Invoice_FormData'

  /invoices/{invoiceid}:
    get:
      operationId: Invoice.get
      x-mojo-to: Invoice#handle
      summary: Get invoice by ID
      tags: [Invoices]
      parameters:
        - name: invoiceid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Invoice data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Invoice_FormData'
    put:
      operationId: Invoice.update
      x-mojo-to: Invoice#updateSimple
      summary: Update invoice fields
      tags: [Invoices]
      parameters:
        - name: invoiceid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        required: true
        content:
          application/x-www-form-urlencoded:
            schema:
              type: object
              properties:
                field:
                  type: string
                  description: Field name to update
                value:
                  type: string
                  description: New value for the field
      responses:
        '200':
          description: Update successful
          content:
            application/json:
              schema:
                type: object
                properties:
                  success:
                    type: boolean
                  message:
                    type: string

  /invoices:
    get:
      operationId: Invoice.index
      x-mojo-to: Invoice#index
      summary: List all invoices
      tags: [Invoices]
      parameters:
        - name: customerid
          in: query
          schema:
            type: integer
        - name: paid
          in: query
          schema:
            type: integer
        - name: unpaid
          in: query
          schema:
            type: integer
        - name: destroyed
          in: query
          schema:
            type: integer
      responses:
        '200':
          description: List of invoices
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Invoice_ListResponse'

  /customers/{customerid}/invoices/open:
    get:
      operationId: Invoice.customer.open
      x-mojo-to: Invoice#edit
      summary: Get customer's open invoice
      tags: [Customer Invoices]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Open invoice form data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Invoice_FormData'
    put:
      operationId: Invoice.customer.update
      x-mojo-to: Invoice#update
      summary: Update customer's open invoice
      tags: [Customer Invoices]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/x-www-form-urlencoded:
            schema:
              type: object
      responses:
        '200':
          description: Updated invoice data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Invoice_FormData'
    post:
      operationId: Invoice.customer.create
      x-mojo-to: Invoice#create
      summary: Create invoice from open invoice
      tags: [Customer Invoices]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/x-www-form-urlencoded:
            schema:
              type: object
      responses:
        '200':
          description: Created invoice
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Invoice_CreateResponse'
            application/pdf:
              schema:
                type: string
                format: binary

  /customers/{customerid}/invoices/{invoiceid}:
    get:
      operationId: Invoice.customer.get
      x-mojo-to: Invoice#handle
      summary: Get customer's specific invoice
      tags: [Customer Invoices]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
        - name: invoiceid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Invoice data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Invoice_FormData'

  /customers/{customerid}/invoices/{invoiceid}/{to}:
    get:
      operationId: Invoice.customer.nav
      x-mojo-to: Invoice#nav
      summary: Navigate to prev/next invoice for customer
      tags: [Customer Invoices]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
        - name: invoiceid
          in: path
          required: true
          schema:
            type: integer
        - name: to
          in: path
          required: true
          schema:
            type: string
            enum: [prev, next]
      responses:
        '200':
          description: Invoice data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Invoice_FormData'

  /customers/{customerid}/invoices/{invoiceid}/creditinvoice:
    post:
      operationId: Invoice.customer.credit
      x-mojo-to: Invoice#creditinvoice
      summary: Create credit invoice
      tags: [Customer Invoices]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
        - name: invoiceid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '302':
          description: Redirect to credit invoice

  /customers/{customerid}/invoices/{invoiceid}/payment:
    post:
      operationId: Invoice.customer.payment
      x-mojo-to: Invoice#payment
      summary: Mark invoice payment
      tags: [Customer Invoices]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
        - name: invoiceid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Payment marked
          content:
            application/json:
              schema:
                type: object

  /customers/{customerid}/invoices/{invoiceid}/remind:
    post:
      operationId: Invoice.customer.remind
      x-mojo-to: Invoice#remind
      summary: Send payment reminder
      tags: [Customer Invoices]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
        - name: invoiceid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/x-www-form-urlencoded:
            schema:
              type: object
              properties:
                type:
                  type: string
                  enum: [mild, tough]
                mailmessage:
                  type: string
      responses:
        '200':
          description: Reminder sent
          content:
            application/json:
              schema:
                type: object

  /customers/{customerid}/invoices/{invoiceid}/resend:
    post:
      operationId: Invoice.customer.resend
      x-mojo-to: Invoice#resend
      summary: Resend invoice email
      tags: [Customer Invoices]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
        - name: invoiceid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Invoice resent
          content:
            application/json:
              schema:
                type: object

  /customers/{customerid}/invoices/{invoiceid}/reprint:
    post:
      operationId: Invoice.customer.reprint
      x-mojo-to: Invoice#reprint
      summary: Reprint invoice PDF
      tags: [Customer Invoices]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
        - name: invoiceid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Invoice reprinted
          content:
            application/json:
              schema:
                type: object

  /customers/{customerid}/invoices:
    get:
      operationId: Invoice.customer.list
      x-mojo-to: Invoice#index
      summary: List customer's invoices
      tags: [Customer Invoices]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Customer invoice list
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Invoice_ListResponse'
    post:
      operationId: Invoice.customer.subscribe
      x-mojo-to: Customer#subscribe
      summary: Subscribe customer to products
      tags: [Customer Invoices]
      parameters:
        - name: customerid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Subscription created
          content:
            application/json:
              schema:
                type: object

components:
  schemas:
    Invoice_Error:
      type: object
      properties:
        error:
          type: string
    Invoice_Invoice:
      type: object
      properties:
        invoiceid:
          type: integer
        customerid:
          type: integer
        fakturanummer:
          type: integer
        uuid:
          type: string
        state:
          type: string
          enum: [obehandlad, fakturerad, bokford, raderad, krediterad]
        invoicedate:
          type: string
        duedate:
          type: string
        totalcost:
          type: number
        debt:
          type: number
        currency:
          type: string
        vat:
          type: number
    Invoice_Customer:
      type: object
      properties:
        customerid:
          type: integer
        name:
          type: string
        billingemail:
          type: string
        billingaddress:
          type: string
        billingzip:
          type: string
        billingcity:
          type: string
        billingcountry:
          type: string
        currency:
          type: string
        vat:
          type: number
    Invoice_Item:
      type: object
      properties:
        invoiceitemid:
          type: integer
        invoiceid:
          type: integer
        articlenumber:
          type: string
        invoiceitemtext:
          type: string
        number:
          type: number
        price:
          type: number
        include:
          type: integer
        vat:
          type: number
    Invoice_FormData:
      type: object
      properties:
        invoice:
          $ref: '#/components/schemas/Invoice_Invoice'
        customer:
          $ref: '#/components/schemas/Invoice_Customer'
        invoiceitems:
          type: object
        articles:
          type: array
          items:
            type: object
    Invoice_OpenInvoicesResponse:
      type: object
      properties:
        customers:
          type: object
    Invoice_ListResponse:
      type: object
      properties:
        customer:
          $ref: '#/components/schemas/Invoice_Customer'
        invoices:
          type: array
          items:
            $ref: '#/components/schemas/Invoice_Invoice'
    Invoice_CreateResponse:
      type: object
      properties:
        success:
          type: integer
        invoiceid:
          type: integer
        fakturanummer:
          type: integer
        uuid:
          type: string
        customerid:
          type: integer
        print_dialog:
          type: integer
