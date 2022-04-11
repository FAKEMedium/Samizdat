package Samizdat::Plugin::Utils;

use strict;
use warnings FATAL => 'all';
no warnings 'uninitialized';

use Mojo::Base 'Mojolicious::Plugin', -signatures;

sub register {
  my $self = shift;
  my $app = shift;

  $app->helper(
    indent => sub ($c, $content, $indents) {
      my $indent = "\t" x $indents;
      $content =~ s/\n/\n$indent/gsm;
      $content =~s/$indent$//sm;
      chomp $content;
      return sprintf("%s%s\n", $indent, $content);
    },
  );

  $app->helper(
    limiter => sub {
      my ($c) = @_;
      return sprintf("<!-- ### ABCDEFGHIJKLMNOPQRSTUVWXYZÅÄÖabcdefghijklmnopqrstuvwxyzåäö0123456789!\"'|\$\\#¤%%&/(){}[]=? ### -->");
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