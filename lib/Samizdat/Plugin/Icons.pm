package Samizdat::Plugin::Icons;

use strict;
use warnings FATAL => 'all';

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::Home;
use Mojo::Template;
use Mojo::DOM;
use Mojo::Loader qw(data_section);

my $xml = Mojo::DOM->new->xml(1);

my $svgformat = q!<svg!;
$svgformat .= q! class="<%= $class %>"!;
$svgformat .= q!<% if ($id) { %> id="<%= $id %>"<% } %>!;
$svgformat .= q!<% if ($title) { %> title="<%= $title %>"<% } %>!;
$svgformat .= q!<% if ($width) { %> width="<%= $width %>"<% } %>!;
$svgformat .= q!<% if ($height) { %> height="<%= $height %>"<% } %>!;
$svgformat .= q!><use xlink:href="#<%= $prefix %>-<%= $icon %>"></use></svg>!;

my $mtsvg = Mojo::Template->new->vars(1);
$mtsvg->parse($svgformat);

my $symbolformat = q!<symbol!;
$symbolformat .= q! id="<%= $prefix %>-<%= $icon %>"!;
$symbolformat .= q! viewBox="<%= $viewbox %>"!;
$symbolformat .= q!><%= $content %></symbol>!;

my $mtsymbol = Mojo::Template->new->vars(1);
$mtsymbol->parse($symbolformat);

my $anyrepo = Mojo::Home->new();  # arbitrary-path SVGs (A2 follow-up)

sub register ($self, $app, $conf) {
  # Store OpenAPI fragment
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Icons} = $openapi_yaml if $openapi_yaml;

  my $r = $app->routes;

  # Vendored flag/icon SVGs via the install-aware shared-data resolver.
  my $flagsrepo = $app->sharedir('flag-icons');
  my $iconrepo  = $app->sharedir('icons', 'icons');
  # GET for HTML page, API routes handled by OpenAPI
  $r->get('/project/icons')->to(controller => 'Icons', action => 'icons')->name('icons_index');

  # Serve flag SVGs as static images for JS-populated content
  $r->get('/assets/flags/:cc' => sub ($c) {
    my $cc = lc $c->stash('cc');
    $cc =~ s/[^a-z]//g;
    my $path = $flagsrepo->child(sprintf('flags/4x3/%s.svg', $cc));
    return $c->reply->not_found unless -f $path;
    $c->res->headers->content_type('image/svg+xml');
    $c->res->headers->cache_control('public, max-age=86400');
    return $c->reply->file($path);
  })->name('flag_svg');

  $app->helper(
    icon => sub($c, $icon, $options = {}) {
      state $symbols = {};
      my $svg = '';
      my $what = $options->{what} // 'bi';
      my $prefix = $options->{prefix} // 'bi';
      if ('flag' eq $what) {
        $prefix = $options->{prefix} // 'flag';
      } elsif ('anysvg' eq $what) {
        $prefix = $options->{prefix} // 'anysvg';
      }
      my $stashsymbols = $c->stash('symbols') // {};
      
      # Only read file if not already cached
      if (!exists($symbols->{$icon})) {
        if ('flag' eq $what) {
          $svg = $flagsrepo->child(
            sprintf(q!flags/%s/%s.svg!, $options->{ratio} // '4x3', lc($icon))
          )->slurp;
        } elsif ('anysvg' eq $what) {
          $svg = $anyrepo->child($icon)->slurp;
          $icon = $options->{iconname};
        } else {
          $svg = $iconrepo->child($icon . '.svg')->slurp;
        }

        $xml->parse($svg);
        my $viewbox = $options->{viewbox} // $xml->at('svg')->attr("viewBox");
        my $content = $xml->at('svg')->content;
        $content =~ s/[\r\n]+//gms;
        $content =~ s/[\t]+//gms;
        $content =~ s/[\s]{2,}//gms;
        my $symbol = $mtsymbol->process({
          prefix  => $prefix,
          icon    => $icon,
          viewbox => $viewbox,
          content => $content,
        });
        chomp $symbol;
        $symbols->{$icon} = $symbol;
      }
      
      # Add to current request's stash
      $stashsymbols->{$icon} = $symbols->{$icon};
      $c->stash(symbols => $stashsymbols);
      my $class = $options->{class} // sprintf('%s %s-%s', $prefix, $prefix, $icon);
      $class .= ' ' . $options->{extraclass} if (exists $options->{extraclass});
      my $iconcode = $mtsvg->process({
        prefix => $prefix,
        icon   => $icon,
        id     => $options->{id} // '',
        class  => $class,
        title  => $options->{title} // '',
        width  => $options->{width} // '',
        height => $options->{height} // '',
      });
      chomp $iconcode;
      return $iconcode;
    }
  );

  $app->helper(
    flag => sub($c, $cc, $options =  {}) {
      $options->{what} = 'flag';
      $options->{iconname} = $cc;
      return $c->icon($cc, $options);
    }
  );

  $app->helper(
    anysvg => sub($c, $iconname, $filename, $options =  {}) {
      $options->{what} = 'anysvg';
      $iconname =~ s/[^A-Za-z0-9\-]+//g;
      $options->{iconname} = $iconname;
      return $c->icon($filename, $options);
    }
  );
}

1;

__DATA__
@@ openapi.yaml
# OpenAPI 3.0 fragment for Icons API
paths:
  /project/icons:
    get:
      tags:
        - Icons
      summary: List available icons
      description: Returns list of available Bootstrap icons. Returns HTML page or JSON based on Accept header.
      operationId: Icons.index
      responses:
        '200':
          description: List of icon names
          content:
            application/json:
              schema:
                type: object
                properties:
                  icons:
                    type: array
                    items:
                      type: string
                    description: List of icon names (without .svg extension)