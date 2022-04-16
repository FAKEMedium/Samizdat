package Samizdat::Plugin::Utils;

use strict;
use warnings;
no warnings 'uninitialized';

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::Home;
use Data::Dumper;

my $public = Mojo::Home->new('public/');


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

  # A marker to show where the generated main content is. Also a little encoding test.
  $app->helper(
    limiter => sub ($c) {
      return sprintf("<!-- ### ABCDEFGHIJKLMNOPQRSTUVWXYZÅÄÖabcdefghijklmnopqrstuvwxyzåäö0123456789!\"'|\$\\#¤%%&/(){}[]=? ### -->");
    },
  );

  # Add the generated html to public as a static cache
  $app->hook(
    after_render => sub ($c, $output, $format) {
      if ('html' eq $format && 'get' eq lc $c->req->method) {
        $public->child($c->{stash}->{web}->{docpath})->spurt($$output);
      }
      return 1;
    }
  );
}


1;