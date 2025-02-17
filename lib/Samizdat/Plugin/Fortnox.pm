package Samizdat::Plugin::Fortnox;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Fortnox;
use Mojo::UserAgent;
use Mojo::File qw(path);
use Mojo::JSON qw(decode_json encode_json from_json);
use Mojo::Collection qw(c);
use Data::Dumper;

sub register ($self, $app, $conf) {
  my $r = $app->routes;
  my $manager = $r->under($app->config->{managerurl})->to(
    controller => 'Account',
    action     => 'authorize',
    require    => {
      users => $app->config->{account}->{admins}
    }
  );

  $manager->any(sprintf('%s', 'fortnox/auth'))->to('Fortnox#auth');
  $manager->any(sprintf('%s', 'fortnox/customers'))->to('Fortnox#customer');
  $manager->any(sprintf('%s', 'fortnox/customers/:customerid'))->to('Fortnox#customer');
  $manager->any(sprintf('%s', 'fortnox/work'))->to('Fortnox#work');
  $manager->any(sprintf('%s', 'fortnox/test'))->to('Fortnox#test');
  $manager->post(sprintf('%s', 'fortnox/invoices'))->to('Fortnox#postinvoice');
  $manager->get(sprintf('%s', 'fortnox/invoices'))->to('Fortnox#listinvoices');
  $manager->any(sprintf('%s', 'fortnox/logout'))->to('Fortnox#logout');
  $manager->any(sprintf('%s', 'fortnox'))->to('Fortnox#index');

  $app->helper(fortnox => sub { state $fortnox = Samizdat::Model::Fortnox->new({app => shift}) });
  $app->helper(
    getLogin => sub($c, $application) {
      my $config = $c->config;
      my $ua = Mojo::UserAgent->new;
      $ua->max_redirects(0)->connect_timeout(3)->request_timeout(2);
      $c->cache->{$application} = { state => 'login' };
      my $response = $ua->get($config->{oauthurl} . '/auth' => {Accept => '*/*'} => form => {
        client_id     => $config->{apps}->{$application}->{clientid},
        response_type => 'code',
        access_type   => 'offline',
        scope         => 'bookkeeping connectfile customer supplier supplierinvoice archive payment settings invoice currency article',
#        scope         => 'connectfile archive invoice article',
        account_type  => 'service',
        state         => $c->cache->{$application}->{state},
      })->result;
      if ($response->headers->header('Location')) {
        $c->cache->{$application}->{state} = 'code';
        $c->saveCache;
#        return sprintf($response->headers->header('Location'));
        return sprintf("https://apps.fortnox.se%s\n", $response->headers->header('Location'));
      }
    }
  );

  $app->helper(
    getToken => sub($c, $application, $refresh) {
      my $config = $c->config;
      my $ua = Mojo::UserAgent->new;
      my $url = Mojo::URL->new($app->config->{oauthurl} . '/token')->userinfo(sprintf('%s:%s',
        $config->{apps}->{$application}->{clientid},
        $config->{apps}->{$application}->{secret}
      ));
      my $response;
      if ($refresh != 0) {
        $response = $ua->post($url => { Accept => '*/*' } => form => {
          grant_type    => 'refresh_token',
          refresh_token => $c->cache->{$application}->{refresh},
        })->result;
      } else {
        $response = $ua->post($url => { Accept => '*/*' } => form => {
          grant_type   => 'authorization_code',
          code         => $c->cache->{$application}->{code},
          redirect_uri => $config->{apps}->{$application}->{redirect},
        })->result;
      }
      $response->save_to($app->config->{statefile});
      if ($response->json('/error')) {
        return 0;
      } else {
        $c->cache->{$application}->{code} = '';
        $c->cache->{$application}->{refresh} = $response->json('/refresh_token');
        $c->cache->{$application}->{access} = $response->json('/access_token');
        $c->cache->{$application}->{state} = 'api';
        $c->saveCache;
        return 1;
      }
    }
  );

  $app->helper(
    financialYears => sub($c) {
      $c->updateCache() if (!exists($c->cache->{bok}->{financialyears}));
      return Mojo::Collection->new(@{ $c->cache->{bok}->{financialyears} });
    }
  );

  $app->helper(
    accounts => sub($c) {
      $c->updateCache() if (!exists($c->cache->{bok}->{accounts}));
      return Mojo::Collection->new(@{ $c->cache->{bok}->{accounts} });
    }
  );

  $app->helper(
    callAPI => sub($c, $application, $resource, $method, $id = 0, $options = {}, $action = '') {
      if (!exists($c->cache->{$application}->{access})) {
        return $c->getLogin($c->config->{apps}->{$application});
      }
      $resource = lc $resource;
      my $url = $c->config->{apiurl};
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
            $url = sprintf("%s%s/%d", $url, $resource, $id);
          } else {
            $url = sprintf("%s%s/%d/%s", $url, $resource, $id, $action);
          }
        } else {
          $url = sprintf("%s%s", $url, $resource);
        }
      }
      my $done = 0;
      my $qp = {};

      state $ua = Mojo::UserAgent->new;
      $ua->max_redirects(0)->connect_timeout(3)->request_timeout(2);

      while (!$done) {
        if (!$id) {
          $qp = {
            limit     => $c->param('limit'),
            offset    => $c->param('offset'),
            sortby    => $c->param('sortby'),
            sortorder => $c->param('sortorder'),
            page      => $c->param('page'),
            filter    => $c->param('filter'),
          };
        }
        $qp = $c->merger->merge($c->config->{apps}->{$application}->{resources}->{$resource}->{qp}, $qp);
        $qp = $c->merger->merge($options->{qp}, $qp);
        for my $p (qw/sortby sortorder filter limit offset page/) {
#          delete $qp->{$p} if (exists($qp->{$p}) and ($qp->{$p} eq ''));
        }
#        say $resource . Dumper $qp;
        my $tx;
#        say $url;
        if ('get' eq $method) {
          $tx = $ua->build_tx('GET' => lc($url) => {Accept => '*/*'} => form => $qp);
        } else {
          $tx = $ua->build_tx(uc($method) => lc($url) => {Accept => '*/*'} => json => $options);
          $tx->req->headers->content_type('application/json');
        }
        $tx->req->headers->add(Authorization => sprintf('Bearer %s', $c->cache->{$application}->{access}));
        $tx = $ua->start($tx);
#        say $tx->req->to_string;

        if (403 == $tx->result->code) {
          say sprintf('%s %s', $tx->result->code, Dumper $tx->result->body);
          return $c->getLogin($c->config->{apps}->{$application});
        } elsif (404 == $tx->result->code) {
          $done = 1;
          return 404;
        } elsif (400 == $tx->result->code) {
          say sprintf('%s %s', $tx->result->code, Dumper $tx->result->body);
          $done = 1;
          return 400;
        } elsif ($tx->result->code =~ /^4/) {

          #          if (2000311 == $result->{'ErrorInformation'}->{Code}) {}

          $c->cache->{$application}->{access} = '';
          $c->cache->{$application}->{state} = 'code';
          $c->saveCache;
          $c->getToken($application, 1);
        } elsif (200 == $tx->result->code) {
          my $result = decode_json($tx->result->body);
#          say Dumper $result;
          return $result;
        }
        sleep 2;
      }
    }
  );

  $app->helper(
    metaInfo => sub($c, $metainfo, $title = '') {
      $c->render_to_string('chunks/metainfo', metainfo => $metainfo, title => $title);
    }
  );

  $app->helper(
    updateCache => sub($c, $resource = '') {
      my @resources = '' eq $resource ? sort {$a cmp $b} keys %{ $c->config->{apps}->{bok}->{resources} } : qw($resource);
      for my $resource (@resources) {
        my $config = $c->config->{apps}->{bok}->{resources}->{$resource};
        if (exists($config->{cache}) && int $app->config->{cache}) {
          my $list = [];
          my $page = 1;
          my $fetch = {};
          my $object = exists($config->{object}) ? $app->config->{object} : $resource;
          do {
            $fetch = $c->callAPI('bok', $resource, 'get', 0, {qp => {page => $page}});
            push(@{ $list }, @{ $fetch->{$object} });
            $page++;
          } until (!exists($fetch->{'MetaInformation'}) or $fetch->{'MetaInformation'}->{'@CurrentPage'} >= $fetch->{'MetaInformation'}->{'@TotalPages'});
          my $what = lc $resource;
          $c->cache->{bok}->{$what} = $list;
          $c->saveCache;

        }
      }
      $c->saveCache;
      return $c->cache;
    }
  );

  $app->helper(
    cache => sub($c) {
      my $config = $c->config;
      state $cache = Cache($config->{statefile});
    }
  );

  $app->helper(
    saveCache => sub($c) {
      my $config = $c->config;
      return Cache($config->{statefile}, $c->cache);
    }
  );

  $app->helper(
    removeCache => sub($c) {
      my $config = $c->config;
      unlink $config->{statefile} if (-e $config->{statefile});
      state $cache = undef;
    }
  );


}

sub Cache ($statefile, $cache = undef) {
  if ($cache) {
    return path($statefile)->spew(encode_json($cache));
  } elsif (-f $statefile) {
    my $json = path($statefile)->slurp;
    if ($json) {
      return decode_json($json);
    }
  }
  return {
    'bok' => {
      'state'   => 'login',
      'access'  => '',
      'refresh' => '',
      'code'    => ''
    }
  };
}

1;

