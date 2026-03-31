package Samizdat::Controller::Chat;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::JSON qw(encode_json from_json to_json);
use Encode qw(decode);


sub index ($self) {
  my $title = $self->app->__('Chat');
  my $web = { title => $title };
  my $accept = $self->req->headers->accept // '';

  if ($accept !~ /json/) {
    $web->{sidebar} = $self->render_to_string(template => 'chat/chunks/sidebar', format => 'html');
    $web->{script} = $self->render_to_string(format => 'js', template => 'chat/index');
    $web->{css} = $self->render_to_string(format => 'css', template => 'chat/index');
    return $self->render(web => $web, title => $title, template => 'chat/index',
      headline => 'chat/chunks/headline');
  }
}


sub stream ($self) {
  # Check admin access manually — the access helper renders JSON which breaks websockets
  my $authcookie = $self->cookie($self->config->{manager}->{account}->{authcookiename});
  if ($authcookie) {
    my $session = $self->app->account->session($authcookie);
    my $username = $session->{username} // '';
    my $admins = $self->config->{manager}->{account}->{admins} // {};
    my $superadmins = $self->config->{manager}->{account}->{superadmins} // {};
    unless (exists $admins->{$username} || exists $superadmins->{$username}) {
      $self->send(to_json({ type => 'error', error => 'Admin access required' }));
      return $self->finish;
    }
  } else {
    $self->send(to_json({ type => 'error', error => 'Authentication required' }));
    return $self->finish;
  }

  $self->inactivity_timeout(300);

  $self->on(message => sub ($self, $msg) {
    # Websocket text frames are UTF-8 bytes; decode to Perl string then parse JSON
    my $text = eval { decode('UTF-8', $msg) } // $msg;
    my $data = eval { from_json($text) };
    if ($@ || !$data) {
      $self->app->log->error("Chat JSON parse error: $@");
      return $self->send(to_json({ type => 'error', error => "Invalid JSON: $@" }));
    }

    my $messages = $data->{messages} // [];
    return $self->send(to_json({ type => 'error', error => 'No messages' })) unless @$messages;

    $self->app->chat->stream($self, $messages);
  });

  $self->on(finish => sub ($self, $code, $reason) {
    $self->app->log->debug("Chat WebSocket closed: $code");
  });
}


sub conversations ($self) {
  return unless $self->access({ admin => 1 });

  my $id = $self->stash('id') // '';

  if ($id) {
    my $conversation = $self->app->chat->get_conversation($id);
    return $self->render(json => { error => 'Not found' }, status => 404) unless $conversation;
    return $self->render(json => $conversation);
  }

  my $list = $self->app->chat->list_conversations;
  return $self->render(json => { conversations => $list });
}


sub save ($self) {
  return unless $self->access({ admin => 1 });

  my $data = $self->req->json;
  my $messages = $data->{messages} // [];
  return $self->render(json => { error => 'No messages' }, status => 400) unless @$messages;

  my $title = $data->{title} // substr($messages->[0]{content} // '', 0, 80);
  my $result = $self->app->chat->save_conversation($title, $messages);
  return $self->render(json => $result);
}


sub delete ($self) {
  return unless $self->access({ admin => 1 });

  my $id = $self->stash('id') // '';
  my $result = $self->app->chat->delete_conversation($id);
  return $self->render(json => $result);
}


1;
