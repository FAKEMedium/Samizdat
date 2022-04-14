package Samizdat::Plugin::Utils;

use strict;
use warnings;
no warnings 'uninitialized';

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Data::Dumper;

sub register  {
  my ($self, $app) = @_;

  $app->helper(
    indent => sub ($c, $content, $indents) {
      my $indent = "  " x $indents;
      $content =~ s/\n/\n$indent/gsm;
      $content =~s/$indent$//sm;
      chomp $content;
      return sprintf("%s%s\n", $indent, $content);
    },
  );

  $app->helper(
    limiter => sub ($c) {
      return sprintf("<!-- ### ABCDEFGHIJKLMNOPQRSTUVWXYZÅÄÖabcdefghijklmnopqrstuvwxyzåäö0123456789!\"'|\$\\#¤%%&/(){}[]=? ### -->");
    },
  );

  $app->hook(
    after_render => sub ($c, $output, $format) {
      if ('html' eq $format && 'get' eq lc $c->req->method) {
        say Dumper $c->{stash};
#        $c->{stash}->{'mojo.captures'}->{docpath};
      }
      return 1;
    }
  );
}


1;