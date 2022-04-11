package Samizdat::Plugin::Utils;

use strict;
use warnings FATAL => 'all';

use Mojo::Base 'Mojolicious::Plugin', -signatures;

sub register {
  my $self = shift;
  my $app = shift;


  $app->helper(
    indent => sub {
      my ($c, $content, $indents) = @_;
      my $indent = "\t" x $indents;
      $content =~ s/\n/\n$indent/gsm;
      $content = $indent . $content;
      chomp $content;
      return $content;
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