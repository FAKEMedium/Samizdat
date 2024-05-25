package Samizdat::Plugin::Icons;

use strict;
use warnings FATAL => 'all';

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::Home;
use Mojo::Template;
use Mojo::DOM;

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
my $svgs = {};

my $symbolformat = q!<symbol!;
$symbolformat .= q! id="<%= $prefix %>-<%= $icon %>"!;
$symbolformat .= q! viewBox="<%= $viewbox %>"!;
$symbolformat .= q!><%= $content %></symbol>!;

my $mtsymbol = Mojo::Template->new->vars(1);
$mtsymbol->parse($symbolformat);
my $symbols = {};

my $flagsrepo = Mojo::Home->new('src/flag-icons/');
my $iconrepo = Mojo::Home->new('src/icons/icons/');
my $anyrepo = Mojo::Home->new();

sub register ($self, $app, $conf) {
  my $r = $app->routes;
  $r->any([qw( GET POST                  )] => '/project/icons')->to(controller => 'Icons', action => 'icons');

  $app->helper(
    icon => sub($c, $icon, $options = {}) {
      return $svgs->{$icon} // eval {
        my $svg;
        my $prefix = $options->{prefix} // 'bi';
        my $what = $options->{what} // 'bi';
        if ('flag' eq $what) {
          $prefix = $options->{prefix} // 'flag';
          $svg = $flagsrepo->child(
            sprintf(q!flags/%s/%s.svg!, $options->{ratio} // '4x3', lc($icon))
          )->slurp;
        } elsif ('anysvg' eq $what) {
          $prefix = $options->{prefix} // 'anysvg';
          $svg = $anyrepo->child($icon)->slurp;
          $icon = $options->{iconname};
        } else {
          $svg = $iconrepo->child($icon . '.svg')->slurp;
        }

        my $class = $options->{class} // sprintf('%s %s-%s', $prefix, $prefix, $icon);
        $class .= ' ' . $options->{extraclass} if (exists $options->{extraclass});
        $xml->parse($svg);
        my $viewbox = $options->{viewbox} // $xml->at('svg')->attr("viewBox");
        my $content = $xml->at('svg')->content;
        $content =~ s/[\r\n]+//gms;
        $content =~ s/[\t]+//gms;
        $content =~ s/[\s]{2,}//gms;
        $symbols->{$icon} = $mtsymbol->process({
          prefix  => $prefix,
          icon    => $icon,
          viewbox => $viewbox,
          content => $content,
        });
        chomp $symbols->{$icon};
        $app->{symbols}->{$icon} = $symbols->{$icon};
        $svgs->{$icon} = $mtsvg->process({
          prefix => $prefix,
          icon   => $icon,
          id     => $options->{id} // '',
          class  => $class,
          title  => $options->{title} // '',
          width  => $options->{width} // '',
          height => $options->{height} // '',
        });
        chomp $svgs->{$icon};
        return $svgs->{$icon};
      };
    },
  );

  $app->helper(
    flag => sub($c, $cc, $options =  {}) {
      $options->{what} = 'flag';
      $options->{iconname} = $cc;
      my $flag = $app->icon($cc, $options);
    }
  );

  $app->helper(
    anysvg => sub($c, $iconname, $filename, $options =  {}) {
      $options->{what} = 'anysvg';
      $iconname =~ s/[^A-Za-z0-9\-]+//g;
      $options->{iconname} = $iconname;
      my $anysvg = $app->icon($filename, $options);
    }
  );
}

1;