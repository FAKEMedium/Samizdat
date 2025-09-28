package Samizdat::Command::invoice;

use Mojo::Base 'Mojolicious::Command', -signatures;
use Mojo::Util qw(getopt encode decode);
use Mojo::Home;
use Data::Dumper;

has description => 'Generate and send invoices from the command line';
has usage => sub ($self) { $self->extract_usage };

sub run ($self, @args) {
  getopt \@args,
    'g|generate=i' => \my $customer_id,
    's|send=i'     => \my $invoice_id,
    'r|reprint=i'  => \my $reprint_id,
    'l|list'       => \my $list,
    'c|customer=i' => \my $list_customer,
    'status=s'     => \my $status_filter,
    'limit=i'      => \(my $limit = 20),
    'dry-run'      => \my $dry_run,
    'h|help'       => \my $help;

  # Show help
  if ($help || (!$customer_id && !$invoice_id && !$reprint_id && !$list)) {
    print $self->usage;
    return;
  }

  # Initialize database and models
  my $pg = $self->app->pg;
  my $invoice_model = $self->app->invoice;
  my $customer_model = $self->app->customer;
  my $config = $self->app->config;

  # List invoices
  if ($list) {
    print "Listing invoices...\n";
    my $where = {};
    $where->{customerid} = $list_customer if $list_customer;
    $where->{state} = $status_filter if $status_filter;

    my $options = {
      where => $where,
      limit => { -desc => 'invoiceid' }
    };

    my $invoices = $invoice_model->get($options);

    # Apply limit after fetching
    if ($limit && $invoices && @$invoices > $limit) {
      splice(@$invoices, $limit);
    }

    if ($invoices && @$invoices) {
      # Get customer names
      my %customer_names;
      for my $inv (@$invoices) {
        next unless $inv->{customerid};
        unless (exists $customer_names{$inv->{customerid}}) {
          my $customers = $customer_model->get({
            where => { customerid => $inv->{customerid} }
          });
          if ($customers && @$customers) {
            my $cust = $customers->[0];
            $customer_names{$inv->{customerid}} =
              $cust->{customername} || $cust->{commonname} ||
              $cust->{givenname} || "Customer $inv->{customerid}";
          } else {
            $customer_names{$inv->{customerid}} = "Customer $inv->{customerid}";
          }
        }
      }

      printf "%-10s %-15s %-30s %-12s %-10s %s\n",
             'ID', 'Number', 'Customer', 'Amount', 'Status', 'Date';
      print '-' x 100 . "\n";

      for my $inv (@$invoices) {
        my $customer_name = $customer_names{$inv->{customerid}} || 'Unknown';
        printf "%-10s %-15s %-30s %-12.2f %-10s %s\n",
               $inv->{invoiceid} || 'N/A',
               $inv->{fakturanummer} || 'N/A',
               substr($customer_name, 0, 30),
               $inv->{total} || 0,
               $inv->{state} || 'unknown',
               $inv->{invoicedate} || 'N/A';
      }
    } else {
      print "No invoices found\n";
    }
    return;
  }

  # Generate invoice for customer
  if ($customer_id) {
    print "Generating invoice for customer ID $customer_id...\n";

    # Get customer
    my $customers = $customer_model->get({ where => { customerid => $customer_id } });
    unless ($customers && @$customers) {
      print "✗ Customer not found\n";
      exit 1;
    }
    my $customer = $customers->[0];

    # Get open invoice items
    my $invoiceitems = $invoice_model->invoiceitems({
      customerid => $customer_id,
      invoiceid => undef
    });

    unless ($invoiceitems && @$invoiceitems) {
      print "✗ No open invoice items found for customer\n";
      exit 1;
    }

    print "Found " . scalar(@$invoiceitems) . " open items\n";

    if ($dry_run) {
      print "Dry run mode - not creating invoice\n";
      my $total = 0;
      for my $item (@$invoiceitems) {
        $total += $item->{price} * $item->{quantity};
        printf "  - %s: %.2f x %d = %.2f\n",
               $item->{description}, $item->{price}, $item->{quantity},
               $item->{price} * $item->{quantity};
      }
      printf "Total (excl VAT): %.2f\n", $total;
      return;
    }

    # Create the invoice
    my $invoice_data = {
      customerid => $customer_id,
      invoicedate => \'NOW()',
      duedate => \"NOW() + INTERVAL '30 days'",
      paymentstatus => 'unpaid',
      currency => $customer->{currency} || 'SEK',
      vat => $customer->{vat} || 0.25,
    };

    my $invoice_id = $invoice_model->addinvoice($customer);

    if ($invoice_id) {
      # Update invoice with data and items
      my $invoice_number = sprintf('%s%06d',
                                  $config->{manager}->{invoice}->{prefix} || 'INV',
                                  $invoice_id);
      $invoice_model->updateinvoice($invoice_id, {
        invoicenumber => $invoice_number,
        currency => $invoice_data->{currency},
        vat => $invoice_data->{vat}
      });

      # Assign open items to this invoice
      for my $item (@$invoiceitems) {
        $invoice_model->updateinvoiceitem($item->{invoiceitemid}, {
          invoiceid => $invoice_id
        });
      }

      # Generate PDF
      print "Generating PDF...\n";
      my $success = $self->_generate_pdf($invoice_id);

      if ($success) {
        print "✓ Invoice $invoice_number created successfully (ID: $invoice_id)\n";
        print "  PDF saved to: " . $config->{manager}->{invoice}->{invoicedir} . "\n";
      } else {
        print "✓ Invoice created but PDF generation failed\n";
      }
    } else {
      print "✗ Failed to create invoice\n";
      exit 1;
    }
  }

  # Send invoice
  if ($invoice_id) {
    print "Sending invoice ID $invoice_id...\n";

    my $invoices = $invoice_model->get({ where => { invoiceid => $invoice_id } });
    unless ($invoices && @$invoices) {
      print "✗ Invoice not found\n";
      exit 1;
    }
    my $invoice = $invoices->[0];

    # Get customer
    my $customers = $customer_model->get({
      where => { customerid => $invoice->{customerid} }
    });
    my $customer = $customers->[0] if $customers && @$customers;

    unless ($customer && $customer->{email}) {
      print "✗ Customer email not found\n";
      exit 1;
    }

    if ($dry_run) {
      print "Dry run mode - not sending email\n";
      print "  To: $customer->{email}\n";
      print "  Invoice: $invoice->{invoicenumber}\n";
      print "  Amount: $invoice->{total} $invoice->{currency}\n";
      return;
    }

    # Send email
    my $success = $self->_send_email($invoice, $customer);

    if ($success) {
      print "✓ Invoice sent successfully to $customer->{email}\n";

      # Update sent date
      $invoice_model->updateinvoice($invoice_id, {
        sentdate => \'NOW()'
      });
    } else {
      print "✗ Failed to send invoice\n";
      exit 1;
    }
  }

  # Reprint invoice
  if ($reprint_id) {
    print "Reprinting invoice ID $reprint_id...\n";

    my $invoices = $invoice_model->get({ where => { invoiceid => $reprint_id } });
    unless ($invoices && @$invoices) {
      print "✗ Invoice not found\n";
      exit 1;
    }

    if ($dry_run) {
      print "Dry run mode - not regenerating PDF\n";
      return;
    }

    my $success = $self->_generate_pdf($reprint_id);

    if ($success) {
      print "✓ Invoice PDF regenerated successfully\n";
    } else {
      print "✗ Failed to regenerate PDF\n";
      exit 1;
    }
  }
}

sub _generate_pdf ($self, $invoice_id) {
  my $invoice_model = $self->app->invoice;
  my $customer_model = $self->app->customer;
  my $config = $self->app->config;

  # Get invoice and related data
  my $invoices = $invoice_model->get({ where => { invoiceid => $invoice_id } });
  return 0 unless $invoices && @$invoices;
  my $invoice = $invoices->[0];

  my $customers = $customer_model->get({
    where => { customerid => $invoice->{customerid} }
  });
  return 0 unless $customers && @$customers;
  my $customer = $customers->[0];

  my $invoiceitems = $invoice_model->invoiceitems({
    invoiceid => $invoice_id
  });

  # Ensure UUID exists
  unless ($invoice->{uuid}) {
    require Data::UUID;
    my $uuid = Data::UUID->new->create_str();
    $invoice_model->updateinvoice($invoice_id, {
      uuid => $uuid
    });
    $invoice->{uuid} = $uuid;
  }

  # Calculate amounts
  my $vat = ($invoice->{vat} || $customer->{vat} || 0.25) * 100;
  my $subtotal = 0;
  my $items_text = '';

  for my $item (@$invoiceitems) {
    my $amount = $item->{price} * $item->{quantity};
    $subtotal += $amount;
    $items_text .= sprintf("    %s & %d & %.2f & %.2f \\\\\n",
                          $item->{description} || 'Item',
                          $item->{quantity},
                          $item->{price},
                          $amount);
  }

  my $vat_amount = $subtotal * ($vat / 100);
  my $total = $subtotal + $vat_amount;

  # Prepare invoice data
  my $formdata = {
    invoice => {
      uuid => $invoice->{uuid},
      invoicenumber => $invoice->{invoicenumber},
      invoicedate => $invoice->{invoicedate},
      duedate => $invoice->{duedate},
    },
    customer => {
      customername => $customer->{customername},
      contactname => $customer->{contactname},
      email => $customer->{email},
      phone => $customer->{phone},
      address => $customer->{address},
      postalcode => $customer->{postalcode},
      city => $customer->{city},
      country => $customer->{country},
    },
    amounts => {
      subtotal => sprintf('%.2f', $subtotal),
      vat => sprintf('%.0f', $vat),
      vat_amount => sprintf('%.2f', $vat_amount),
      total => sprintf('%.2f', $total),
      currency => $invoice->{currency} || 'SEK',
    }
  };

  # Generate LaTeX
  my $tex = $self->_generate_tex($formdata, $items_text);

  # Generate PDF using the static helper
  require Samizdat::Plugin::Invoice;
  my $pdf = Samizdat::Plugin::Invoice::generate_pdf_from_tex($tex, $invoice->{uuid}, $config);

  return $pdf ? 1 : 0;
}

sub _generate_tex ($self, $formdata, $items_text) {
  # Basic LaTeX template for invoice
  my $tex = <<'EOF';
\documentclass[a4paper,11pt]{article}
\usepackage[utf8]{inputenc}
\usepackage{graphicx}
\usepackage{longtable}
\usepackage{array}
\usepackage[margin=2cm]{geometry}

\begin{document}

\begin{center}
\Large\textbf{INVOICE}
\end{center}

\vspace{1cm}

\begin{tabular}{ll}
\textbf{Invoice Number:} & %%INVOICENUMBER%% \\
\textbf{Invoice Date:} & %%INVOICEDATE%% \\
\textbf{Due Date:} & %%DUEDATE%% \\
\end{tabular}

\vspace{1cm}

\textbf{Bill To:}\\
%%CUSTOMERNAME%%\\
%%CONTACTNAME%%\\
%%ADDRESS%%\\
%%POSTALCODE%% %%CITY%%\\
%%COUNTRY%%

\vspace{1cm}

\begin{longtable}{|l|r|r|r|}
\hline
\textbf{Description} & \textbf{Qty} & \textbf{Price} & \textbf{Amount} \\
\hline
%%ITEMS%%
\hline
\multicolumn{3}{|r|}{\textbf{Subtotal}} & %%SUBTOTAL%% %%CURRENCY%% \\
\multicolumn{3}{|r|}{\textbf{VAT (%%VAT%%\%)}} & %%VATAMOUNT%% %%CURRENCY%% \\
\multicolumn{3}{|r|}{\textbf{Total}} & %%TOTAL%% %%CURRENCY%% \\
\hline
\end{longtable}

\end{document}
EOF

  # Replace placeholders
  $tex =~ s/%%INVOICENUMBER%%/$formdata->{invoice}->{invoicenumber}/g;
  $tex =~ s/%%INVOICEDATE%%/$formdata->{invoice}->{invoicedate}/g;
  $tex =~ s/%%DUEDATE%%/$formdata->{invoice}->{duedate}/g;
  $tex =~ s/%%CUSTOMERNAME%%/$formdata->{customer}->{customername}/g;
  $tex =~ s/%%CONTACTNAME%%/$formdata->{customer}->{contactname} || ''/ge;
  $tex =~ s/%%ADDRESS%%/$formdata->{customer}->{address} || ''/ge;
  $tex =~ s/%%POSTALCODE%%/$formdata->{customer}->{postalcode} || ''/ge;
  $tex =~ s/%%CITY%%/$formdata->{customer}->{city} || ''/ge;
  $tex =~ s/%%COUNTRY%%/$formdata->{customer}->{country} || ''/ge;
  $tex =~ s/%%ITEMS%%/$items_text/g;
  $tex =~ s/%%SUBTOTAL%%/$formdata->{amounts}->{subtotal}/g;
  $tex =~ s/%%VAT%%/$formdata->{amounts}->{vat}/g;
  $tex =~ s/%%VATAMOUNT%%/$formdata->{amounts}->{vat_amount}/g;
  $tex =~ s/%%TOTAL%%/$formdata->{amounts}->{total}/g;
  $tex =~ s/%%CURRENCY%%/$formdata->{amounts}->{currency}/g;

  return $tex;
}

sub _send_email ($self, $invoice, $customer) {
  my $config = $self->app->config;
  my $locale = $self->app->locale;

  # Determine language
  my $lang = $customer->{billinglang} || $customer->{language} ||
             $config->{locale}->{default_language} || 'sv';
  $locale->languages($lang);

  # Check if PDF exists
  my $pdf_path = sprintf('%s/%s.pdf',
                        $config->{manager}->{invoice}->{invoicedir},
                        $invoice->{uuid});

  unless (-f $pdf_path) {
    warn "PDF file not found: $pdf_path";
    return 0;
  }

  # Read PDF
  my $pdf_file = Mojo::Home->new()->rel_file($pdf_path);
  my $pdf_data = $pdf_file->slurp;

  # Prepare email
  require MIME::Lite;

  my $subject = sprintf('%s: %s',
                       $locale->__('Invoice'),
                       $invoice->{invoicenumber});

  my $body = sprintf("%s\n\n%s: %s %s\n%s: %s\n\n%s\n",
                    $locale->__('Dear') . ' ' . $customer->{contactname},
                    $locale->__('Please find attached invoice'),
                    $invoice->{total},
                    $invoice->{currency},
                    $locale->__('Due date'),
                    $invoice->{duedate},
                    $locale->__('Thank you for your business'));

  # Create email
  my $mail = MIME::Lite->new(
    From    => $config->{mail}->{from},
    To      => $customer->{email},
    Subject => Encode::encode("MIME-Q", $subject),
    Type    => 'multipart/mixed',
  );

  # Add text part
  $mail->attach(
    Type => 'TEXT',
    Data => encode('UTF-8', $body),
  );

  # Add PDF attachment
  $mail->attach(
    Type        => 'application/pdf',
    Filename    => sprintf('%s.pdf', $invoice->{uuid}),
    Disposition => 'attachment',
    Data        => $pdf_data,
  );

  # Send email
  eval {
    $mail->send($config->{mail}->{how}, @{$config->{mail}->{howargs}});
  };

  if ($@) {
    warn "Failed to send email: $@";
    return 0;
  }

  return 1;
}

1;

=head1 SYNOPSIS

  Usage: APPLICATION invoice [OPTIONS]

  # Generate invoice for a customer
  samizdat invoice -g 123
  samizdat invoice --generate 123 --dry-run

  # Send an existing invoice
  samizdat invoice -s 456
  samizdat invoice --send 456 --dry-run

  # Regenerate PDF for existing invoice
  samizdat invoice -r 789
  samizdat invoice --reprint 789

  # List invoices
  samizdat invoice --list
  samizdat invoice --list --customer 123
  samizdat invoice --list --status unpaid --limit 50

  Options:
    -g, --generate <id>     Generate invoice for customer ID
    -s, --send <id>         Send invoice by ID via email
    -r, --reprint <id>      Regenerate PDF for invoice ID
    -l, --list              List invoices
    -c, --customer <id>     Filter by customer ID (with --list)
    --status <status>       Filter by payment status (with --list)
    --limit <n>             Limit number of results (default: 20)
    --dry-run               Show what would be done without doing it
    -h, --help              Show this help

=cut