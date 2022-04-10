package Samizdat::Plugin::Cache;

use strict;
use warnings FATAL => 'all';

use Mojo::Base 'Mojolicious::Plugin', -signatures;

sub register {
  my $self = shift;
  my $app = shift;


  $app->helper(
    testhelper => sub {
      my $c = shift;
      return 1;
    },
  );

  $app->hook(
    after_render => sub {
      my ($c, $output, $format) = @_;
      if ('html' eq $format) {

      }
      if ('get' eq lc $c->req->method) {

      }
      return 1;
    }
  );
}


1;