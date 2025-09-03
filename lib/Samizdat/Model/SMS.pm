package Samizdat::Model::SMS;

use Mojo::Base -base, -signatures;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::Util qw(url_escape);

has 'config';
has 'database';
has 'ua' => sub { Mojo::UserAgent->new };


sub send_sms ($self, $to, $message, %opts) {
  my $config = $self->config;
  my $ua = $self->ua;
  
  my $url = sprintf('http://%s/cgi-bin/sms_send', $config->{host});
  
  # Prepare SMS data
  my $form_data = {
    username => $config->{username},
    password => $config->{password},
    number   => $to,
    text     => $message,
  };
  
  my $tx = $ua->post($url => form => $form_data);
  
  my $response = {
    success => 0,
    message => '',
    tx_id   => undef,
  };
  
  if ($tx->result->is_success) {
    my $body = $tx->result->body;
    
    # Parse Teltonika response format
    if ($body =~ /OK\s+(\d+)/) {
      $response->{success} = 1;
      $response->{tx_id} = $1;
      $response->{message} = 'SMS sent successfully';
      
      # Store in database if available
      if ($self->database) {
        $self->store_message({
          direction => 'outbound',
          phone     => $to,
          message   => $message,
          tx_id     => $response->{tx_id},
          status    => 'sent',
          sent_at   => \'NOW()',
        });
      }
    } else {
      $response->{message} = "Send failed: $body";
    }
  } else {
    $response->{message} = 'Connection failed: ' . $tx->result->message;
  }
  
  return $response;
}


sub receive_sms ($self, %opts) {
  my $config = $self->config;
  my $ua = $self->ua;
  
  my $url = sprintf('http://%s/cgi-bin/sms_read', $config->{host});
  
  my $form_data = {
    username => $config->{username},
    password => $config->{password},
  };
  
  my $tx = $ua->post($url => form => $form_data);
  
  my @messages = ();
  
  if ($tx->result->is_success) {
    my $body = $tx->result->body;
    
    # Parse messages from Teltonika format
    # Format: number|message|timestamp|id
    for my $line (split /\n/, $body) {
      next unless $line =~ /\|/;
      my ($phone, $message, $timestamp, $msg_id) = split(/\|/, $line, 4);
      
      my $sms = {
        phone     => $phone,
        message   => $message,
        timestamp => $timestamp,
        msg_id    => $msg_id,
      };
      
      # Store in database if available
      if ($self->database) {
        $self->store_message({
          direction  => 'inbound',
          phone      => $phone,
          message    => $message,
          msg_id     => $msg_id,
          status     => 'received',
          received_at => \'NOW()',
        });
      }
      
      push @messages, $sms;
    }
  }
  
  return \@messages;
}


sub get_messages ($self, %opts) {
  return [] unless $self->database;
  
  my $db = $self->database->db;
  my $limit = $opts{limit} || 50;
  my $offset = $opts{offset} || 0;
  my $direction = $opts{direction};
  my $phone = $opts{phone};
  
  my $where = {};
  $where->{direction} = $direction if $direction;
  $where->{phone} = $phone if $phone;
  
  my $other = { 
    order_by => {-desc => 'created_at'}, 
    limit => $limit,
    offset => $offset
  };
  
  return $db->select('sms.messages', '*', $where, $other)->hashes->to_array;
}


sub store_message ($self, $message) {
  return unless $self->database;
  
  my $db = $self->database->db;
  $message->{created_at} = \'NOW()' unless $message->{created_at};
  
  return $db->insert('sms.messages', $message, {returning => 'id'})->hash->{id};
}


sub delete_message ($self, $id) {
  return unless $self->database;
  
  my $db = $self->database->db;
  return $db->delete('sms.messages', {id => $id})->rows;
}


sub get_status ($self) {
  my $config = $self->config;
  my $ua = $self->ua;
  
  my $url = sprintf('http://%s/cgi-bin/sms_status', $config->{host});
  
  my $form_data = {
    username => $config->{username},
    password => $config->{password},
  };
  
  my $tx = $ua->post($url => form => $form_data);
  
  my $status = {
    connected => 0,
    signal    => 0,
    operator  => '',
  };
  
  if ($tx->result->is_success) {
    my $body = $tx->result->body;
    $status->{connected} = 1;
    
    # Parse status response
    if ($body =~ /Signal:\s*(\d+)/) {
      $status->{signal} = $1;
    }
    if ($body =~ /Operator:\s*(.+)/) {
      $status->{operator} = $1;
    }
  }
  
  return $status;
}

1;