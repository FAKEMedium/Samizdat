package Samizdat::Plugin::Utils;

use strict;
use warnings;
no warnings 'uninitialized';

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::Home;
use IO::Compress::Gzip;
use Imager;
use Data::Dumper;

my $public = Mojo::Home->new('public/');
my $image = Imager->new;
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

  # Remove indentation from pre and textarea elements
  # Add the generated html to public as a static cache
  # Also adds missing webP files
  $app->hook(
    after_render => sub ($c, $output, $format) {
      return 1 if (exists($cacheexist->{$c->{stash}->{web}->{docpath}}));
      if (404 != $c->{stash}->{status}) {
        $$output =~ s{<pre>(.+?)</pre>}[
          my $text = $1;
          $text =~ s/^[ ]+//gms;
          sprintf('<pre>%s</pre>', $text);
        ]gexsmu;
        $public->child($c->{stash}->{web}->{docpath})->spurt($$output);
        my $z = new IO::Compress::Gzip sprintf('%s.gz',
          $public->child($c->{stash}->{web}->{docpath})->to_string),
          -Level => 9, Minimal => 1, AutoClose => 1;
        $z->print($$output);
        $z->close;
        undef $z;
        $cacheexist->{$c->{stash}->{web}->{docpath}} = 1;
      } elsif ($c->{stash}->{web}->{url} =~ /\.webp$/) {
        my $webpfile = $public->child($c->{stash}->{web}->{url});
        my $probefile = $webpfile;
        $probefile =~ s/\.webp$//;
        my $ext = '';
        $webpfile->dirname->list->each( sub ($file, $num) {
          if ($file =~ /$probefile\.(.+)$/) {
            $ext = $1;
          }
        });
        if ('' ne $ext) {
          $image->read(file => sprintf("%s.%s",  $probefile, $ext)) or die $image->errstr;
          my $width = $image->getwidth();
          if ($width > 1078) {
            $width = 1078;
            $image = $image->scale(xpixels => $width);
          }
          $image->write(
            data                 => $output,
            type                 => 'webp',
            webp_method          => 6,
            webp_sns_strength    => 80,
            webp_pass            => 10,
            webp_quality         => 75,
            webp_alpha_filtering => 2,
          ) or die $image->errstr;
          $c->stash('status', 200);
          $format = 'image/webp';
          $c->tx->res->headers->content_type($format);
          $webpfile->spurt($$output);
        }
      }
      return 1;
    }
  );
}

1;