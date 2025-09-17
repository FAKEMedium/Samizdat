package Samizdat::Plugin::Web;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Web;
use Mojo::Home;
use Mojo::DOM;
use Mojo::Util qw(decode);
use IO::Compress::Gzip;
use Imager;
use Data::Dumper;

my $public = Mojo::Home->new('public/');
my $templates = Mojo::Home->new('templates/');
my $image = Imager->new;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  my $manager = $r->manager('web')->to(controller => 'Web');
  $manager->get('editor/toolbar')   ->to('#editor_toolbar')    ->name('web_editor_toolbar');
  $manager->get('editor')           ->to('#editor')            ->name('web_editor');
  $manager->get('menus')            ->to('#menus')             ->name('web_menus');
  $manager->get('languages')        ->to('#languages')         ->name('web_languages');
  $manager->get('images')           ->to('#images')            ->name('web_images');
  $manager->post('save')            ->to('#save')              ->name('web_save');
  $manager->get('/')                ->to('#index')             ->name('web_index');

  # Things coming from configuration file
  my $web  = $r->home->to(controller => 'Web');
  $web->get('manifest.json')               ->to('#manifest',  docpath => 'manifest.json');
  $web->get('robots.txt')                  ->to('#robots',    docpath => 'robots.txt');
  $web->get('humans.txt')                  ->to('#humans',    docpath => 'humans.txt');
  $web->get('ads.txt')                     ->to('#ads',       docpath => 'ads.txt');
  $web->get('.well-known/security.txt')    ->to('#security',  docpath => '.well-known/security.txt');

  # Things coming from database, or markdown files in src/public
  # Database overlays files. See Samizdat::Model::Web and Samizdat::Controller::Web
  $web->get('/')                           ->to('#getdoc',    docpath => '')->name('home');
  $web->get('/*docpath')                   ->to('#getdoc');


  # Helper for accessing the Web model.
  $app->helper(web => sub ($self) {
    state $web = Samizdat::Model::Web->new(
      config       => $self->config->{manager}->{web},
      database     => $self->app->pg,
      locale       => $self->config->{locale}
    );
    return $web;
  });


  # Content shown in the headline area, default is share buttons
  $app->helper(headline => sub ($self, $chunkname =  'chunks/sharebuttons') {
    return ($chunkname) ? $self->render_to_string(template => $chunkname) : '';
  });


  # Get the preferred language from the Accept-Language header
  $app->helper(
    accept_language => sub ($c) {
      my $language = $c->req->headers->accept_language;
      return $language unless defined $language;
    }
  );


  # A marker to show where the generated main content is. Also a little encoding test.
  $app->helper(
    limiter => sub ($c, $what =  'start') {
      return sprintf("<!-- ### %s ### ABCDEFGHIJKLMNOPQRSTUVWXYZÅÄÖabcdefghijklmnopqrstuvwxyzåäö0123456789!\"'|\$\\#¤%%&/(){}[]=? ### -->",
        ($what eq 'end') ? $c->app->__('End main content') :
          ($what eq 'endside') ? $c->app->__('End side content') :
            ($what eq 'startside') ? $c->app->__('Start side content') :
              $c->app->__('Start main content')
      );
    }
  );


  # Helper to check if a language is RTL
  $app->helper(
    is_rtl => sub ($c, $lang = undef) {
      $lang = $c->language unless defined $lang;
      return $lang =~ /^(ar|he|fa)$/ ? 1 : 0;
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
          $content = sprintf("<script>\n%s</script>", $c->app->web->indent($content, 1));
        } elsif ('css' eq $type) {
          $content = sprintf("<style>\n\t%s</style>", $c->app->web->indent($content, 1));
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
      my $symbols = $c->stash('symbols') // {};
      $$output =~ s{        <!-- symbols -->\n}[
        $c->app->web->indent(join("\n", sort {$a cmp $b} map $symbols->{$_}, keys %{ $symbols }), 4)
      ]eu;
      if ('html' eq $format && 404 != $c->{stash}->{status} && uc($c->req->method) eq 'GET') {
        my $docpath = $c->stash('docpath') // eval {
          my $docpath = $c->req->url->to_abs->path->to_string;
          if ($docpath =~ /\/$/) {
            $docpath .= 'index.html';
          } elsif ($docpath !~ /\.[a-zA-Z0-9]+$/) {
            $docpath .= '/index.html';
          }
          return $docpath;
        };
        my $language = $c->stash('language');
        if ($c->config->{locale}->{default_language} ne $language) {
          $docpath =~ s/\.html$/.$language.html/;
        }
        $c->app->web->tidyup($output);
        if ($c->config->{cache} && $docpath ne '') {
          $public->child($docpath)->dirname->make_path;
          $public->child($docpath)->spew($$output);
          my $z = new IO::Compress::Gzip sprintf('%s.gz',
            $public->child($docpath)->to_string),
            -Level => 9, Minimal => 1, AutoClose => 1;
          $z->print($$output);
          $z->close;
          undef $z;
        }
      }
      if ($c->config->{manager}->{web}->{imageconversion}->{format}->{webp} && ($c->{stash}->{web}->{url} =~ /\.webp$/)) {
        my $publicsrc = Mojo::Home->new($c->config->{manager}->{web}->{publicsrc} // 'src/public/');
        my $url = $c->{stash}->{web}->{url} // '';
        $url =~ s/\.webp$//;
        my $wantedsize = 0;
        if ($url =~ s/_(\d+)$//) {
          $wantedsize = $1;
        }
        my $srcfile = $publicsrc->child($url);

        my $ext = '';
        $srcfile->dirname->list->each( sub ($file, $num) {
          if ($file =~ /$url\.(jpg|jpeg|png|gif|tiff|webp|heif|bmp)$/) {
            $ext = $1;
          }
        });

        if ('' ne $ext) {
          $image->read(file => sprintf("%s.%s",  $srcfile, $ext)) or die $image->errstr;
          my $colwidth = my $width = $image->getwidth();
          my $imgdata = '';
          my $done = 0;
          for my $col (
            sort {$c->config->{manager}->{web}->{imageconversion}->{width}->{$a} <=> $c->config->{manager}->{web}->{imageconversion}->{width}->{$b}}
              keys %{ $c->config->{manager}->{web}->{imageconversion}->{width} }
          ) {
            $colwidth = $c->config->{manager}->{web}->{imageconversion}->{width}->{$col};
            my $converted = $image->scale(xpixels => $colwidth);
            $converted->write(
              data                 => \$imgdata,
              type                 => 'webp',
              webp_method          => 6,
              webp_sns_strength    => 80,
              webp_pass            => 10,
              webp_quality         => 75,
              webp_alpha_filtering => 2,
            ) or die $converted->errstr;

            my $webpfile = $public->child(sprintf('%s_%d.webp', $url, $colwidth));
            $webpfile->dirname->make_path({mode => 0750});
            $webpfile->spew($imgdata);
            if ($colwidth == $wantedsize) {
              $c->stash('status', 200);
              $c->tx->res->headers->content_type('image/webp');
              $$output = $imgdata;
              $done = 1;
            }
          }

          # PNG fallback with the maximum column width
          if ($width > $colwidth) {
            $image = $image->scale(xpixels => $colwidth);
          }

          $image->write(
              data                 => \$imgdata,
              type                 => 'png',
          ) or die $image->errstr;

          my $pngfile = $public->child(sprintf('%s.png', $url));
          $pngfile->dirname->make_path({mode => 0750});
          $pngfile->spew($imgdata);
          if (!$done) {
            $c->stash('status', 200);
            $c->tx->res->headers->content_type('image/png');
            $$output = $imgdata;
          }
        }
      }
      return 1;
    }
  );

}

1;

=encoding utf8

=head1 NAME

Samizdat::Plugin::Web - Mojolicious plugin for web-related functionality

=head1 DESCRIPTION

This plugin provides web-related functionality for the Samizdat application, including routes for manifest files,
robots.txt, humans.txt, ads.txt, security.txt, and a general document handler. The accompanying controller and model
handle the logic for rendering these documents and managing the web interface.

=head1 PARTS

=over

=item Samizdat::Plugin::Web

This is the main plugin module that registers the web routes and helpers.

=item Samizdat::Controller::Web

This controller handles the web-related actions, such as rendering the index page, serving static files, and managing
web documents.

=item Samizdat::Model::Web

This model provides the functionality to manage web documents, including fetching and rendering them based on the
requested path and language. Source markdown files are converted to HTML and returned in a data structure for assembly in the controller
and view.

=item Samizdat::Plugin::Utils

This module implements the after_render hook to inject some code, beautify HTML, and store optimized HTML files in the
static directory if the docpath stash is set.

=item samizdat.yml

Contains supported languages and the path to the source files.

=back


=head1 BUGS

Make controller/model/after render hook translate README.md to index.html and save it in the static cs, using a naming scheme containing
the language code, e.g. index.en.html, index.de.html, etc. The default language should be without a language code.

=head1 TODO

AI gave me a list of features to implement in the web plugin. Here is the list combined with my own ideas:

=over

=item Add database backend for web pages, so that they can be edited and managed through the admin interface.

=item Add caching for static files to improve performance.

=item Implement a more robust error handling mechanism for missing documents.

=item Add support for internationalization and localization of web pages.

=item Implement a search functionality for web pages.

=item Add support for custom themes and styles for web pages.

=item Implement a content management system (CMS) for easier management of web pages.

=item Add support for user-generated content and comments on web pages.

=item Implement a versioning system for web pages to track changes over time.

=item Add analytics and tracking for web page visits and user interactions.

=item Implement a sitemap generation feature for better SEO.

=item Add support for social media integration and sharing of web pages.

=item Implement a feedback mechanism for users to report issues or suggest improvements for web pages.

=item Add support for multimedia content (images, videos, etc.) on web pages.

=item Implement a responsive design for web pages to ensure compatibility with various devices.

=item Add support for accessibility features to ensure web pages are usable by all users.

=item Implement a backup and restore functionality for web pages to prevent data loss.

=item Add support for custom domains and subdomains for web pages.

=item Implement a security mechanism to protect web pages from unauthorized access and modifications.

=item Add support for user authentication and authorization for web page management.

=item Implement a logging mechanism to track changes and access to web pages.

=item Add support for webhooks to trigger actions based on web page events.

=item Implement a plugin system to allow third-party developers to extend web page functionality.

=item Add support for API endpoints to allow programmatic access to web page data.

=item Implement a content delivery network (CDN) integration for faster delivery of web page assets.

=item Add support for A/B testing and experimentation on web pages.

=item Implement a user-friendly interface for managing web pages, including drag-and-drop functionality.

=item Add support for custom metadata and SEO optimization for web pages.

=item Implement a notification system to alert users of changes or updates to web pages.

=item Add support for multilingual web pages to cater to a global audience.

=item Implement a content approval workflow for web pages to ensure quality and consistency.

=item Add support for custom URL structures and redirects for web pages.

=item Implement a feature to allow users to bookmark or favorite web pages for easy access.

=item Add support for custom CSS and JavaScript for web pages to allow for greater customization.

=item Implement a feature to allow users to subscribe to updates or changes on web pages.

=item Add support for content syndication and distribution for web pages.

=item Implement a feature to allow users to create and manage their own web pages within the application.

=item Add support for web page analytics and reporting to track user engagement and performance.

=item Implement a feature to allow users to export web pages as static HTML files.

=item Add support for web page archiving to preserve historical versions of web pages.

=item Implement a feature to allow users to import web pages from external sources.

=item Add support for web page collaboration, allowing multiple users to work on the same page simultaneously.

=item Implement a feature to allow users to create and manage web page templates for consistent design.

=item Add support for web page tagging and categorization for better organization.

=item Implement a feature to allow users to create and manage web page menus for easy navigation.

=item Add support for web page scheduling, allowing users to publish or unpublish pages at specific times.

=item Implement a feature to allow users to create and manage web page forms for user input.

=item Add support for web page comments and discussions to foster user engagement.

=item Implement a feature to allow users to create and manage web page galleries for images and media.

=item Add support for web page search functionality to help users find content easily.

=item Implement a feature to allow users to create and manage web page FAQs for common questions.

=item Add support for web page polls and surveys to gather user feedback.

=item Implement a feature to allow users to create and manage web page newsletters for email updates.

=item Add support for web page social sharing buttons to encourage content distribution.

=item Implement a feature to allow users to create and manage web page events and calendars.

=item Add support for web page user profiles to personalize content.

=back
