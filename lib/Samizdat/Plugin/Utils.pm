package Samizdat::Plugin::Utils;

use strict;
use warnings;
no warnings 'uninitialized';

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::Home;
use IO::Compress::Gzip;
use Data::Dumper;

my $public = Mojo::Home->new('public/');
my $cacheexist = {};

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
      if (
        404 != $c->{stash}->{status}
        and !exists($cacheexist->{$c->{stash}->{web}->{docpath}})
        and 'html' eq $format
        and 'get' eq lc $c->req->method
      ) {
        $public->child($c->{stash}->{web}->{docpath})->spurt($$output);
        my $z = new IO::Compress::Gzip sprintf('%s.gz',
          $public->child($c->{stash}->{web}->{docpath})->to_string),
          -Level => 9, Minimal => 1, AutoClose => 1;
        $z->print($$output);
        $z->close;
        $cacheexist->{$c->{stash}->{web}->{docpath}} = 1;
        undef $z;
      }
      return 1;
    }
  );
}


1;