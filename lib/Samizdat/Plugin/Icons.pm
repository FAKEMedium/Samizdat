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

my $symbolformat = q!<symbol!;
$symbolformat .= q! id="<%= $prefix %>-<%= $icon %>"!;
$symbolformat .= q! viewBox="<%= $viewbox %>"!;
$symbolformat .= q!><%= $content %></symbol>!;

my $mtsymbol = Mojo::Template->new->vars(1);
$mtsymbol->parse($symbolformat);

my $flagsrepo = Mojo::Home->new('src/flag-icons/');
my $iconrepo = Mojo::Home->new('src/icons/icons/');
my $anyrepo = Mojo::Home->new();

sub register ($self, $app, $conf) {
  my $r = $app->routes;
  $r->any([qw( GET POST )] => '/project/icons')->to(controller => 'Icons', action => 'icons');

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
      $c->{stash}->{symbols}->{$icon} = $symbols->{$icon};
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
      return $app->icon($cc, $options);
    }
  );

  $app->helper(
    anysvg => sub($c, $iconname, $filename, $options =  {}) {
      $options->{what} = 'anysvg';
      $iconname =~ s/[^A-Za-z0-9\-]+//g;
      $options->{iconname} = $iconname;
      return $app->icon($filename, $options);
    }
  );
}

1;