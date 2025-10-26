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
  state $ua = Mojo::UserAgent->new->max_redirects(0)->connect_timeout(3)->request_timeout(2);
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
      'cache' => 0,
      'single' => {
        'name' => 'InvoicePayment'
      },
      'required' => ['InvoiceNumber']
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

sub updateCache ($self, $resource = undef) {
  my $resources = [];
  if ($resource) {
    push @{ $resources }, $resource;
  } else {
    push @{ $resources }, sort {$a cmp $b} keys %{ $self->config->{app}->{resources} };
  }
  for my $resource (@{ $resources }) {
    my $resourceconfig = $self->config->{app}->{resources}->{$resource};
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

  # Reset to empty cache
  $self->Cache({
    'state'   => '',
    'access'  => '',
    'refresh' => '',
    'code'    => ''
  });
}

sub getLogin($self) {
  $self->data->{state} = 'login';
  my $response = $self->ua->get($self->config->{oauth2}->{url} . '/auth' => {Accept => '*/*'} => form => {
    client_id     => $self->config->{app}->{clientid},
    scope         => $self->config->{app}->{scope},
    access_type   => $self->config->{oauth2}->{access_type},
    account_type  => $self->config->{oauth2}->{account_type},
    state         => $self->data->{state},
    response_type => 'code',
  })->result;
  if ($response->headers->header('Location')) {
    $self->data->{state} = 'code';
    $self->saveCache;
    #        return sprintf($response->headers->header('Location'));
    my $redirect = sprintf("https://apps.fortnox.se%s\n", $response->headers->header('Location'));
    return $redirect;
  }
  return 0;
}

sub getToken ($self, $refresh = 0) {
  my $url = Mojo::URL->new($self->config->{oauth2}->{url} . '/token')->userinfo(sprintf('%s:%s',
    $self->config->{app}->{clientid},
    $self->config->{app}->{secret}
  ));
  my $response;
  if ($refresh) {
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
#  $response->save_to($self->config->{cachefile});
  if ($response->json('/error')) {
    return 0;
  } else {
    $self->data->{code} = '';
    $self->data->{refresh} = $response->json('/refresh_token');
    $self->data->{access} = $response->json('/access_token');
    $self->data->{state} = 'api';
    $self->saveCache;
    return 1;
  }
}


sub callAPI ($self, $resource, $method, $id = 0, $options = {}, $action = '') {
  if (!exists($self->data->{access})) {
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
    $qp = $self->merger->merge($self->config->{app}->{resources}->{$resource}->{qp}, $qp);
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
  my $url = sprintf("%s%s?folderid=%s", $self->config->{apiurl}, 'inbox', $folderid);
  my $headers = {
    'Content-Type'  => 'multipart/form-data',
    'Authorization' => sprintf('Bearer %s', $self->data->{access})
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
  $tx->req->headers->add(Authorization => sprintf('Bearer %s', $self->data->{access}));
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
  $self->updateCache('FinancialYears') if (!exists($self->data->{FinancialYears}));
  return Mojo::Collection->new(@{ $self->data->{FinancialYears} });
}

sub accounts ($self) {
  $self->updateCache('Accounts') if (!exists($self->data->{Accounts}));
  return Mojo::Collection->new(@{ $self->data->{Accounts} });
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