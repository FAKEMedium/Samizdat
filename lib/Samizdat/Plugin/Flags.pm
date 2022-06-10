package Samizdat::Plugin::Flags;

use strict;
use warnings FATAL => 'all';

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::Home;
use Mojo::Template;

use Data::Dumper;

my $mt = Mojo::Template->new;
$mt->parse('<svg class="fi fi-<%= $cc %>"><use xlink:href="#fi-<%= $cc %>"></use></svg>');
my $public = Mojo::Home->new('src/flag-icons/flags/');
my $cache = {};
my $symbols = {};


sub register  {
  my ($self, $app) = @_;

  $app->helper(
    flag => sub($c, $cc) {
      return $cache->{$cc} // eval {
        return $cache->{$cc} = $mt->process(flag => $public->child($cc . '.svg')->slurp);
      };
    },
  );
}

1;

