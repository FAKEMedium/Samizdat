package Samizdat::Plugin::Web;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Web;
use Mojo::Home;
use Mojo::DOM;
use Mojo::Util qw(decode);
use Mojo::Loader qw(data_section);
use Digest::SHA qw(sha256_base64);
use IO::Compress::Gzip;
use IO::Compress::Brotli qw(bro);
use Imager;
use Data::Dumper;

my $public = Mojo::Home->new('public/');
my $templates = Mojo::Home->new('templates/');
my $image = Imager->new;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  # Store OpenAPI fragment (parsed centrally in _load_openapi)
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Web} = $openapi_yaml if $openapi_yaml;

  # Manager routes (HTML pages only - GET)
  my $manager = $r->manager('web')->to(controller => 'Web');
  $manager->get('editor/toolbar')                     ->to('#editor_toolbar')    ->name('web_editor_toolbar');
  $manager->get('editor')                             ->to('#editor')            ->name('web_editor');
  $manager->get('menus/:menuid/items/new')            ->to('#menuitem')          ->name('web_menuitem_new');
  $manager->get('menus/:menuid/items/:menuitemid')    ->to('#menuitem')          ->name('web_menuitem');
  $manager->get('menus/:menuid')                      ->to('#menu')              ->name('web_menu');
  $manager->get('menus')                              ->to('#menus')             ->name('web_menus');
  $manager->get('languages')                          ->to('#languages')         ->name('web_languages');
  $manager->get('images')                             ->to('#images')            ->name('web_images');
  $manager->get('new')                                ->to('#addcontent')        ->name('web_new');
  $manager->get('src/*srcpath')                       ->to('#src')               ->name('web_src');
  $manager->get('src')                                ->to('#src', srcpath => '')->name('web_src_root');
  $manager->get('source/*docpath')                    ->to('#source')            ->name('web_source');
  $manager->get('source')                             ->to('#source', docpath => '')->name('web_source_root');
  $manager->get('/')                                  ->to('#index')             ->name('web_index');

  # API routes are defined in OpenAPI spec (__DATA__ section)

  # Things coming from configuration file
  my $web  = $r->home->to(controller => 'Web');
  $web->get('manifest.json')               ->to('#manifest',  docpath => 'manifest.json');
  $web->get('robots.txt')                  ->to('#robots',    docpath => 'robots.txt');
  $web->get('humans.txt')                  ->to('#humans',    docpath => 'humans.txt');
  $web->get('ads.txt')                     ->to('#ads',       docpath => 'ads.txt');
  $web->get('sw-routes.json')              ->to('#sw_routes', docpath => undef)->name('sw_routes');
  $web->get('assets/sw.js')                ->to('#sw_js',     docpath => 'assets/sw.js')->name('sw_js');

  # Home page route - specific route here, wildcard catch-all registered separately in Samizdat.pm
  # after OpenAPI routes to ensure proper route priority
  $web->get('/')                           ->to('#getdoc',    docpath => '')->name('home');


  # Helper to get the real IP address of the client. Call this from controller object ($c->getip
  $app->helper(getip => sub ($self) {
    # Try various methods to get the real IP
    my $ip = $self->tx->remote_address
      // $self->req->headers->header('X-Real-IP')
      // $self->req->headers->header('X-Forwarded-For')
      // $self->req->headers->header('Remote-Host')
      // $self->tx->original_remote_address
      // '0.0.0.0';

    # If X-Forwarded-For contains multiple IPs, take the first one
    if ($ip && $ip =~ /,/) {
      $ip = (split /,\s*/, $ip)[0];
    }

    return $ip;
  });


  # Helper for accessing the Web model.
  $app->helper(web => sub ($self) {
    state $model = Samizdat::Model::Web->new(
      config       => $self->config->{manager}->{web},
      database     => $self->app->pg,
      locale       => $self->config->{locale}
    );
    return $model;
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

  # Menu helper - renders a menu by name or ID
  # Usage: <%== menu('main') %>
  #        <%== menu('main', { template => 'web/chunks/menu/sidebar', skip_root => 1 }) %>
  #        menu('main', { json => 1 })  # returns data structure for JSON rendering
  $app->helper(
    menu => sub ($c, $name_or_id, $options = {}) {
      return $options->{json} ? undef : '' unless defined $name_or_id;

      # Get localized menu from model
      my $lang = $c->stash('language') // $c->config->{locale}->{default_language};
      my $data;
      eval { $data = $c->web->getLocalizedMenu($name_or_id, $lang) };
      return $options->{json} ? undef : '' if $@ || !$data || !$data->{items} || !@{$data->{items}};

      # Skip root level if requested (use children of first root item)
      my $items = $data->{items};
      if ($options->{skip_root} && @$items == 1 && $items->[0]{items} && @{$items->[0]{items}}) {
        $items = $items->[0]{items};
      }

      # Return JSON data structure if requested
      return { menu => $data->{menu}, items => $items } if $options->{json};

      # Render the menu template
      my $template = $options->{template} // 'web/chunks/menu/navbar';
      return $c->render_to_string(template => $template, items => $items) // '';
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


  # Automatically set canonical URLs and meta tags for all pages
  $app->hook(before_render => sub ($c, $args) {
    # Skip if rendering non-HTML or if web/title not set
    return unless $args->{template};
    return unless $c->stash('web') && $c->stash('title');

    my $web = $c->stash('web');
    my $title = $c->stash('title');

    # Set canonical URL if not already set
    unless ($web->{head}->{canonical}) {
      my $docpath = $c->stash('docpath') || $c->req->url->path->to_string;

      # Clean up the path: remove /index.html suffix and normalize slashes
      $docpath =~ s|/index\.html$||;  # Remove /index.html suffix
      $docpath =~ s|^/+|/|;            # Ensure single leading slash

      my $canonical = sprintf('%s%s%s',
        $c->config->{siteurl},
        $c->config->{baseurl},
        $docpath
      );

      # Remove double slashes (but keep :// for protocol)
      $canonical =~ s|([^:])//+|$1/|g;

      $web->{head}->{canonical} = $canonical;
    }

    # Set meta tags
    $web->{head}->{meta}->{property}->{'og:title'} ||= $title;
    $web->{head}->{meta}->{property}->{'og:url'} ||= $web->{head}->{canonical};
    $web->{head}->{meta}->{property}->{'og:canonical'} ||= $web->{head}->{canonical};
    $web->{head}->{meta}->{name}->{'twitter:title'} ||= $title;
    $web->{head}->{meta}->{name}->{'twitter:url'} ||= $web->{head}->{canonical};
    $web->{head}->{meta}->{itemprop}->{'name'} ||= $title;

    # Set description meta tags if description exists
    if (my $desc = $web->{head}->{meta}->{name}->{description}) {
      $web->{head}->{meta}->{property}->{'og:description'} ||= $desc;
      $web->{head}->{meta}->{name}->{'twitter:description'} ||= $desc;
      $web->{head}->{meta}->{itemprop}->{'description'} ||= $desc;
    }

    # Set image meta tags if selectedimage exists
    if (my $img = $web->{selectedimage}) {
      if ($img->{src}) {
        my $pngsrc = $img->{src};
        $pngsrc =~ s/\.(webp|jpg|jpeg|png|gif|tiff|bmp)$/.png/;
        $web->{head}->{meta}->{property}->{'og:image'} ||= $pngsrc;
        $web->{head}->{meta}->{name}->{'twitter:image'} ||= $pngsrc;
      }
      if ($img->{width}) {
        $web->{head}->{meta}->{property}->{'og:image:width'} ||= $img->{width};
      }
      if ($img->{height}) {
        $web->{head}->{meta}->{property}->{'og:image:height'} ||= $img->{height};
      }
    }
  });


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
        my $default_language = $c->config->{locale}->{default_language};
        my $is_default_lang = ($default_language eq $language);
        # Always use language suffix for all languages
        $docpath =~ s/\.html$/.$language.html/;
        # Generate CSP hashes for inline scripts and styles
        # Only match inline scripts (no src attribute) to avoid capturing across external script tags
        my @script_hashes;
        my @style_hashes;
        while ($$output =~ m{<script(?![^>]*\ssrc\s*=)[^>]*>([^<]+(?:<(?!/script>)[^<]*)*)</script>}gsi) {
          my $content = $1;
          next unless $content =~ /\S/;  # skip empty
          my $hash = sha256_base64($content);
          $hash .= '=' x (4 - length($hash) % 4) if length($hash) % 4;  # pad base64
          push @script_hashes, "'sha256-$hash'";
        }
        while ($$output =~ m{<style[^>]*>(.+?)</style>}gs) {
          my $content = $1;
          next unless $content =~ /\S/;
          my $hash = sha256_base64($content);
          $hash .= '=' x (4 - length($hash) % 4) if length($hash) % 4;
          push @style_hashes, "'sha256-$hash'";
        }
        # Generate CSP policy and inject meta tag into <head>
        my $csp_policy = '';
        if (@script_hashes || @style_hashes) {
          my $csp = $c->config->{csp} // {};
          my $default_src = $csp->{default_src} // "'self' data:";
          # script_src_extra allows adding 'unsafe-eval' or external sources from config
          my $script_src_extra = $csp->{script_src_extra} // '';
          my $script_src = "'self' blob: " . join(' ', @script_hashes) . ($script_src_extra ? " $script_src_extra" : '');
          # 'unsafe-inline' for style-src covers style attributes on elements (SVG, etc.)
          my $style_src = "'self' 'unsafe-inline'";
          my $img_src = $csp->{img_src} // "'self' data: *";
          my $font_src = $csp->{font_src} // "'self' data:";
          my $connect_src = $csp->{connect_src} // "'self'";
          my $frame_ancestors = $csp->{frame_ancestors} // "'none'";
          # Meta tag policy (frame-ancestors not supported in meta)
          my $csp_meta_policy = "default-src $default_src; script-src $script_src; style-src $style_src; img-src $img_src; font-src $font_src; connect-src $connect_src";
          # Full policy for companion file (includes frame-ancestors)
          $csp_policy = "$csp_meta_policy; frame-ances tors $frame_ancestors";
          my $csp_meta = qq{<meta http-equiv="Content-Security-Policy" content="$csp_meta_policy">};
          $$output =~ s{(</head>)}{  $csp_meta\n  $1};
        }
        $c->app->web->tidyup($output);
        if ($c->config->{cache} && $docpath ne '') {
          $public->child($docpath)->dirname->make_path;
          $public->child($docpath)->spew($$output);
          # Companion CSP file for OpenResty
          $public->child($docpath . '.csp')->spew($csp_policy) if $csp_policy;
          # Gzip compression
          my $z = new IO::Compress::Gzip sprintf('%s.gz', $public->child($docpath)->to_string),
            -Level => 9, Minimal => 1, AutoClose => 1;
          $z->print($$output);
          $z->close;
          undef $z;
          # Brotli compression (better ratio, for nginx brotli_static)
          # quality=11 (max), lgwin=24 (max window) - slow but best compression
          $public->child($docpath . '.br')->spew(bro($$output, 11, 24));
          # Create index.html symlink for default language (works in ISO with Rock Ridge)
          if ($is_default_lang && $docpath =~ /index\.\w+\.html$/) {
            my $symlink_path = $docpath;
            $symlink_path =~ s/index\.\w+\.html$/index.html/;
            my $symlink_file = $public->child($symlink_path);
            my $target_file = $public->child($docpath);
            # Get just the filename for relative symlink
            my $target_name = $target_file->basename;
            unlink $symlink_file if -e $symlink_file || -l $symlink_file;
            symlink $target_name, $symlink_file->to_string;
          }
        }
      }
      if ($c->config->{manager}->{web}->{imageconversion}->{format}->{webp} && ($c->{stash}->{web}->{url} =~ /\.webp$/)) {
        my $publicsrc = Mojo::Home->new($c->config->{manager}->{web}->{src} // 'src')->child('public');
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

=head1 STATIC CACHE AND NGINX

The C<after_render> hook in this plugin generates static HTML files in the
C<public/> directory. These files can be served directly by nginx, bypassing
the Perl application for dramatically improved performance.

=head2 The docpath Stash Variable

For routes with dynamic parameters (like C</:id> or C</#domain>), set the
C<docpath> stash variable in your controller to ensure all variations use
the same cached template file:

    # In controller - all customer IDs share one cached file
    sub edit ($self) {
        $self->stash(docpath => '/customers/customer/edit/index.html');
        # ... render template
    }

Without C<docpath>, each customer would create a separate cached file:

    public/customers/123/edit/index.html
    public/customers/456/edit/index.html
    public/customers/789/edit/index.html

With C<docpath>, all share one file:

    public/customers/customer/edit/index.html

=head2 Nginx Regex Routes for Dynamic Parameters

Configure nginx to rewrite dynamic URLs to the shared cached path.
The manager URL prefix is configurable (e.g., C</manager/> or C</rs/>).

    # Menu edit page - any menu ID uses same cached template
    # /rs/web/menus/123 -> /rs/web/menus/menu/index.html
    location ~ ^/(manager|rs)/web/menus/\d+/?$ {
        root /path/to/public;
        try_files /$1/web/menus/menu/index.html @backend;
    }

    # Menu item pages - any menu/item ID uses same cached template
    # /rs/web/menus/123/items/456 -> /rs/web/menus/menu/item/index.html
    location ~ ^/(manager|rs)/web/menus/\d+/items/(\d+|new)/?$ {
        root /path/to/public;
        try_files /$1/web/menus/menu/item/index.html @backend;
    }

    # Source browser with path - all paths use same template
    # /rs/web/src/documentation/guides -> /rs/web/src/index.html
    location ~ ^/(manager|rs)/web/src/.+$ {
        root /path/to/public;
        try_files /$1/web/src/index.html @backend;
    }

    # Fallback to application
    location @backend {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

=head2 Compressed Static Files

The C<after_render> hook creates compressed versions of cached files:

=over 4

=item * C<file.html> - Original HTML

=item * C<file.html.gz> - Gzip compressed (for C<gzip_static on>)

=item * C<file.html.br> - Brotli compressed (for C<brotli_static on>)

=back

Enable static compression in nginx:

    gzip_static on;
    brotli_static on;

Nginx will automatically serve C<.gz> or C<.br> files when the client
supports compression, without needing to compress on-the-fly.

=head2 Service Worker

The Service Worker at C</assets/sw.js> provides client-side caching for
dynamic routes. When serving the cached file directly, nginx must add the
C<Service-Worker-Allowed> header to permit the worker to control the entire
site (service workers normally only control paths at or below their location):

    location = /assets/sw.js {
        add_header Service-Worker-Allowed /;
        add_header Cache-Control "no-cache";
    }

The C<no-cache> directive ensures browsers check for updates, while still
allowing conditional requests (304 Not Modified).

=head2 Complete Nginx Configuration Example

    server {
        listen 443 ssl http2;
        server_name example.com;
        root /path/to/samizdat/public;

        # Enable pre-compressed files
        gzip_static on;
        brotli_static on;

        # Static assets - serve directly
        location /media/ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # Service Worker - requires special header for root scope
        location = /assets/sw.js {
            add_header Service-Worker-Allowed /;
            add_header Cache-Control "no-cache";
        }

        # API routes - always proxy
        location /api/ {
            proxy_pass http://127.0.0.1:3000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        # Manager dynamic routes with regex
        location ~ ^/manager/customers/\d+/ {
            try_files /manager/customers/customer$uri/index.html @backend;
        }

        location ~ ^/manager/zones/[^/]+/ {
            try_files /manager/zones/_zone_id$uri/index.html @backend;
        }

        # Default - try static then proxy
        location / {
            try_files $uri $uri/index.html @backend;
        }

        location @backend {
            proxy_pass http://127.0.0.1:3000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }

=head2 Cache Invalidation

When content changes, the cached file must be regenerated. The model provides
an C<invalidate_cache> method that deletes the cached file and its compressed
variants. The next request will regenerate the cache through the application.

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

=cut

1;

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for Web API (content management)
paths:
  /web/menus:
    get:
      operationId: Web.menus.index
      x-mojo-to: Web#menus
      summary: List all menus
      tags: [Web]
      responses:
        '200':
          description: List of menus
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Web_MenuListResponse'
    post:
      operationId: Web.menus.create
      x-mojo-to: Web#menus
      summary: Create new menu
      tags: [Web]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Web_MenuInput'
      responses:
        '200':
          description: Menu created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Web_Result'

  /web/menus/{menuid}:
    get:
      operationId: Web.menus.get
      x-mojo-to: Web#menu
      summary: Get menu details
      tags: [Web]
      parameters:
        - name: menuid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Menu data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Web_Menu'
    post:
      operationId: Web.menus.update
      x-mojo-to: Web#menu
      summary: Update menu
      tags: [Web]
      parameters:
        - name: menuid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Web_MenuInput'
      responses:
        '200':
          description: Menu updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Web_Result'
    delete:
      operationId: Web.menus.delete
      x-mojo-to: Web#menu
      summary: Delete menu
      tags: [Web]
      parameters:
        - name: menuid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Menu deleted
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Web_Result'

  /web/menus/{menuid}/reorder:
    post:
      operationId: Web.menus.reorder
      x-mojo-to: Web#menuitems_reorder
      summary: Reorder menu items
      tags: [Web]
      parameters:
        - name: menuid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                order:
                  type: array
                  items:
                    type: integer
      responses:
        '200':
          description: Items reordered
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Web_Result'

  /web/menus/{menuid}/items:
    post:
      operationId: Web.menuitems.create
      x-mojo-to: Web#menuitem
      summary: Create new menu item
      tags: [Web]
      parameters:
        - name: menuid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Web_MenuItemInput'
      responses:
        '200':
          description: Menu item created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Web_Result'

  /web/menus/{menuid}/items/{menuitemid}:
    get:
      operationId: Web.menuitems.get
      x-mojo-to: Web#menuitem
      summary: Get menu item details
      tags: [Web]
      parameters:
        - name: menuid
          in: path
          required: true
          schema:
            type: integer
        - name: menuitemid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Menu item data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Web_MenuItem'
    post:
      operationId: Web.menuitems.update
      x-mojo-to: Web#menuitem
      summary: Update menu item
      tags: [Web]
      parameters:
        - name: menuid
          in: path
          required: true
          schema:
            type: integer
        - name: menuitemid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Web_MenuItemInput'
      responses:
        '200':
          description: Menu item updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Web_Result'
    delete:
      operationId: Web.menuitems.delete
      x-mojo-to: Web#menuitem
      summary: Delete menu item
      tags: [Web]
      parameters:
        - name: menuid
          in: path
          required: true
          schema:
            type: integer
        - name: menuitemid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Menu item deleted
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Web_Result'

  /web/translate:
    post:
      operationId: Web.translate
      x-mojo-to: Web#translate
      summary: Translate markdown content using AI
      tags: [Web]
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                markdown:
                  type: string
                  description: Markdown content to translate
                target_language:
                  type: string
                  description: Target language code (e.g., 'es', 'sv')
                frontmatter:
                  type: string
                  description: Optional YAML frontmatter to translate
              required:
                - markdown
                - target_language
      responses:
        '200':
          description: Translation successful
          content:
            application/json:
              schema:
                type: object
                properties:
                  success:
                    type: boolean
                  translated:
                    type: string
                  frontmatter:
                    type: string

  /web/languages:
    get:
      operationId: Web.languages.index
      x-mojo-to: Web#languages
      summary: List available languages
      tags: [Web]
      responses:
        '200':
          description: List of languages
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Web_LanguageListResponse'

  /web/images:
    get:
      operationId: Web.images.index
      x-mojo-to: Web#images
      summary: List images
      tags: [Web]
      responses:
        '200':
          description: List of images
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Web_ImageListResponse'

  /web/src/{srcpath}:
    get:
      operationId: Web.src.list
      x-mojo-to: Web#src
      summary: List directory structure
      tags: [Web]
      parameters:
        - name: srcpath
          in: path
          required: true
          x-mojo-placeholder: "*"
          schema:
            type: string
          description: Directory path (%2F-encoded, _ for root)
      responses:
        '200':
          description: Directory listing
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Web_FileTreeResponse'
    post:
      operationId: Web.src.create
      x-mojo-to: Web#src
      summary: Create new directory or file
      tags: [Web]
      parameters:
        - name: srcpath
          in: path
          required: true
          x-mojo-placeholder: "*"
          schema:
            type: string
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Web_FileTreeInput'
      responses:
        '200':
          description: Item created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Web_Result'
    put:
      operationId: Web.src.save
      x-mojo-to: Web#src_save
      summary: Save content changes
      tags: [Web]
      parameters:
        - name: srcpath
          in: path
          required: true
          x-mojo-placeholder: "*"
          schema:
            type: string
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                editors:
                  type: array
                  items:
                    type: object
                format:
                  type: string
                target:
                  type: string
      responses:
        '200':
          description: Content saved
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Web_Result'

    patch:
      operationId: Web.src.rename
      x-mojo-to: Web#src_rename
      summary: Rename file or directory
      tags: [Web]
      parameters:
        - name: srcpath
          in: path
          required: true
          x-mojo-placeholder: "*"
          schema:
            type: string
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                newPath:
                  type: string
              required:
                - newPath
      responses:
        '200':
          description: Item renamed
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Web_Result'
    delete:
      operationId: Web.src.delete
      x-mojo-to: Web#src_delete
      summary: Delete file or directory
      tags: [Web]
      parameters:
        - name: srcpath
          in: path
          required: true
          x-mojo-placeholder: "*"
          schema:
            type: string
      responses:
        '200':
          description: Item deleted
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Web_Result'

components:
  schemas:
    Web_Menu:
      type: object
      properties:
        menuid:
          type: integer
        menuname:
          type: string
        description:
          type: string
        items:
          type: array
          items:
            $ref: '#/components/schemas/Web_MenuItem'
    Web_MenuInput:
      type: object
      properties:
        menuname:
          type: string
        description:
          type: string
    Web_MenuItem:
      type: object
      properties:
        menuitemid:
          type: integer
        menuid:
          type: integer
        parentid:
          type: integer
        sortorder:
          type: integer
        resourceid:
          type: integer
        url:
          type: string
        target:
          type: string
        titles:
          type: object
    Web_MenuItemInput:
      type: object
      properties:
        parentid:
          type: integer
        sortorder:
          type: integer
        resourceid:
          type: integer
        url:
          type: string
        target:
          type: string
        titles:
          type: object
    Web_MenuListResponse:
      type: object
      properties:
        menus:
          type: array
          items:
            $ref: '#/components/schemas/Web_Menu'
    Web_LanguageListResponse:
      type: object
      properties:
        languages:
          type: array
          items:
            type: object
            properties:
              code:
                type: string
              name:
                type: string
    Web_ImageListResponse:
      type: object
      properties:
        images:
          type: array
          items:
            type: object
            properties:
              path:
                type: string
              url:
                type: string
              width:
                type: integer
              height:
                type: integer
    Web_Result:
      type: object
      properties:
        success:
          type: boolean
        error:
          type: string
        message:
          type: string
    Web_FileTreeItem:
      type: object
      properties:
        name:
          type: string
        path:
          type: string
        type:
          type: string
          enum: [directory, file]
        hasChildren:
          type: boolean
        languages:
          type: array
          items:
            type: string
    Web_FileTreeResponse:
      type: object
      properties:
        success:
          type: boolean
        path:
          type: string
        items:
          type: array
          items:
            $ref: '#/components/schemas/Web_FileTreeItem'
    Web_FileTreeInput:
      type: object
      properties:
        path:
          type: string
        type:
          type: string
          enum: [directory, file, sidecard]
        language:
          type: string
          description: Language code (e.g., en, sv, ru)
        target:
          type: string
          enum: [file, database]
          description: Storage target for content
      required:
        - path
        - type
