package Samizdat::Plugin::Cache;

use strict;
use warnings FATAL => 'all';

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::File qw(path);

sub register ($self, $app, $conf) {

  $app->helper(
    cache => sub($c) {
      my $config = $c->config;
      state $cache = Cache($config->{statefile});
      return $cache;
    }
  );

  $app->helper(
    saveCache => sub($c) {
      my $config = $c->config;
      return Cache($config->{statefile}, $c->cache);
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
  return {};
}

1;