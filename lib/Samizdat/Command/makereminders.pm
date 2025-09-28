package Samizdat::Command::makereminders;

use Mojo::Base 'Mojolicious::Command', -signatures;
use Mojo::Util qw(getopt);

has description => 'Send invoice reminders for overdue invoices';
has usage => sub ($self) { $self->extract_usage };

sub run ($self, @args) {
  my $app = $self->app;

  # Parse command-line options
  getopt \@args,
    'd|dry-run' => \my $dry_run,
    'c|customerid=i' => \my $customerid,
    'i|invoiceid=i' => \my $invoiceid,
    'a|all' => \my $all,
    't|tough' => \my $tough,
    'v|verbose' => \my $verbose;

  # Get database helpers
  my $invoice_model = $app->invoice;
  my $customer_model = $app->customer;

  my $invoices = [];

  if ($invoiceid) {
    # Send reminder for specific invoice
    $invoices = $invoice_model->get({
      where => {
        invoiceid => $invoiceid,
        state => 'fakturerad'
      }
    });
  } elsif ($customerid) {
    # Send reminders for specific customer's overdue invoices
    $invoices = $invoice_model->get({
      where => {
        customerid => $customerid,
        state => 'fakturerad'
      }
    });
  } elsif ($all) {
    # Send reminders for all overdue invoices
    $invoices = $invoice_model->get({
      where => {
        state => 'fakturerad'
      }
    });
  } else {
    say "Usage: samizdat makereminders [OPTIONS]";
    say "Options:";
    say "  -i, --invoiceid=ID    Send reminder for specific invoice";
    say "  -c, --customerid=ID   Send reminders for customer's overdue invoices";
    say "  -a, --all             Send reminders for all overdue invoices";
    say "  -t, --tough           Send tough (final) reminders instead of mild";
    say "  -d, --dry-run         Show what would be sent without sending";
    say "  -v, --verbose         Show detailed output";
    return;
  }

  my $sent_count = 0;
  my $skip_count = 0;

  for my $invoice (@$invoices) {
    # Check if invoice is actually overdue
    if (!$invoice_model->is_overdue($invoice)) {
      $skip_count++;
      say "Skipping invoice $invoice->{fakturanummer} - not overdue" if $verbose;
      next;
    }

    # Check reminder history
    my $reminders = $invoice_model->reminders($invoice->{invoiceid});
    my $reminder_count = scalar(@$reminders);

    # Determine if we should send based on reminder type and history
    if ($tough) {
      # For tough reminders, require at least one previous reminder
      if ($reminder_count < 1) {
        $skip_count++;
        say "Skipping invoice $invoice->{fakturanummer} - no mild reminder sent yet" if $verbose;
        next;
      }
      # Skip if we sent a tough reminder in the last 14 days
      if (@$reminders) {
        my $last_reminder = $reminders->[-1];
        require Time::ParseDate;
        my $last_reminder_time = Time::ParseDate::parsedate($last_reminder->{reminderdate});
        if (time - $last_reminder_time < 14 * 24 * 3600) {
          $skip_count++;
          say "Skipping invoice $invoice->{fakturanummer} - reminder sent recently" if $verbose;
          next;
        }
      }
    } else {
      # For mild reminders, skip if sent in last 7 days
      if (@$reminders) {
        my $last_reminder = $reminders->[-1];
        require Time::ParseDate;
        my $last_reminder_time = Time::ParseDate::parsedate($last_reminder->{reminderdate});
        if (time - $last_reminder_time < 7 * 24 * 3600) {
          $skip_count++;
          say "Skipping invoice $invoice->{fakturanummer} - reminder sent recently" if $verbose;
          next;
        }
      }
    }

    # Get customer details
    my $customer = $customer_model->get({
      where => { customerid => $invoice->{customerid} }
    })->[0];

    if (!$customer) {
      say "ERROR: Customer not found for invoice $invoice->{fakturanummer}";
      next;
    }

    my $reminder_type = $tough ? 'tough' : 'mild';

    if ($dry_run) {
      say "Would send $reminder_type reminder for invoice $invoice->{fakturanummer} to $customer->{email}";
    } else {
      say "Sending $reminder_type reminder for invoice $invoice->{fakturanummer} to $customer->{email}" if $verbose;

      # Send the reminder email using the process_invoice helper
      my $result = $app->process_invoice(
        $invoice->{invoiceid},
        $invoice->{customerid},
        {
          action => $tough ? 'reminder_tough' : 'reminder_mild',
          send_email => 1
        }
      );

      if ($result->{success}) {
        # Record the reminder in database
        $invoice_model->addreminder($invoice->{invoiceid});
        $sent_count++;
        say "✓ $reminder_type reminder sent for invoice $invoice->{fakturanummer}";
      } else {
        say "ERROR: Failed to send reminder for invoice $invoice->{fakturanummer}: $result->{error}";
      }
    }
  }

  # Summary
  say "";
  say "Summary:";
  say "  Invoices processed: " . scalar(@$invoices);
  say "  Reminders sent: $sent_count" unless $dry_run;
  say "  Would send: $sent_count" if $dry_run;
  say "  Skipped (not overdue or recent reminder): $skip_count";
}

=encoding utf8

=head1 NAME

Samizdat::Command::makereminders - Send invoice reminders

=head1 SYNOPSIS

  # Send reminders for all overdue invoices
  samizdat makereminders --all

  # Send reminder for specific invoice
  samizdat makereminders --invoiceid=12345

  # Send reminders for specific customer
  samizdat makereminders --customerid=1234

  # Dry run to see what would be sent
  samizdat makereminders --all --dry-run

  # Run from cron (daily at 9 AM)
  0 9 * * * /path/to/samizdat makereminders --all

=head1 DESCRIPTION

Send invoice reminders for overdue invoices. Can be run manually or from cron.

=head1 OPTIONS

=over 4

=item -i, --invoiceid=ID

Send reminder for a specific invoice

=item -c, --customerid=ID

Send reminders for all overdue invoices of a specific customer

=item -a, --all

Send reminders for all overdue invoices in the system

=item -d, --dry-run

Show what would be sent without actually sending emails

=item -v, --verbose

Show detailed output

=back

=cut

1;