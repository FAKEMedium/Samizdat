package Samizdat::Plugin::Utils;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::Home;
use Mojo::Template;
use Mojo::Util qw(decode);
use IO::Compress::Gzip;
use Imager;
use Data::Dumper;

my $public = Mojo::Home->new('public/');
my $srcpublic = Mojo::Home->new('src/public/');
my $templates = Mojo::Home->new('templates/');
my $mt = Mojo::Template->new();
my $image = Imager->new;

my $cacheexist = {};

sub register ($self, $app, $conf) {

  $app->helper(
    accept_language => sub ($c) {
      my $language = $c->req->headers->accept_language;
    }
  );

  $app->helper(
    indent => sub ($c, $content = '', $indents = 0) {
      no warnings 'uninitialized';
      my $indent = "  " x $indents;
      $content =~ s/\n/\n$indent/gsm;
      $content =~s/$indent$//sm;
      chomp $content;
      return sprintf("%s%s\n", $indent, $content);
    }
  );

  # A marker to show where the generated main content is. Also a little encoding test.
  $app->helper(
    limiter => sub ($c) {
      return sprintf("<!-- ### ABCDEFGHIJKLMNOPQRSTUVWXYZÅÄÖabcdefghijklmnopqrstuvwxyzåäö0123456789!\"'|\$\\#¤%%&/(){}[]=? ### -->");
    }
  );

  # Inline logotype (svg)
  $app->helper(
    languageselector => sub ($c) {
      my $out = '';

    }
  );

  $app->helper(
    includeany => sub ($c, $file = undef, $type = 'javascript', $insert = 0) {
      my $content = $templates->rel_file($file)->slurp if ($file and -e $templates->rel_file($file)->to_string) // '';
      $content = decode 'UTF-8', $content;
      if ($insert) {
        my $web = $c->stash('web');
        if ('javascript' eq $type) {
          $web->{script} .= $content;
        } elsif ('css' eq $type) {
          $web->{css} .= $content;
        }
        $content = '';
      } else {
        if ('javascript' eq $type) {
          $content = sprintf("<script>\n%s</script>", $c->app->indent($content, 1));
        } elsif ('css' eq $type) {
          $content = sprintf("<style>\n\t%s</style>", $c->app->indent($content, 1));
        }
      }
      return $content;
    }
  );

  # Remove indentation from pre and textarea elements
  # Add the generated html to public as a static cache
  # Also adds missing webP files
  $app->hook(
    after_render => sub ($c, $output, $format) {
      no warnings 'uninitialized';
      $$output =~ s{        <!-- symbols -->\n}[
        $c->app->indent(join("\n", sort {$a cmp $b} map $app->{symbols}->{$_}, keys %{ $app->{symbols} }), 4)
      ]eu;
      return 1 if (exists($cacheexist->{$c->{stash}->{web}->{docpath}}));
      if (404 != $c->{stash}->{status}) {
        $$output =~ s{<pre([^>]*?)>(.*?)</pre>}[
          my $attribs = $1;
          my $text = $2;
          $text =~ s/^[ ]+//gms;
          sprintf('<pre%s>%s</pre>', $attribs, $text);
        ]gexsmu;

        # Especially for converted indented markdown
        $$output =~ s{<pre><code>(.*?)</code></pre>}[
          my $text = $1;
          $text =~ s/^[ ]+//gms;
          sprintf('<pre><code>%s</code></pre>', $text);
        ]gexsmu;

        $$output =~ s{(^[\s]*)<textarea([^>]*?)>(.*?)</textarea>}[
          my $indent = $1;
          my $attribs = $2;
          my $text = $3;
          $text =~ s/^[ ]+//gms;
          sprintf('%s<textarea%s>%s</textarea>', $indent, $attribs, $text);
        ]gexsmu;

        if ($c->config->{cache} && exists $c->{stash}->{web}->{docpath}) {
          $public->child($c->{stash}->{web}->{docpath})->dirname->make_path;
          $public->child($c->{stash}->{web}->{docpath})->spew($$output);
          my $z = new IO::Compress::Gzip sprintf('%s.gz',
            $public->child($c->{stash}->{web}->{docpath})->to_string),
            -Level => 9, Minimal => 1, AutoClose => 1;
          $z->print($$output);
          $z->close;
          undef $z;
          $cacheexist->{$c->{stash}->{web}->{docpath}} = 1;
        }
      } elsif ($c->config->{makewebp} && ($c->{stash}->{web}->{url} =~ /\.webp$/)) {
        my $srcfile = $srcpublic->child($c->{stash}->{web}->{url});
        my $probefile = $srcfile;
        $probefile =~ s/\.webp$//;
        my $ext = '';
        $srcfile->dirname->list->each( sub ($file, $num) {
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
          my $webpfile = $public->child($c->{stash}->{web}->{url});
          $webpfile->spew($$output);
        }
      }
      return 1;
    }
  );
}

1;