package Samizdat::Command::sms;

use Mojo::Base 'Mojolicious::Command', -signatures;
use Mojo::Util qw(getopt);
use Data::Dumper;

has description => 'Send and receive SMS messages via Teltonika device';
has usage => sub ($self) { $self->extract_usage };

sub run ($self, @args) {
  getopt \@args,
    's|send=s'     => \my $send_to,
    'm|message=s'  => \my $message,
    'r|receive'    => \my $receive,
    'status'       => \my $status,
    'list'         => \my $list,
    'limit=i'      => \(my $limit = 10),
    'phone=s'      => \my $phone_filter,
    'direction=s'  => \my $direction_filter,
    'delete=i'     => \my $delete_id,
    'h|help'       => \my $help;

  # Show help
  if ($help || (!$send_to && !$receive && !$status && !$list && !$delete_id)) {
    print $self->usage;
    return;
  }

  # Initialize SMS helper
  my $sms = $self->app->sms;
  
  # Send SMS
  if ($send_to && $message) {
    print "Sending SMS to $send_to...\n";
    my $result = $sms->send_sms($send_to, $message);
    
    if ($result->{success}) {
      print "✓ SMS sent successfully (ID: $result->{tx_id})\n";
    } else {
      print "✗ Failed to send SMS: $result->{message}\n";
      exit 1;
    }
  } elsif ($send_to && !$message) {
    print "Error: Message required when sending SMS\n";
    print "Use: samizdat sms -s +46701234567 -m 'Your message here'\n";
    exit 1;
  }
  
  # Receive SMS
  if ($receive) {
    print "Checking for new SMS messages...\n";
    my $messages = $sms->receive_sms();
    
    if (@$messages) {
      print "✓ Received " . scalar(@$messages) . " new message(s):\n";
      for my $msg (@$messages) {
        print "  From: $msg->{phone}\n";
        print "  Time: $msg->{timestamp}\n";
        print "  Text: $msg->{message}\n";
        print "  ---\n";
      }
    } else {
      print "No new messages\n";
    }
  }
  
  # Show device status
  if ($status) {
    print "Checking device status...\n";
    my $device_status = $sms->get_status();
    
    if ($device_status->{connected}) {
      print "✓ Device connected\n";
      print "  Signal: $device_status->{signal}%\n";
      print "  Operator: $device_status->{operator}\n" if $device_status->{operator};
    } else {
      print "✗ Device not connected\n";
      exit 1;
    }
  }
  
  # List messages
  if ($list) {
    print "Retrieving message history...\n";
    my $messages = $sms->get_messages(
      limit => $limit,
      phone => $phone_filter,
      direction => $direction_filter,
    );
    
    if (@$messages) {
      print "Found " . scalar(@$messages) . " message(s):\n";
      printf "%-4s %-10s %-15s %-10s %-20s %s\n", 
             'ID', 'Direction', 'Phone', 'Status', 'Time', 'Message';
      print '-' x 80 . "\n";
      
      for my $msg (@$messages) {
        my $preview = length($msg->{message}) > 30 ? 
                     substr($msg->{message}, 0, 30) . '...' : 
                     $msg->{message};
        printf "%-4s %-10s %-15s %-10s %-20s %s\n",
               $msg->{id} || 'N/A',
               $msg->{direction},
               $msg->{phone},
               $msg->{status},
               $msg->{created_at} || $msg->{timestamp} || 'N/A',
               $preview;
      }
    } else {
      print "No messages found\n";
    }
  }
  
  # Delete message
  if ($delete_id) {
    print "Deleting message ID $delete_id...\n";
    my $deleted = $sms->delete_message($delete_id);
    
    if ($deleted > 0) {
      print "✓ Message deleted successfully\n";
    } else {
      print "✗ Message not found or could not be deleted\n";
      exit 1;
    }
  }
}

1;

=head1 SYNOPSIS

  Usage: APPLICATION sms [OPTIONS]

  # Send an SMS
  samizdat sms -s +46701234567 -m "Hello from Samizdat!"

  # Receive new SMS messages
  samizdat sms --receive

  # Check device status
  samizdat sms --status

  # List recent messages
  samizdat sms --list

  # List messages with filters
  samizdat sms --list --limit 20 --direction outbound
  samizdat sms --list --phone +46701234567

  # Delete a message by ID
  samizdat sms --delete 123

  Options:
    -s, --send <phone>      Send SMS to phone number
    -m, --message <text>    Message text to send
    -r, --receive           Check for and retrieve new SMS messages
    --status                Show device connection status
    --list                  List message history
    --limit <n>             Limit number of messages (default: 10)
    --phone <number>        Filter messages by phone number
    --direction <dir>       Filter by direction (inbound/outbound)
    --delete <id>           Delete message by ID
    -h, --help              Show this help

=cut