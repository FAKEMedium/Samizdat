package Samizdat::Model::Fortnox;

use Mojo::Base -base, -signatures;
use Mojo::Promise;
use Mojo::JSON qw(decode_json encode_json from_json);
use Mojo::Collection qw(c);
use Mojo::UserAgent;
use Mojo::File qw(path);
use Mojo::Util qw(secure_compare);
use Hash::Merge;
use Data::Dumper;
use Crypt::AuthEnc::GCM;
use Crypt::PRNG qw(random_bytes);
use MIME::Base64 qw(encode_base64 decode_base64);

has 'config';
has 'redis';
has 'session';
has 'cache' => sub ($self) {
  return $self->_loadCache();
};
has 'merger' => sub {
  state $merger = Hash::Merge->new();
  return $merger;
};
has 'ua' => sub ($self) {
  state $ua = Mojo::UserAgent->new->max_redirects(0)->connect_timeout(3)->request_timeout(2);
  return $ua;
};

# Get session-specific Redis key
sub _getRedisKey ($self) {
  my $base_key = 'fortnox:cache';

  # If we have a session, make it session-specific
  if ($self->session && $self->session->{fortnox_session_id}) {
    return $base_key . ':' . $self->session->{fortnox_session_id};
  }

  # Generate a session ID if we don't have one
  if ($self->session) {
    my $session_id = encode_base64(random_bytes(16), '');
    $session_id =~ s/[^a-zA-Z0-9]//g;  # Remove special chars
    $self->session->{fortnox_session_id} = $session_id;
    return $base_key . ':' . $session_id;
  }

  # Fallback to non-session key (backwards compatibility)
  return $base_key;
}

# Get or create encryption key from session
sub _getEncryptionKey ($self) {
  return undef unless $self->session;

  # Check if session already has an encryption key
  my $key = $self->session->{fortnox_encrypt_key};

  if (!$key) {
    # Generate new 256-bit (32-byte) key for AES-256
    $key = encode_base64(random_bytes(32), '');
    $self->session->{fortnox_encrypt_key} = $key;
  }

  return decode_base64($key);
}

# Encrypt data for Redis storage
sub _encrypt ($self, $data) {
  my $key = $self->_getEncryptionKey();
  return $data unless $key;  # If no session, store unencrypted (fallback)

  my $iv = random_bytes(12);  # 96-bit IV for GCM
  my $gcm = Crypt::AuthEnc::GCM->new('AES', $key, $iv);

  my $ciphertext = $gcm->encrypt_add($data);
  my $tag = $gcm->encrypt_done();

  # Return: encrypted marker + IV + tag + ciphertext (all base64 encoded)
  # Format: ENC1:iv_base64:tag_base64:ciphertext_base64
  return 'ENC1:' . encode_base64($iv, '') . ':' . encode_base64($tag, '') . ':' . encode_base64($ciphertext, '');
}

# Decrypt data from Redis
sub _decrypt ($self, $encrypted) {
  # Check if data is encrypted (starts with ENC1:)
  return $encrypted unless $encrypted =~ /^ENC1:/;

  my $key = $self->_getEncryptionKey();
  return '' unless $key;  # No key available, can't decrypt

  # Remove ENC1: prefix and split
  $encrypted =~ s/^ENC1://;
  my ($iv_b64, $tag_b64, $ciphertext_b64) = split(':', $encrypted, 3);

  my $iv = decode_base64($iv_b64);
  my $tag = decode_base64($tag_b64);
  my $ciphertext = decode_base64($ciphertext_b64);

  my $plaintext;
  eval {
    my $gcm = Crypt::AuthEnc::GCM->new('AES', $key, $iv);
    $plaintext = $gcm->decrypt_add($ciphertext);
    $gcm->decrypt_done($tag) or die "Authentication tag verification failed";
  };

  # If decryption fails, return empty (cache will be regenerated)
  return '' if $@;

  return $plaintext;
}

sub _loadCache ($self) {
  my $cache;
  my $redis_key = $self->_getRedisKey();

  # Try to load from Redis
  my $encrypted = $self->redis->db->get($redis_key);
  if ($encrypted) {
    # Decrypt if we have a session
    my $json = $self->_decrypt($encrypted);
    eval { $cache = decode_json($json) if $json; };
  }

  if (!$cache || !exists($cache->{state})) {
    $cache = {
      'state'   => 'login',
      'access'  => '',
      'refresh' => '',
      'code'    => ''
    };
    $self->_saveCache($cache);
  }
  return $cache;
}

sub Cache ($self, $cache = undef) {
  if ($cache) {
    $self->_saveCache($cache);
    return $cache;
  }
  return $self->cache;
}

sub _saveCache ($self, $cache) {
  my $redis_key = $self->_getRedisKey();
  my $json = encode_json($cache);

  # Encrypt before storing
  my $encrypted = $self->_encrypt($json);
  $self->redis->db->set($redis_key => $encrypted);
}

sub saveCache ($self) {
  $self->_saveCache($self->cache);
}

sub updateCache ($self, $resource = undef) {
  my $resources = [];
  if ($resource) {
    push @{ $resources }, $resource;
  } else {
    push @{ $resources }, sort {$a cmp $b} keys %{ $self->config->{apps}->{$self->config->{selectedapp}}->{resources} };
  }
  for my $resource (@{ $resources }) {
    my $resourceconfig = $self->config->{apps}->{$self->config->{selectedapp}}->{resources}->{$resource};
    if (exists($resourceconfig->{cache}) && int $resourceconfig->{cache}) {
      my $list = [];
      my $page = 1;
      my $fetch = {};
      my $object = exists($resourceconfig->{object}) ? $resourceconfig->{object} : $resource;
      do {
        $fetch = $self->callAPI($resource, 'get', 0, {qp => {page => $page}});

        # Check for errors
        if (ref($fetch) eq 'HASH' && exists($fetch->{error}) && $fetch->{error}) {
          # Log the error and stop fetching
          say sprintf("Fortnox API error for %s: %s", $resource, $fetch->{message} // 'Unknown error');
          last;
        }

        if (ref($fetch) eq 'HASH' && exists($fetch->{$object})) {
          push(@{$list}, @{$fetch->{$object}});
        }
        $page++;
      } until (!ref($fetch) || !exists($fetch->{'MetaInformation'}) or $fetch->{'MetaInformation'}->{'@CurrentPage'} >= $fetch->{'MetaInformation'}->{'@TotalPages'});
      $self->cache->{$self->config->{selectedapp}}->{$resource} = $list;
      $self->saveCache;
    }
  }
  $self->saveCache;

  # Ensure we return at least an empty array if the cache entry doesn't exist
  if ($resource) {
    return $self->cache->{$self->config->{selectedapp}}->{$resource} // [];
  } else {
    return $self->cache;
  }
}

sub removeCache ($self) {
  # Clear the cache in Redis
  my $redis_key = $self->_getRedisKey();
  $self->redis->db->del($redis_key);

  # Clear session data
  if ($self->session) {
    delete $self->session->{fortnox_encrypt_key};
    delete $self->session->{fortnox_session_id};
  }

  # Reset to empty cache
  $self->Cache({
    'state'   => '',
    'access'  => '',
    'refresh' => '',
    'code'    => ''
  });
}

sub getLogin($self) {
  $self->cache->{state} = 'login';
  my $response = $self->ua->get($self->config->{oauth2}->{url} . '/auth' => {Accept => '*/*'} => form => {
    client_id     => $self->config->{apps}->{$self->config->{selectedapp}}->{clientid},
    scope         => $self->config->{apps}->{$self->config->{selectedapp}}->{scope},
    access_type   => $self->config->{oauth2}->{access_type},
    account_type  => $self->config->{oauth2}->{account_type},
    state         => $self->cache->{state},
    response_type => 'code',
  })->result;
  if ($response->headers->header('Location')) {
    $self->cache->{state} = 'code';
    $self->saveCache;
    #        return sprintf($response->headers->header('Location'));
    my $redirect = sprintf("https://apps.fortnox.se%s\n", $response->headers->header('Location'));
    return $redirect;
  }
  return 0;
}

sub getToken ($self, $refresh = 0) {
  my $url = Mojo::URL->new($self->config->{oauth2}->{url} . '/token')->userinfo(sprintf('%s:%s',
    $self->config->{apps}->{$self->config->{selectedapp}}->{clientid},
    $self->config->{apps}->{$self->config->{selectedapp}}->{secret}
  ));
  my $response;
  if ($refresh) {
    $response = $self->ua->post($url => { Accept => '*/*' } => form => {
      grant_type    => 'refresh_token',
      refresh_token => $self->cache->{refresh},
    })->result;
  } else {
    $response = $self->ua->post($url => { Accept => '*/*' } => form => {
      grant_type   => 'authorization_code',
      code         => $self->cache->{code},
      redirect_uri => $self->config->{oauth2}->{redirect_uri},
    })->result;
  }
#  $response->save_to($self->config->{cachefile});
  if ($response->json('/error')) {
    return 0;
  } else {
    $self->cache->{code} = '';
    $self->cache->{refresh} = $response->json('/refresh_token');
    $self->cache->{access} = $response->json('/access_token');
    $self->cache->{state} = 'api';
    $self->saveCache;
    return 1;
  }
}


sub callAPI ($self, $resource, $method, $id = 0, $options = {}, $action = '') {
  if (!exists($self->cache->{access})) {
    return $self->getLogin();
  }
  $resource = lc $resource;
  my $url = $self->config->{apiurl};
  if ('put' eq $method) {
    return 0 if (!$id);
    $url = ('' eq $action) ? sprintf("%s%s/%d", $url, $resource, $id) : sprintf("%s%s/%d/%s", $url, $resource, $id, $action);
  } elsif ('delete' eq $method) {
    return 0 if (!$id);
    $url = sprintf("%s%s/%d", $url, $resource, $id);
  } elsif ('post' eq $method) {
    $url = sprintf("%s%s", $url, $resource);
  } elsif ('get' eq $method) {
    if ($id) {
      if ('' eq $action) {
        $url = sprintf("%s%s/%s", $url, $resource, $id);
      } else {
        $url = sprintf("%s%s/%d/%s", $url, $resource, $id, $action);
      }
    } else {
      $url = sprintf("%s%s", $url, $resource);
    }
  }
  my $done = 0;
  my $qp = {};

  if (!$id) {
    $qp = $options->{qp} if (exists($options->{qp}));
  }
  while (!$done) {
    $qp = $self->merger->merge($self->config->{apps}->{$self->config->{selectedapp}}->{resources}->{$resource}->{qp}, $qp);
    $qp = $self->merger->merge($options->{qp}, $qp);
    for my $p (qw/sortby sortorder filter limit offset page/) {
      #          delete $qp->{$p} if (exists($qp->{$p}) and ($qp->{$p} eq ''));
    }
    #        say $resource . Dumper $qp;
    my $tx;
    #        say $url;
    if ('get' eq $method) {
      $tx = $self->ua->build_tx('GET' => $url => {Accept => '*/*'} => form => $qp);
    } else {
      if ($resource =~ /^(Archive|Inbox)$/) {
        if (exists($options->{qp}->{file})) {
          if (my $content = path->new($options->{qp}->{file})->slurp) {
            delete $options->{qp}->{file};
            $options->{qp}->{File} = {
              $content
            };
          }
        }
      }
      $tx = $self->ua->build_tx(uc($method) => $url => {Accept => '*/*'} => json => $options);
#      say Dumper $tx;
      $tx->req->headers->content_type('application/json');
    }
    $tx->req->headers->add(Authorization => sprintf('Bearer %s', $self->cache->{access}));
    $tx = $self->ua->start($tx);
    #        say $tx->req->to_string;

    if (403 == $tx->result->code) {
      say sprintf('%s %s', $tx->result->code, Dumper $tx->result->body);
      $self->cache->{access} = '';
      $self->cache->{state} = '';
      $self->cache->{refresh} = '';
      $self->saveCache;
      $done = 1;
      return {};
    } elsif (404 == $tx->result->code) {
      $done = 1;
      return { error => 1, code => 404, message => 'Resource not found' };
    } elsif (400 == $tx->result->code) {
      say sprintf('%s %s %s', $url, $tx->result->code, Dumper $tx->result->body);
      $done = 1;
      my $error_data = {};
      eval { $error_data = decode_json($tx->result->body); };
      return { error => 1, code => 400, message => $error_data->{ErrorInformation}->{message} // 'Bad Request' };
    } elsif ($tx->result->code =~ /^4/) {
      #          say sprintf('%s %s', $tx->result->code, Dumper $tx->result->body);

      #          if (2000311 == $result->{'ErrorInformation'}->{Code}) {}
      say sprintf('%s %s', $tx->result->code, Dumper $tx->result->body);
      $self->cache->{access} = '';
      $self->cache->{state} = 'code';
      $self->saveCache;
      $self->getToken(1);
    } elsif (200 == $tx->result->code || 201 == $tx->result->code) {
      #          say Dumper $tx->result->body;
      my $result = decode_json($tx->result->body);
      #          say Dumper $result;
      return $result;
    }
    sleep 2;
  }
}


sub postInbox ($self, $file, $folderid = 'inbox_kf') {
  my $url = sprintf("%s%s?folderid=%s", $self->config->{apiurl}, 'inbox', $folderid);
  my $headers = {
    'Content-Type'  => 'multipart/form-data',
    'Authorization' => sprintf('Bearer %s', $self->cache->{access})
  };
  my $tx;
  if (1) {
    my $tx = $self->ua->build_tx('POST' => $url => $headers => form => {
      file => { file => $file }
    });
#    say Dumper $tx;
    $tx = $self->ua->start($tx);
#    say sprintf('%s %s %s', $url, $tx->result->code, Dumper $tx->result->body);

    if (201 == $tx->result->code) {
      return decode_json($tx->result->body);
    }

    #  say Dumper $tx;
#    return $tx->result;
  }
}


sub attachment ($self, $method, $fileid, $entityid, $entitype = 'F') {
  my $url = $self->config->{attachmentsurl};
  my $tx;
  # say $url;
  if ('get' eq $method) {
    $tx = $self->ua->build_tx('GET' => $url => {Accept => '*/*'} => form => {
      entityid      => $entityid,
      entitytype    => $entitype,
    });
  } else {
    $tx = $self->ua->build_tx(uc($method) => $url => {Accept => '*/*'} => json => [{
      fileId        => $fileid,
      entityId      => $entityid,
      entityType    => $entitype,
      includeOnSend => 'true',
    }]);
    $tx->req->headers->content_type('application/json');
  }
  $tx->req->headers->add(Authorization => sprintf('Bearer %s', $self->cache->{access}));
  $tx = $self->ua->start($tx);
#  say sprintf('%s %s %s', $url, $tx->result->code, Dumper $tx->result->body);

  if (200 == $tx->result->code) {
#    say Dumper $tx->result->body;
    my $result = decode_json($tx->result->body);
    #          say Dumper $result;
    return $result;
  }
}

sub financialYears ($self) {
  $self->updateCache('FinancialYears') if (!exists($self->cache->{$self->config->{selectedapp}}->{FinancialYears}));
  return Mojo::Collection->new(@{ $self->cache->{$self->config->{selectedapp}}->{FinancialYears} });
}

sub accounts ($self) {
  $self->updateCache('Accounts') if (!exists($self->cache->{$self->config->{selectedapp}}->{Accounts}));
  return Mojo::Collection->new(@{ $self->cache->{$self->config->{selectedapp}}->{Accounts} });
}

sub postInvoice ($self, $payload) {
  my $result = $self->callAPI('Invoices', 'post', 0, $payload);
#  say Dumper $result;
  return $result;
}

sub externalInvoice ($self, $DocumentNumber = 0) {
  if ($DocumentNumber) {
    my $result = $self->callAPI('Invoices', 'put', $DocumentNumber, {}, 'externalprint');
#    say Dumper $result;
    return $result;
  }
}

sub creditInvoice ($self, $DocumentNumber = 0) {
  if ($DocumentNumber) {
    my $result = $self->callAPI('Invoices', 'put', $DocumentNumber, {}, 'credit');
    say Dumper $result;
    return $result;
  }
}

sub getInvoice ($self, $DocumentNumber = 0, $options = {'qp' => {'limit' => 500, page => 1}}) {
  my $list = $self->callAPI('Invoices', 'get', $DocumentNumber, $options);
}

sub putInvoice ($self, $DocumentNumber = 0) {
  return 0 if (!$DocumentNumber);
  my $result = $self->callAPI('Invoices', 'put', $DocumentNumber);
}

sub getInvoicePayment ($self, $Number = 0, $options = {'qp' => {'limit' => 500, page => 1}}) {
  my $result = $self->callAPI('InvoicePayments', 'get', $Number, $options);
  say Dumper $result;
  return $result;
}

sub getCustomer ($self, $CustomerNumber = 0, $options = {'qp' => {'limit' => 500, page => 1}}) {
  my $result = $self->callAPI('Customers', 'get', $CustomerNumber, $options);
  say Dumper $result;
  return $result;
}

sub putCustomer ($self, $CustomerNumber, $data = {}) {
  my $result = $self->callAPI('Customers', 'put', $CustomerNumber, $data);
  return $result;
}

sub postCustomer ($self, $data =  {}) {
  my $result = $self->callAPI('Customers', 'post', 0, $data);
  return $result;
}

sub deleteCustomer ($self, $CustomerNumber) {
  my $result = $self->callAPI('Customers', 'delete', $CustomerNumber);
  return $result;
}

sub putCurrency ($self, $Currency, $data = {}) {
  my $result = $self->callAPI('Currencies', 'put', $Currency, $data);
  return $result;
}

sub getCurrency ($self, $Currency = 0, $options = {'qp' => {'limit' => 500, page => 1}}) {
  my $result = $self->callAPI('Currencies', 'get', $Currency, $options);
  return $result;
}

sub postCurrency ($self, $data = {}) {
  my $result = $self->callAPI('Currencies', 'post', 0, $data);
  return $result;
}

sub getAccount ($self, $Number = 0, $options = {'qp' => {'limit' => 500, page => 1}}) {
  my $result = $self->callAPI('Accounts', 'get', $Number, $options);
  return $result;
}

sub putAccount ($self, $Number = 0, $data = {}) {
  my $result = $self->callAPI('Accounts', 'put', $Number, $data);
  return $result;
}

sub postAccount ($self, $data = {}) {
  my $result = $self->callAPI('Accounts', 'post', 0, $data);
  return $result;
}

sub getArticle ($self, $ArticleNumber = 0, $options = {'qp' => {'limit' => 500, page => 1}}) {
  if ($ArticleNumber) {
    return $self->callAPI('Articles', 'get', $ArticleNumber, $options);
  } else {
    return { Articles => $self->updateCache('Articles') };
  }
}

sub postArticle ($self, $article = {}) {
  return 0 if (!exists($article->{Article}));
  return 0 if (!exists($article->{Article}->{ArticleNumber}));
  $article->{Article}->{Type} = 'SERVICE' if (!exists($article->{Article}->{Type}));
  my $result = $self->callAPI('Articles', 'post', 0, $article);
  return $result;
}


sub getArchive ($self, $id = 0, $options = {'qp' => {'limit' => 500, page => 1}}) {
  if ($id) {
    # This is possibly a file
    return $self->callAPI('Archive', 'get', $id, $options);
  } else {
    #This is a folder with folders and files
    my $result = $self->callAPI('Archive', 'get', 0, $options);
    return $result;
  }
}

1;