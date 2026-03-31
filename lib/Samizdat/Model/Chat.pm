package Samizdat::Model::Chat;

use Mojo::Base -base, -signatures;
use Mojo::UserAgent;
use Mojo::JSON qw(encode_json from_json to_json);
use Mojo::Util qw(md5_sum);
use Encode qw(decode);
use Time::Piece;

has 'config';
has 'redis';
has 'ua' => sub {
  my $ua = Mojo::UserAgent->new;
  $ua->transactor->name('Samizdat Chat');
  $ua->request_timeout(120);
  $ua->inactivity_timeout(300);
  return $ua;
};

sub api_key ($self) {
  return $self->config->{api_key} // $ENV{ANTHROPIC_API_KEY} // '';
}

sub model ($self) {
  return $self->config->{model} // 'claude-sonnet-4-20250514';
}

sub max_tokens ($self) {
  return $self->config->{max_tokens} // 8192;
}

sub system_prompt ($self) {
  return $self->config->{system_prompt} // '';
}


# Stream a chat completion over a websocket connection
sub stream ($self, $ws, $messages) {
  my $api_key = $self->api_key;
  unless ($api_key) {
    $ws->send(to_json({ type => 'error', error => 'No API key configured' }));
    $ws->finish;
    return;
  }

  my $body = {
    model      => $self->model,
    max_tokens => $self->max_tokens,
    stream     => \1,
    messages   => $messages,
  };

  my $system = $self->system_prompt;
  $body->{system} = $system if $system;

  my $buffer = '';
  my $tx = $self->ua->build_tx(POST => 'https://api.anthropic.com/v1/messages' => {
    'Content-Type'      => 'application/json',
    'x-api-key'         => $api_key,
    'anthropic-version'  => '2023-06-01',
  } => json => $body);

  my $done_sent = 0;

  # Read SSE events as they arrive
  $tx->res->content->unsubscribe('read')->on(read => sub ($content, $bytes) {
    $buffer .= $bytes;

    # SSE format: optional "event: type\n" followed by "data: json\n\n"
    while ($buffer =~ s/^(?:event:\s*[^\n]*\n)*data:\s*(.*?)\n\n//s) {
      my $data = $1;
      next if $data eq '[DONE]';

      my $decoded = eval { decode('UTF-8', $data) } // $data;
      my $event = eval { from_json($decoded) };
      next unless $event;

      my $type = $event->{type} // '';

      if ($type eq 'content_block_delta') {
        my $text = $event->{delta}{text} // '';
        $ws->send(to_json({ type => 'delta', text => $text })) if $text;
      }
      elsif ($type eq 'message_stop') {
        $done_sent = 1;
        $ws->send(to_json({ type => 'done' }));
      }
      elsif ($type eq 'error') {
        $done_sent = 1;
        $ws->send(to_json({ type => 'error', error => $event->{error}{message} // 'Unknown error' }));
      }
    }
  });

  $self->ua->start_p($tx)->then(sub ($tx) {
    # Check for HTTP-level errors (non-streaming response)
    unless ($tx->result->is_success) {
      my $err = eval { $tx->result->json->{error}{message} } // $tx->result->message;
      $ws->send(to_json({ type => 'error', error => "API error: $err" }));
      $done_sent = 1;
    }
    $ws->send(to_json({ type => 'done' })) unless $done_sent;
  })->catch(sub ($err) {
    $ws->send(to_json({ type => 'error', error => "Request failed: $err" }));
    $ws->send(to_json({ type => 'done' })) unless $done_sent;
  });
}


# Conversation persistence via Redis

sub _key ($self, $id = '') {
  return $id ? "chat:conversation:$id" : 'chat:conversations';
}

sub list_conversations ($self) {
  my $db = $self->redis->db;
  my $ids = $db->smembers($self->_key);
  my @conversations;
  for my $id (@$ids) {
    my $json = $db->get($self->_key($id));
    next unless $json;
    my $conv = eval { from_json($json) };
    push @conversations, $conv if $conv;
  }
  return [ sort { ($b->{updated} // '') cmp ($a->{updated} // '') } @conversations ];
}

sub get_conversation ($self, $id) {
  my $json = $self->redis->db->get($self->_key($id));
  return undef unless $json;
  return eval { from_json($json) };
}

sub save_conversation ($self, $title, $messages) {
  my $id = md5_sum(time . $$ . rand());
  my $now = gmtime->strftime('%Y-%m-%dT%H:%M:%SZ');
  my $conversation = {
    id       => $id,
    title    => $title,
    messages => $messages,
    created  => $now,
    updated  => $now,
  };
  my $db = $self->redis->db;
  $db->set($self->_key($id), encode_json($conversation));
  $db->sadd($self->_key, $id);
  return { success => 1, id => $id };
}

sub delete_conversation ($self, $id) {
  my $db = $self->redis->db;
  $db->del($self->_key($id));
  $db->srem($self->_key, $id);
  return { success => 1 };
}


1;
