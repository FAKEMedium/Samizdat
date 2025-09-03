package Samizdat::Controller::SMS;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Data::Dumper;

sub index ($self) {
  my $method = lc $self->req->method;
  my $web = { docpath => 'sms/index.html' };
  my $title = $self->app->__('SMS Management');
  my $valid = {};
  
  # Get recent messages
  my $messages = $self->sms->get_messages(limit => 20);
  my $status = $self->sms->get_status();
  
  if ('post' eq $method) {
    my $v = $self->validation;
    my $form = {
      to      => $self->param('to'),
      message => $self->param('message'),
    };
    
    $valid->{to} = $v->required('to', 'trim', 'not_empty')->is_valid ? " is-valid" : " is-invalid";
    $valid->{message} = $v->required('message', 'trim', 'not_empty')->is_valid ? " is-valid" : " is-invalid";
    
    if (!$v->has_error) {
      my $result = $self->sms->send_sms($form->{to}, $form->{message});
      
      if ($result->{success}) {
        $self->flash(success => $self->app->__('SMS sent successfully'));
        $form = {}; # Clear form on success
      } else {
        $self->flash(error => $self->app->__('Failed to send SMS: {error}', error => $result->{message}));
      }
      
      # Refresh messages after send
      $messages = $self->sms->get_messages(limit => 20);
    }
    
    $self->stash(form => $form);
    delete $web->{docpath};
  }
  
  $self->stash(messages => $messages);
  $self->stash(status => $status);
  $self->stash(valid => $valid);
  $self->stash(title => $title);
  $self->stash(template => 'sms/index');
  $self->render(web => $web);
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
  my $limit = $self->param('limit') || 50;
  my $offset = $self->param('offset') || 0;
  my $direction = $self->param('direction');
  my $phone = $self->param('phone');
  
  my $messages = $self->sms->get_messages(
    limit => $limit,
    offset => $offset,
    direction => $direction,
    phone => $phone,
  );
  
  $self->render(json => {
    success => 1,
    messages => $messages,
    count => scalar @$messages
  });
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

sub manager ($self) {
  my $web = {};
  my $title = $self->app->__('SMS Manager');
  
  # Get all messages with pagination
  my $page = $self->param('page') || 1;
  my $limit = 25;
  my $offset = ($page - 1) * $limit;
  
  my $messages = $self->sms->get_messages(
    limit => $limit,
    offset => $offset
  );
  
  my $status = $self->sms->get_status();
  
  $self->stash(messages => $messages);
  $self->stash(status => $status);
  $self->stash(page => $page);
  $self->stash(title => $title);
  $self->stash(template => 'sms/manager');
  $self->render(web => $web);
}

sub access ($self) {
  # Simple access control - check if user is authenticated
  my $user = $self->session('user');
  
  unless ($user && $user->{privileges} && $user->{privileges}->{sms}) {
    $self->flash(error => $self->app->__('Access denied'));
    return $self->redirect_to('/account/login');
  }
  
  return 1;
}

1;