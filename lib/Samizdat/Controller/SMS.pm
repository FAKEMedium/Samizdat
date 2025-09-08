package Samizdat::Controller::SMS;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Data::Dumper;

sub index ($self) {
  my $formdata = {};
  my $accept = $self->req->headers->{headers}->{accept}->[0] // '';
  
  if ($accept =~ /json/) {
    $formdata->{ip} = $self->tx->remote_address;
    if ($self->req->method =~ /^(POST)$/i) {
      my $valid = {};
      my $errors = {};
      my $v = $self->validation;
      
      for my $field (qw(to message)) {
        $formdata->{$field} = $self->param($field);
        if (!$v->required($field, 'trim', 'not_empty')->is_valid) {
          $valid->{$field} = "is-invalid";
          $errors->{$field} = $self->app->__('This field is required');
          $v->error($field => ['empty_field']);
        } else {
          # Additional validation for phone number
          if ($field eq 'to') {
            # Basic phone number validation (can be enhanced)
            if ($formdata->{$field} !~ /^\+?[1-9]\d{1,14}$/) {
              $valid->{$field} = "is-invalid";
              $errors->{$field} = $self->app->__('Please enter a valid phone number');
              $v->error($field => ['invalid_phone']);
            } else {
              $valid->{$field} = "is-valid";
              $errors->{$field} = '';
            }
          } elsif ($field eq 'message') {
            # Check message length (SMS limit)
            if (length($formdata->{$field}) > 160) {
              $valid->{$field} = "is-invalid";
              $errors->{$field} = $self->app->__('Message must be 160 characters or less');
              $v->error($field => ['message_too_long']);
            } else {
              $valid->{$field} = "is-valid";
              $errors->{$field} = '';
            }
          } else {
            $valid->{$field} = "is-valid";
            $errors->{$field} = '';
          }
        }
      }
      
      if ($v->has_error) {
        $formdata->{success} = 0;
      } else {
        my $result = $self->sms->send_sms($formdata->{to}, $formdata->{message});
        if ($result->{success}) {
          $formdata->{success} = 1;
          $formdata->{tx_id} = $result->{tx_id};
          $formdata->{message_text} = $self->app->__('SMS sent successfully');
        } else {
          $formdata->{success} = 0;
          $formdata->{error} = { reason => 'send_failed' };
          $errors->{general} = $result->{message} || $self->app->__('Failed to send SMS');
        }
      }
      $formdata->{errors} = $errors;
      $formdata->{valid} = $valid;
    }
    
    # Return JSON response for both POST and GET
    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $formdata, status => 200);
  }
  
  # Handle regular GET request (return HTML page)
  my $title = $self->app->__('SMS');
  my $web = { title => $title };
  $web->{script} = ($web->{script} // '') . $self->render_to_string(template => 'sms/index', format => 'js');
  $web->{script} .= $self->render_to_string(template => 'sms/chunks/sendform', format => 'js');
  $web->{sidebar} = ($web->{sidebar} // '') . $self->render_to_string(template => 'sms/chunks/sendform');
  return $self->render(web => $web, title => $title, template => 'sms/index', headline => 'chunks/pagination', status => 200);
}

sub send ($self) {
  my $to = $self->param('to');
  my $message = $self->param('message');
  
  unless ($to && $message) {
    return $self->render(json => {
      success => 0,
      error => 'Missing required parameters: to, message'
    });
  }
  
  my $result = $self->sms->send_sms($to, $message);
  
  $self->render(json => $result);
}

sub receive ($self) {
  my $messages = $self->sms->receive_sms();
  
  $self->render(json => {
    success => 1,
    messages => $messages,
    count => scalar @$messages
  });
}

sub messages ($self) {
  my $limit = $self->param('limit') || $self->app->config->{sms}->{teltonika}->{perpage} || 50;
  my $offset = $self->param('offset') || 0;
  my $direction = $self->param('direction');
  my $phone = $self->param('phone');
  my $need_total = $self->param('total');
  
  my $messages = $self->sms->get_messages(
    limit => $limit,
    offset => $offset,
    direction => $direction,
    phone => $phone,
  );
  
  my $result = {
    success => 1,
    messages => $messages,
    count => scalar @$messages
  };
  
  # Add total count if requested (for pagination)
  if ($need_total) {
    $result->{total} = $self->sms->count_messages(
      direction => $direction,
      phone => $phone,
    );
  }
  
  $self->render(json => $result);
}

sub status ($self) {
  my $status = $self->sms->get_status();
  
  $self->render(json => {
    success => 1,
    status => $status
  });
}

sub delete ($self) {
  my $id = $self->param('id');
  
  unless ($id) {
    return $self->render(json => {
      success => 0,
      error => 'Missing message ID'
    });
  }
  
  my $deleted = $self->sms->delete_message($id);
  
  $self->render(json => {
    success => $deleted > 0 ? 1 : 0,
    deleted => $deleted
  });
}


sub conversation ($self) {
  my $phone = $self->param('phone');
  my $formdata = { phone => $phone };
  my $accept = $self->req->headers->{headers}->{accept}->[0] // '';
  
  if ($accept =~ /json/) {
    # Return JSON response for AJAX requests
    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $formdata, status => 200);
  }
  
  # Handle regular GET request (return HTML page)  
  my $title = $self->app->__('SMS Conversation');
  my $web = { title => $title, phone => $phone };
  $web->{script} = ($web->{script} // '') . $self->render_to_string(template => 'sms/conversation/index', format => 'js');
  $web->{script} .= $self->render_to_string(template => 'sms/chunks/sendform', format => 'js');
  $web->{sidebar} = ($web->{sidebar} // '') . $self->render_to_string(template => 'sms/chunks/sendform');
  return $self->render(web => $web, title => $title, template => 'sms/conversation/index', headline => 'chunks/pagination', status => 200);
}

sub sync ($self) {
  my $new_messages = $self->sms->sync_messages();
  
  $self->render(json => {
    success => 1,
    new_messages => $new_messages,
    message => "Sync completed. $new_messages new messages retrieved."
  });
}

sub webhook ($self) {
  # Get SMS parameters from Teltonika device
  my $phone = $self->param('phone') || $self->param('from') || $self->param('sender');
  my $message = $self->param('message') || $self->param('text');
  my $timestamp = $self->param('timestamp') || $self->param('time');
  my $msg_id = $self->param('id') || $self->param('msg_id');
  
  warn "SMS webhook received from " . $self->tx->remote_address . ": phone=$phone, message=$message, id=$msg_id";
  
  # Validate required parameters
  unless ($phone && $message) {
    warn "SMS webhook: Missing required parameters";
    return $self->render(json => {
      success => 0,
      error => 'Missing required parameters'
    }, status => 400);
  }
  
  # Store incoming SMS in database
  if ($self->database) {
    $self->sms->store_message({
      direction => 'inbound',
      phone => $phone,
      message => $message,
      msg_id => $msg_id,
      status => 'received',
      received_at => \'NOW()',
    });
  }
  
  return $self->render(json => {
    success => 1,
    message => 'SMS received and stored'
  });
}

sub access ($self) {
  # Simple access control - check if user is authenticated
  my $authcookie = $self->cookie($self->config->{account}->{authcookiename});
  my $user;
  
  if ($authcookie) {
    $user = $self->app->account->session($authcookie);
  }
  
  # For now, just check if user exists (until privileges system is implemented)
  unless ($user) {
    my $accept = $self->req->headers->accept // '';
    
    if ($accept =~ /json/) {
      return $self->render(json => {
        success => 0,
        error => 'Access denied'
      }, status => 403);
    } else {
      $self->flash(error => $self->app->__('Access denied'));
      return $self->redirect_to('/account/login');
    }
  }
  
  return 1;
}

1;