package Samizdat::Plugin::Icons;

use strict;
use warnings FATAL => 'all';

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::Home;
use Mojo::Template;

use Data::Dumper;

my $mt = Mojo::Template->new;
$mt->parse('<svg class="bi bi-<%= $icon %>"><use xlink:href="#bi-<%= $icon %>"></use></svg>');
my $public = Mojo::Home->new('src/icons/icons/');
my $cache = {};
my $symbols = {};


sub register  {
  my ($self, $app) = @_;

  $app->helper(
    icon => sub($c, $icon) {
      return $cache->{$icon} // eval {
        return $cache->{$icon} = $mt->process(icon => $public->child($icon . '.svg')->slurp);
      };
    },
  );

  $app->helper(
    symbols => sub($c) {
      return $symbols;
    },
  );
}

1;

