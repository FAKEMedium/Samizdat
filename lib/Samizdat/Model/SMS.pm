package Samizdat::Model::SMS;

use Mojo::Base -base, -signatures;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::Util qw(url_escape);
use MIME::Base64;
use Encode qw(decode encode);
use utf8;

has 'config';
has 'database';
has 'ua' => sub { 
  my $ua = Mojo::UserAgent->new;
  # Skip SSL verification for self-signed certificates
  $ua->insecure(1);
  # Set timeout
  $ua->connect_timeout(10)->request_timeout(30);
  return $ua;
};


sub send_sms ($self, $to, $message, %opts) {
  my $config = $self->config;
  my $ua = $self->ua;
  
  # Use HTTPS for port 443, HTTP otherwise  
  my $protocol = ($config->{port} && $config->{port} == 443) ? 'https' : 'http';
  my $port = ($config->{port} && $config->{port} != 80 && $config->{port} != 443) ? ":$config->{port}" : '';
  
  # Format phone number - ensure it starts with 00 + country code
  my $formatted_number = $to;
  if ($to =~ /^\+(\d+)/) {
    # Convert +46... to 0046...
    $formatted_number = "00$1";
  } elsif ($to !~ /^00/) {
    # If no +, assume it needs 00 prefix (this might need adjustment)
    $formatted_number = "00$to" if $to =~ /^\d+$/;
  }
  
  # Encode message properly for SMS
  my $encoded_message = encode('UTF-8', $message);
  
  # Use traditional CGI endpoint with GET parameters
  my $url = sprintf('%s://%s%s/cgi-bin/sms_send', $protocol, $config->{host}, $port);
  my $query_params = {
    username => $config->{username},
    password => $config->{password},
    number   => $formatted_number,
    text     => $encoded_message,
  };
  
  # Build query string
  my $query_string = join('&', map { 
    url_escape($_) . '=' . url_escape($query_params->{$_}) 
  } keys %$query_params);
  
  my $full_url = "$url?$query_string";
  
  # Log the request for debugging
  warn "SMS Send URL: $full_url";
  
  my $tx = $ua->get($full_url);
  
  my $response = {
    success => 0,
    message => '',
    tx_id   => undef,
  };
  
  # Log response for debugging
  warn "SMS Response Status: " . $tx->result->code if $tx->result->code;
  warn "SMS Response Body: " . $tx->result->body if $tx->result->body;
  
  if ($tx->result->is_success) {
    my $body = $tx->result->body;
    
    # Parse Teltonika CGI response format
    if ($body =~ /^OK/) {
      # Success response - could be "OK" or "OK <message_id>"
      $response->{success} = 1;
      $response->{message} = 'SMS sent successfully';
      
      # Extract message ID if present
      if ($body =~ /OK\s+(\d+)/) {
        $response->{tx_id} = $1;
      }
      
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
      # Error response
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
  
  # Use HTTPS for port 443, HTTP otherwise
  my $protocol = ($config->{port} && $config->{port} == 443) ? 'https' : 'http';
  my $port = ($config->{port} && $config->{port} != 80 && $config->{port} != 443) ? ":$config->{port}" : '';
  my $url = sprintf('%s://%s%s/cgi-bin/sms_list', $protocol, $config->{host}, $port);
  
  my $query_params = {
    username => $config->{username},
    password => $config->{password},
  };
  
  # Build query string
  my $query_string = join('&', map { 
    url_escape($_) . '=' . url_escape($query_params->{$_}) 
  } keys %$query_params);
  
  my $full_url = "$url?$query_string";
  
  warn "SMS List URL: $full_url";
  my $tx = $ua->get($full_url);
  
  my @messages = ();
  
  if ($tx->result->is_success) {
    my $body = $tx->result->body;
    # Decode UTF-8 properly
    $body = decode('UTF-8', $body) unless utf8::is_utf8($body);
    warn "SMS List Response: $body"; # Debug log
    
    # Parse messages from Teltonika format
    # Format is:
    # Index: N
    # Date: timestamp  
    # Sender: phone
    # Text: message
    # Status: read/unread
    # ------------------------------
    
    my @message_blocks = split /------------------------------/, $body;
    
    for my $block (@message_blocks) {
      next unless $block =~ /\S/; # Skip empty blocks
      
      my %msg_data;
      for my $line (split /\n/, $block) {
        $line =~ s/^\s+|\s+$//g; # Trim whitespace
        next unless $line;
        
        if ($line =~ /^Index:\s*(\d+)/) {
          $msg_data{index} = $1;
        } elsif ($line =~ /^Date:\s*(.+)/) {
          $msg_data{date} = $1;
        } elsif ($line =~ /^Sender:\s*(.+)/) {
          $msg_data{sender} = $1;
        } elsif ($line =~ /^Text:\s*(.*)/) {
          $msg_data{text} = $1;
          # Text might span multiple lines, so collect the rest
          my @remaining_lines = split /\n/, $block;
          my $in_text = 0;
          my @text_lines;
          for my $remaining_line (@remaining_lines) {
            if ($remaining_line =~ /^Text:\s*(.*)/) {
              $in_text = 1;
              push @text_lines, $1 if $1;
            } elsif ($in_text && $remaining_line =~ /^Status:/) {
              last;
            } elsif ($in_text) {
              $remaining_line =~ s/^\s+|\s+$//g;
              push @text_lines, $remaining_line if $remaining_line;
            }
          }
          $msg_data{text} = join("\n", @text_lines);
        } elsif ($line =~ /^Status:\s*(.+)/) {
          $msg_data{status} = $1;
        }
      }
      
      # Only process if we have the required fields
      if ($msg_data{sender} && $msg_data{text} && defined $msg_data{index}) {
        warn "Found SMS: phone=$msg_data{sender}, index=$msg_data{index}, message=$msg_data{text}"; # Debug log
        
        my $sms = {
          phone     => $msg_data{sender},
          message   => $msg_data{text},
          timestamp => $msg_data{date},
          msg_id    => $msg_data{index},
        };
        
        
        push @messages, $sms;
      }
    }
  } else {
    warn "SMS List Request Failed: " . $tx->result->code . " - " . $tx->result->message;
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
    order_by => {-desc => 'id'}, 
    limit => $limit,
    offset => $offset
  };
  
  my $results = $db->select('sms.messages', '*', $where, $other)->hashes->to_array;
  
  # Format timestamps to remove microseconds and timezone
  for my $msg (@$results) {
    if ($msg->{created_at} && length($msg->{created_at}) > 19) {
      $msg->{created_at} = substr($msg->{created_at}, 0, 19);
    }
    if ($msg->{sent_at} && length($msg->{sent_at}) > 19) {
      $msg->{sent_at} = substr($msg->{sent_at}, 0, 19);
    }
    if ($msg->{received_at} && length($msg->{received_at}) > 19) {
      $msg->{received_at} = substr($msg->{received_at}, 0, 19);
    }
  }
  
  return $results;
}


sub count_messages ($self, %opts) {
  return 0 unless $self->database;
  
  my $db = $self->database->db;
  my $direction = $opts{direction};
  my $phone = $opts{phone};
  
  my $where = {};
  $where->{direction} = $direction if $direction;
  $where->{phone} = $phone if $phone;
  
  return $db->select('sms.messages', 'COUNT(*) as total', $where)->hash->{total} || 0;
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
  
  # Use HTTPS for port 443, HTTP otherwise
  my $protocol = ($config->{port} && $config->{port} == 443) ? 'https' : 'http';
  my $port = ($config->{port} && $config->{port} != 80 && $config->{port} != 443) ? ":$config->{port}" : '';
  my $url = sprintf('%s://%s%s/cgi-bin/sms_total', $protocol, $config->{host}, $port);
  
  my $query_params = {
    username => $config->{username},
    password => $config->{password},
  };
  
  # Build query string
  my $query_string = join('&', map { 
    url_escape($_) . '=' . url_escape($query_params->{$_}) 
  } keys %$query_params);
  
  my $full_url = "$url?$query_string";
  
  warn "SMS Status URL: $full_url";
  my $tx = $ua->get($full_url);
  
  my $status = {
    connected => 0,
  };
  
  if ($tx->result->is_success) {
    $status->{connected} = 1;
  }
  
  return $status;
}

sub sync_messages ($self) {
  # Get all messages from device (without auto-storing)
  my $device_messages = $self->get_device_messages();
  
  return 0 unless $self->database && @$device_messages;
  
  # Sort by timestamp so oldest messages get processed first (and get lower IDs)
  my @sorted_messages = sort {
    # Parse timestamps for comparison
    my $time_a = eval { 
      require Time::Piece;
      Time::Piece->strptime($a->{timestamp} || '', "%a %b %d %H:%M:%S %Y")->epoch;
    } || 0;
    my $time_b = eval {
      require Time::Piece; 
      Time::Piece->strptime($b->{timestamp} || '', "%a %b %d %H:%M:%S %Y")->epoch;
    } || 0;
    $time_a <=> $time_b;
  } @$device_messages;
  
  my $db = $self->database->db;
  my $new_count = 0;
  
  for my $msg (@sorted_messages) {
    # Check if message already exists in database
    my $existing = $db->select('sms.messages', 'id', {
      direction => 'inbound',
      phone => $msg->{phone},
      message => $msg->{message},
      msg_id => $msg->{msg_id}
    })->hash;
    
    # Only insert if it doesn't exist
    unless ($existing) {
      # Parse the device timestamp if available
      my $created_at;
      if ($msg->{timestamp}) {
        # Convert device timestamp to PostgreSQL format
        # Device format: "Sat Sep  6 23:35:05 2025"
        eval {
          require Time::Piece;
          my $parsed = Time::Piece->strptime($msg->{timestamp}, "%a %b %d %H:%M:%S %Y");
          $created_at = $parsed->strftime("%Y-%m-%d %H:%M:%S");
        };
        # Fall back to NOW() if parsing fails
        $created_at = \'NOW()' if $@;
      } else {
        $created_at = \'NOW()';
      }
      
      $self->store_message({
        direction => 'inbound',
        phone => $msg->{phone},
        message => $msg->{message},
        msg_id => $msg->{msg_id},
        status => 'received',
        created_at => $created_at,
      });
      $new_count++;
    }
  }
  
  return $new_count;
}

# Get messages from device without storing them (used by sync)
sub get_device_messages ($self) {
  my $config = $self->config;
  my $ua = $self->ua;
  
  # Use HTTPS for port 443, HTTP otherwise
  my $protocol = ($config->{port} && $config->{port} == 443) ? 'https' : 'http';
  my $port = ($config->{port} && $config->{port} != 80 && $config->{port} != 443) ? ":$config->{port}" : '';
  my $url = sprintf('%s://%s%s/cgi-bin/sms_list', $protocol, $config->{host}, $port);
  
  my $query_params = {
    username => $config->{username},
    password => $config->{password},
  };
  
  # Build query string
  my $query_string = join('&', map { 
    url_escape($_) . '=' . url_escape($query_params->{$_}) 
  } keys %$query_params);
  
  my $full_url = "$url?$query_string";
  
  warn "SMS Device Messages URL: $full_url";
  my $tx = $ua->get($full_url);
  
  my @messages = ();
  
  if ($tx->result->is_success) {
    my $body = $tx->result->body;
    # Decode UTF-8 properly
    $body = decode('UTF-8', $body) unless utf8::is_utf8($body);
    warn "SMS Device Messages Response: $body"; # Debug log
    
    # Parse messages from Teltonika format
    my @message_blocks = split /------------------------------/, $body;
    
    for my $block (@message_blocks) {
      next unless $block =~ /\S/; # Skip empty blocks
      
      my %msg_data;
      for my $line (split /\n/, $block) {
        $line =~ s/^\s+|\s+$//g; # Trim whitespace
        next unless $line;
        
        if ($line =~ /^Index:\s*(\d+)/) {
          $msg_data{index} = $1;
        } elsif ($line =~ /^Date:\s*(.+)/) {
          $msg_data{date} = $1;
        } elsif ($line =~ /^Sender:\s*(.+)/) {
          $msg_data{sender} = $1;
        } elsif ($line =~ /^Text:\s*(.*)/) {
          $msg_data{text} = $1;
          # Text might span multiple lines, so collect the rest
          my @remaining_lines = split /\n/, $block;
          my $in_text = 0;
          my @text_lines;
          for my $remaining_line (@remaining_lines) {
            if ($remaining_line =~ /^Text:\s*(.*)/) {
              $in_text = 1;
              push @text_lines, $1 if $1;
            } elsif ($in_text && $remaining_line =~ /^Status:/) {
              last;
            } elsif ($in_text) {
              $remaining_line =~ s/^\s+|\s+$//g;
              push @text_lines, $remaining_line if $remaining_line;
            }
          }
          $msg_data{text} = join("\n", @text_lines);
        } elsif ($line =~ /^Status:\s*(.+)/) {
          $msg_data{status} = $1;
        }
      }
      
      # Only process if we have the required fields
      if ($msg_data{sender} && $msg_data{text} && defined $msg_data{index}) {
        warn "Found SMS: phone=$msg_data{sender}, index=$msg_data{index}, message=$msg_data{text}"; # Debug log
        
        my $sms = {
          phone     => $msg_data{sender},
          message   => $msg_data{text},
          timestamp => $msg_data{date},
          msg_id    => $msg_data{index},
        };
        
        push @messages, $sms;
      }
    }
  } else {
    warn "SMS Device Messages Request Failed: " . $tx->result->code . " - " . $tx->result->message;
  }
  
  return \@messages;
}

1;