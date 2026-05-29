package Samizdat::Model::Fortnox;

use Mojo::Base -base, -signatures;
use Mojo::Promise;
use Mojo::JSON qw(decode_json encode_json from_json);
use Mojo::Collection qw(c);
use Mojo::UserAgent;
use Mojo::File qw(path);
use Hash::Merge;
use Data::Dumper;

has 'config';
has 'cache';
has 'data' => sub ($self) {
  return $self->_loadCache();
};
has 'merger' => sub {
  state $merger = Hash::Merge->new();
  return $merger;
};
has 'ua' => sub ($self) {
  state $ua = Mojo::UserAgent->new->max_redirects(0)->connect_timeout(10)->request_timeout(30);
  return $ua;
};
has 'default_resources' => sub ($self) {
  return {
    'Accounts' => {
      'key' => 'Number',
      'cache' => 1,
      'qp' => {
        'sortby' => 'number',
        'sortorder' => 'ascending',
        'limit' => 500
      }
    },
    'AccountCharts' => {
      'cache' => 1,
      'qp' => {
        'limit' => 500
      }
    },
    'Archive' => {
      'cache' => 1
    },
    'Articles' => {
      'cache' => 1,
      'key' => 'ArticleNumber',
      'single' => {
        'name' => 'Article',
        'required' => ['Description']
      }
    },
    'Customers' => {
      'key' => 'CustomerNumber',
      'cache' => 1,
      'single' => {
        'name' => 'Customer',
        'required' => ['CustomerNumber']
      }
    },
    'FinancialYears' => {
      'key' => 'Id',
      'cache' => 1,
      'qp' => {
        'sortby' => 'fromdate',
        'sortorder' => 'descending',
        'limit' => 40
      }
    },
    'Inbox' => {
      'key' => 'Id'
    },
    'Invoices' => {
      'key' => 'DocumentNumber',
      'single' => {
        'name' => 'Invoice',
        'required' => ['CustomerNumber']
      },
      'cache' => 0,
      'qp' => {
        'sortby' => 'invoicedate',
        'sortorder' => 'descending',
        'limit' => 50
      }
    },
    'InvoiceAccruals' => {
      'key' => 'InvoiceNumber'
    },
    'InvoicePayments' => {
      'key' => 'Number',
      'cache' => 1,
      'single' => {
        'name' => 'InvoicePayment'
      },
      'required' => ['InvoiceNumber'],
      'qp' => {
        'sortby' => 'paymentdate',
        'sortorder' => 'descending',
        'limit' => 500
      }
    },
    'PredefinedAccounts' => {
      'key' => 'Name'
    },
    'PredefinedVoucherSeries' => {
      'key' => 'Name'
    },
    'Suppliers' => {
      'key' => 'SupplierNumber',
      'single' => 'Supplier',
      'cache' => 1,
      'qp' => {
        'limit' => 500
      }
    },
    'SupplierInvoiceAccruals' => {
      'key' => 'SupplierInvoiceNumber'
    },
    'SupplierInvoices' => {
      'key' => 'GivenNumber'
    },
    'SupplierInvoiceFileConnections' => {
      'key' => 'FileId'
    },
    'SupplierInvoicePayments' => {
      'key' => 'Number'
    },
    'Units' => {
      'key' => 'Code',
      'cache' => 1,
      'qp' => {
        'sortby' => 'code',
        'sortorder' => 'ascending',
        'limit' => 500
      }
    },
    'VoucherFileConnections' => {
      'key' => 'FileId',
      'cache' => 0,
      'qp' => {
        'sortby' => 'vouchernumber',
        'sortorder' => 'descending',
        'limit' => 500
      }
    },
    'Vouchers' => {
      'key' => undef,
      'cache' => 0,
      'object' => 'Voucher',
      'qp' => {
        'sortby' => 'vouchernumber',
        'sortorder' => 'descending',
        'limit' => 500
      }
    },
    'VoucherSeries' => {
      'cache' => 1,
      'object' => 'VoucherSeriesCollection',
      'qp' => {
        'sortorder' => 'descending',
        'limit' => 500
      }
    },
    'Currencies' => {
      'key' => 'currency',
      'single' => {
        'name' => 'Currency',
        'required' => ['currency', 'rate']
      },
      'cache' => 0,
      'qp' => {
        'sortby' => 'currency',
        'sortorder' => 'ascending',
        'limit' => 5
      }
    }
  };
};

has 'resources' => sub ($self) {
  # Merge config resources with default resources (config overrides defaults)
  my $config_resources = $self->config->{app}->{resources} // {};
  return $self->merger->merge($self->default_resources, $config_resources);
};


sub _loadCache ($self) {
  my $redis_key = 'fortnox:cache';

  # Try to load from cache (encryption handled by Cache model)
  my $cache = $self->cache->get($redis_key);

  if (!$cache || ref($cache) ne 'HASH' || !exists($cache->{state})) {
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
  return $self->data;
}


sub _saveCache ($self, $cache) {
  my $redis_key = 'fortnox:cache';

  # Encryption handled by Cache model
  $self->cache->set($redis_key => $cache);
}


sub saveCache ($self) {
  $self->_saveCache($self->data);
}


sub reload ($self) {
  # The model is a per-process singleton whose `data` is otherwise loaded from
  # Redis only once. Re-read the shared cache so token changes and logouts
  # performed by other hypnotoad workers take effect in this worker too.
  $self->data($self->_loadCache);
  return $self->data;
}


sub updateCache ($self, $resource = undef) {
  my $resources = [];
  if ($resource) {
    push @{ $resources }, $resource;
  } else {
    push @{ $resources }, sort {$a cmp $b} keys %{ $self->resources };
  }
  for my $resource (@{ $resources }) {
    my $resourceconfig = $self->resources->{$resource};
    if (exists($resourceconfig->{cache}) && int $resourceconfig->{cache}) {
      my $list = [];
      my $page = 1;
      my $fetch = {};
      my $has_error = 0;
      my $object = exists($resourceconfig->{object}) ? $resourceconfig->{object} : $resource;
      do {
        $fetch = $self->callAPI($resource, 'get', 0, {qp => {page => $page}});

        # Check for errors
        if (ref($fetch) eq 'HASH' && exists($fetch->{error}) && $fetch->{error}) {
          # Log the error and stop fetching
          say sprintf("Fortnox API error for %s: %s", $resource, $fetch->{message} // 'Unknown error');
          $has_error = 1;
        }

        if (!$has_error && ref($fetch) eq 'HASH' && exists($fetch->{$object})) {
          push(@{$list}, @{$fetch->{$object}});
        }
        $page++;
      } until ($has_error || !ref($fetch) || !exists($fetch->{'MetaInformation'}) or $fetch->{'MetaInformation'}->{'@CurrentPage'} >= $fetch->{'MetaInformation'}->{'@TotalPages'});

      # Return error if API failed
      if ($has_error) {
        return { error => 1, message => $fetch->{message} // 'API error' };
      }

      $self->data->{$resource} = $list;
      $self->saveCache;
    }
  }
  $self->saveCache;

  # Ensure we return at least an empty array if the cache entry doesn't exist
  if ($resource) {
    return $self->data->{$resource} // [];
  } else {
    return $self->data;
  }
}


sub removeCache ($self) {
  # Clear the cache in Redis
  my $redis_key = 'fortnox:cache';
  $self->cache->del($redis_key);

  my $empty = {
    'state'   => '',
    'access'  => '',
    'refresh' => '',
    'code'    => '',
  };
  # Reset the in-memory copy too. The model is a per-process singleton whose
  # `data` is loaded from Redis only once, so without this the worker keeps
  # using the old tokens and writes them straight back to Redis on the next
  # saveCache, undoing the logout.
  $self->data($empty);
  $self->_saveCache($empty);
}


sub getLogin($self, $oauth_state = 'login') {
  # $oauth_state is the OAuth state parameter Fortnox echoes back to our
  # redirect_uri. The internal cache state machine ('login'/'code'/'api') is
  # tracked separately in $self->data->{state}.
  $self->data->{state} = 'login';
  my $response = $self->ua->get($self->config->{oauth2}->{authorize_url} => {Accept => '*/*'} => form => {
    client_id     => $self->config->{oauth2}->{client_id},
    redirect_uri  => $self->config->{oauth2}->{redirect_uri},
    scope         => $self->config->{oauth2}->{scope},
    access_type   => $self->config->{oauth2}->{access_type},
    account_type  => $self->config->{oauth2}->{account_type},
    state         => $oauth_state,
  })->result;
  my $redirect_path;
  if ($response->headers->header('Location')) {
    $redirect_path = $response->headers->header('Location');
  } elsif ($response->body =~ /http-equiv="REFRESH"[^>]+url=([^">\s]+)/i) {
    $redirect_path = $1;
  }
  if ($redirect_path) {
    $self->data->{state} = 'code';
    $self->saveCache;
    return sprintf("https://apps.fortnox.se%s", $redirect_path);
  }
  return 0;
}


sub getToken ($self, $refresh = 0) {
  my $url = Mojo::URL->new($self->config->{oauth2}->{token_url})->userinfo(sprintf('%s:%s',
    $self->config->{oauth2}->{client_id},
    $self->config->{oauth2}->{secret}
  ));
  my $response;
  if ($refresh) {
    say "Refreshing Fortnox access token";
    $response = $self->ua->post($url => { Accept => '*/*' } => form => {
      grant_type    => 'refresh_token',
      refresh_token => $self->data->{refresh},
    })->result;
  } else {
    $response = $self->ua->post($url => { Accept => '*/*' } => form => {
      grant_type   => 'authorization_code',
      code         => $self->data->{code},
      redirect_uri => $self->config->{oauth2}->{redirect_uri},
    })->result;
  }

  # Check HTTP status first
  if (!$response->is_success) {
    say "Token HTTP error: " . $response->code . " " . $response->message;
    say "Response body: " . $response->body;
    return 0;
  }

  if ($response->json('/error')) {
    say "Token error: " . Dumper($response->json);
    return 0;
  } else {
    $self->data->{code} = '';
    $self->data->{refresh} = $response->json('/refresh_token');
    $self->data->{access} = $response->json('/access_token');
    $self->data->{state} = 'api';
    $self->saveCache;
    say "Token refreshed successfully";
    return 1;
  }
}


sub callAPI ($self, $resource, $method, $id = 0, $options = {}, $action = '') {
  # Sync with the shared Redis cache before checking the token, so a logout in
  # another worker is honoured here. Safe: nothing has mutated data yet, and all
  # writes are write-through via saveCache.
  $self->reload;
  if (!$self->data->{access}) {
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
  my $refresh_attempted = 0;  # Prevent infinite refresh loops

  if (!$id) {
    $qp = $options->{qp} if (exists($options->{qp}));
  }
  while (!$done) {
    $qp = $self->merger->merge($self->resources->{$resource}->{qp}, $qp) if (exists($self->resources->{$resource}) && exists($self->resources->{$resource}->{qp}));
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
    $tx->req->headers->add(Authorization => sprintf('Bearer %s', $self->data->{access}));
    $tx = $self->ua->start($tx);
    #        say $tx->req->to_string;

    if (403 == $tx->result->code) {
      say sprintf('%s %s', $tx->result->code, Dumper $tx->result->body);
      # Try to refresh token if we have a refresh token (only once)
      if ($self->data->{refresh} && !$refresh_attempted) {
        $refresh_attempted = 1;
        say "Attempting token refresh...";
        $self->data->{access} = '';
        if ($self->getToken(1)) {
          say "Token refreshed successfully, retrying request...";
          next;  # Retry the request with new token
        }
      }
      # Refresh failed or no refresh token - clear everything
      say "Token refresh failed, clearing session";
      $self->data->{access} = '';
      $self->data->{state} = '';
      $self->data->{refresh} = '';
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
    } elsif (429 == $tx->result->code) {
      # Rate limited - wait and retry
      say "Rate limited (429), waiting 10 seconds...";
      sleep 10;
      next;  # Retry the request
    } elsif ($tx->result->code =~ /^4/) {
      #          say sprintf('%s %s', $tx->result->code, Dumper $tx->result->body);

      #          if (2000311 == $result->{'ErrorInformation'}->{Code}) {}
      say sprintf('%s %s', $tx->result->code, Dumper $tx->result->body);
      $self->data->{access} = '';
      $self->data->{state} = 'code';
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
  # Check if file exists
  unless (-f $file) {
    return { error => 1, message => "File not found: $file" };
  }

  my $url = sprintf("%s%s?folderid=%s", $self->config->{apiurl}, 'inbox', $folderid);
  my $headers = {
    'Content-Type'  => 'multipart/form-data',
    'Authorization' => sprintf('Bearer %s', $self->data->{access})
  };

  while (1) {
    my $tx = $self->ua->build_tx('POST' => $url => $headers => form => {
      file => { file => $file }
    });
    $tx = $self->ua->start($tx);

    my $code = $tx->result->code;
    if ($code == 201) {
      return decode_json($tx->result->body);
    }

    # Rate limited - wait and retry
    if ($code == 429) {
      say "Rate limited (429), waiting 10 seconds...";
      sleep 10;
      next;
    }

    # Return error for other non-201 responses
    my $body = $tx->result->body // '';
    if ($body && $body =~ /^\{/) {
      my $json = eval { decode_json($body) };
      if ($json && $json->{ErrorInformation}) {
        return { error => 1, message => $json->{ErrorInformation}{message} // "HTTP $code" };
      }
    }
    return { error => 1, message => "HTTP $code: $body" };
  }
}


sub attachment ($self, $method, $fileid, $entityid, $entitype = 'F') {
  my $url = $self->config->{attachmentsurl};
  my $tx;

  $method = lc($method);

  if ($method eq 'get') {
    $tx = $self->ua->build_tx('GET' => $url => {Accept => '*/*'} => form => {
      entityid      => $entityid,
      entitytype    => $entitype,
    });
  } elsif ($method eq 'delete') {
    # DELETE uses URL path with file ID
    my $delete_url = "$url/$fileid";
    $tx = $self->ua->build_tx('DELETE' => $delete_url => {Accept => '*/*'});
  } else {
    # POST to create attachment
    $tx = $self->ua->build_tx(uc($method) => $url => {Accept => '*/*'} => json => [{
      fileId        => "$fileid",
      entityId      => "$entityid",
      entityType    => $entitype,
      includeOnSend => \1,
    }]);
    $tx->req->headers->content_type('application/json');
  }
  $tx->req->headers->add(Authorization => sprintf('Bearer %s', $self->data->{access}));
  say "Attachment request: $url fileId=$fileid entityId=$entityid entityType=$entitype";
  $tx = $self->ua->start($tx);
  say "Attachment response: " . $tx->result->code . " " . ($tx->result->body // '');

  my $code = $tx->result->code;
  if ($code == 200 || $code == 201 || $code == 204) {
    my $body = $tx->result->body // '';
    return {} if $code == 204 || !$body;  # DELETE returns 204 No Content
    return decode_json($body);
  }

  # Return error for non-success responses
  my $body = $tx->result->body // '';
  if ($body && $body =~ /^\{/) {
    my $json = eval { decode_json($body) };
    if ($json && $json->{ErrorInformation}) {
      return { error => 1, message => $json->{ErrorInformation}{message} // "HTTP $code" };
    }
  }
  return { error => 1, message => "HTTP $code: $body" };
}


sub financialYears ($self) {
  $self->updateCache('FinancialYears') if (!exists($self->data->{FinancialYears}));
  return Mojo::Collection->new(@{ $self->data->{FinancialYears} });
}


sub accounts ($self) {
  $self->updateCache('Accounts') if (!exists($self->data->{Accounts}));
  return Mojo::Collection->new(@{ $self->data->{Accounts} });
}


# Determine Fortnox VAT type for a customer
# Returns: 0=SEVAT, 1=SEREVERSEDVAT, 2=EUVAT, 3=EUREVERSEDVAT, 4=EXPORT
# Reference: https://www.momsens.se/vilka-omraden-ingar-i-eus-momsomrade
sub vatType ($self, $customer) {
  my $country = uc($customer->{billingcountry} // $customer->{country} // '');
  my $has_vatno = ($customer->{vatno} && $customer->{vatno} ne '');

  # EU VAT area member states (excluding Sweden)
  # Includes: MC (Monaco - uses French VAT system)
  # Excludes territories with own ISO codes outside EU VAT area:
  #   AX (Åland), GF (French Guiana), GP (Guadeloupe), MQ (Martinique),
  #   RE (Réunion), YT (Mayotte), IC (Canary Islands), EA (Ceuta/Melilla)
  my %eu_vat_countries = map { $_ => 1 } qw(
    AT BE BG CY CZ DE DK EE ES FI FR GR HR HU IE IT LT LU LV MC MT NL PL PT RO SI SK
  );

  # Territories outside EU VAT area (with own ISO codes) - treated as EXPORT
  my %non_vat_territories = map { $_ => 1 } qw(
    AX GF GP MQ RE YT IC EA
  );

  if ($country eq 'SE') {
    # Swedish customers - always SEVAT (normal VAT)
    # SEREVERSEDVAT is only for construction industry reverse charge (set manually)
    return 0;  # SEVAT
  } elsif ($non_vat_territories{$country}) {
    # EU territory but outside VAT area - treat as export
    return 4;  # EXPORT
  } elsif ($eu_vat_countries{$country}) {
    # EU VAT area customers - reverse charge if they have VAT number
    return $has_vatno ? 3 : 2;  # EUREVERSEDVAT or EUVAT
  } else {
    # Non-EU customers
    return 4;  # EXPORT
  }
}


# Get VAT type name from code
sub vatTypeName ($self, $code) {
  my @types = qw(SEVAT SEREVERSEDVAT EUVAT EUREVERSEDVAT EXPORT);
  return $types[$code] // 'SEVAT';
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
  say "Fortnox::creditInvoice called with DocumentNumber=$DocumentNumber";
  if ($DocumentNumber) {
    my $result = $self->callAPI('Invoices', 'put', $DocumentNumber, {}, 'credit');
    if (ref($result) eq 'HASH') {
      if ($result->{Invoice}) {
        # The credit endpoint returns the ORIGINAL invoice (now credited)
        # CreditInvoiceReference in the response points to the NEW credit invoice
        my $credit_num = $result->{Invoice}->{CreditInvoiceReference};
        say "Fortnox::creditInvoice: Original $DocumentNumber credited, credit invoice is $credit_num";
        $result->{CreditInvoiceNumber} = $credit_num;
        $result->{OriginalInvoiceNumber} = $DocumentNumber;
      } else {
        say "Fortnox::creditInvoice error: " . ($result->{ErrorInformation}->{message} // $result->{error} // 'unknown');
      }
    }
    return $result;
  }
  say "Fortnox::creditInvoice called without DocumentNumber";
  return;
}


sub getInvoice ($self, $DocumentNumber = 0, $options = {'qp' => {'limit' => 500, page => 1}}) {
  my $result = $self->callAPI('Invoices', 'get', $DocumentNumber, $options);
  return $result;
}


# Navigate to prev/next invoice using cached invoice list
sub navInvoice ($self, $to = 'next', $DocumentNumber = 0) {
  return 0 unless $DocumentNumber;

  my $cache_key = 'fortnox:invoice_list';
  my $list = $self->cache->get($cache_key);

  # Refresh cache if empty or stale (fetch all invoice numbers)
  if (!$list || !@$list) {
    $list = [];
    my $page = 1;
    my $fetch;
    do {
      $fetch = $self->callAPI('Invoices', 'get', 0, {qp => {
        page => $page,
        limit => 500,
        sortby => 'documentnumber',
        sortorder => 'descending'
      }});
      if ($fetch && $fetch->{Invoices}) {
        push @$list, map { $_->{DocumentNumber} } @{$fetch->{Invoices}};
      }
      $page++;
    } until (!$fetch || !$fetch->{MetaInformation} ||
             $fetch->{MetaInformation}->{'@CurrentPage'} >= $fetch->{MetaInformation}->{'@TotalPages'});

    $self->cache->set($cache_key => $list, 3600);  # Cache for 1 hour
  }

  # Find current position and navigate
  my $idx;
  for my $i (0 .. $#$list) {
    if ($list->[$i] == $DocumentNumber) {
      $idx = $i;
      last;
    }
  }

  return 0 unless defined $idx;

  # List is descending, so 'next' goes to lower index (newer), 'prev' goes to higher index (older)
  if ($to eq 'next' && $idx > 0) {
    return $list->[$idx - 1];
  } elsif ($to eq 'prev' && $idx < $#$list) {
    return $list->[$idx + 1];
  }

  return 0;
}


sub putInvoice ($self, $DocumentNumber = 0) {
  return 0 if (!$DocumentNumber);
  my $result = $self->callAPI('Invoices', 'put', $DocumentNumber);
}


sub getInvoicePayment ($self, $Number = 0, $options = {}) {
  # For single payment, always fetch from API
  if ($Number) {
    return $self->callAPI('InvoicePayments', 'get', $Number, $options);
  }

  # Require valid token - trigger auth flow if missing (reload first so a logout
  # in another worker is honoured)
  $self->reload;
  if (!$self->data->{access}) {
    return $self->getLogin();
  }

  # For list, use cache - check for errors
  if (!exists($self->data->{InvoicePayments})) {
    my $result = $self->updateCache('InvoicePayments');
    # Propagate error if update failed
    return $result if ref($result) eq 'HASH' && $result->{error};
  }
  return { InvoicePayments => $self->data->{InvoicePayments} // [] };
}


# Get customer names for invoice numbers, using cache
sub getInvoiceCustomerNames ($self, $invoice_numbers = []) {
  return {} unless @$invoice_numbers;

  my $cache_key = 'fortnox:invoice_customers';
  my $cached = $self->cache->get($cache_key) // {};
  my %result;
  my @missing;

  # Check cache first
  for my $num (@$invoice_numbers) {
    if (exists $cached->{$num}) {
      $result{$num} = $cached->{$num};
    } else {
      push @missing, $num;
    }
  }

  # Fetch missing from API
  for my $num (@missing) {
    my $invoice = $self->callAPI('Invoices', 'get', $num);
    if ($invoice && $invoice->{Invoice}) {
      my $customer_name = $invoice->{Invoice}->{CustomerName} // '';
      $result{$num} = $customer_name;
      $cached->{$num} = $customer_name;
    }
  }

  # Save updated cache
  if (@missing) {
    $self->cache->set($cache_key => $cached);
  }

  return \%result;
}


sub getCustomer ($self, $CustomerNumber = 0, $options = {'qp' => {'limit' => 500, page => 1}}) {
  my $result = $self->callAPI('Customers', 'get', $CustomerNumber, $options);
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


sub navCustomer ($self, $to = 'next', $CustomerNumber = '') {
  return '' unless $CustomerNumber;

  # Get cached customers or fetch if empty
  my $list = $self->data->{Customers} // [];
  $list = $self->updateCache('Customers') unless @$list;

  # Find current position
  my $idx;
  for my $i (0 .. $#$list) {
    if ($list->[$i]->{CustomerNumber} eq $CustomerNumber) {
      $idx = $i;
      last;
    }
  }

  return '' unless defined $idx;

  # Navigate (list is sorted by CustomerNumber ascending)
  if ($to eq 'next' && $idx < $#$list) {
    return $list->[$idx + 1]->{CustomerNumber};
  } elsif ($to eq 'prev' && $idx > 0) {
    return $list->[$idx - 1]->{CustomerNumber};
  }

  return '';
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
  # Hardcoded articles data (TODO: implement API/cache later)
  my $articles = [
    { ArticleNumber => '3010', Description => 'Domäner' },
    { ArticleNumber => '3011', Description => 'Snapback' },
    { ArticleNumber => '3012', Description => 'Webhosting' },
    { ArticleNumber => '3013', Description => 'Konsultarbete' },
    { ArticleNumber => '3540', Description => 'Fakturaavgifter' },
  ];
  if ($ArticleNumber) {
    # Find specific article
    my ($article) = grep { $_->{ArticleNumber} eq $ArticleNumber } @$articles;
    return { Article => $article } if $article;
    return {};
  }

  return { Articles => $articles };

  # OLD CODE - keep for reference until API/cache is implemented
  # if ($ArticleNumber) {
  #   return $self->callAPI('Articles', 'get', $ArticleNumber, $options);
  # } else {
  #   return { Articles => $self->updateCache('Articles') } if (!exists($self->data->{Articles}));
  # }
  # Example API response:
  # {
  #   "Articles": [
  #     { "@url": "https://api.fortnox.se/3/articles/3010", "ArticleNumber": "3010", "Description": "Domäner, svensk moms", "VAT": "25" },
  #     { "@url": "https://api.fortnox.se/3/articles/3011", "ArticleNumber": "3011", "Description": "Snapback, svensk moms", "VAT": "25" },
  #     ...
  #   ]
  # }
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