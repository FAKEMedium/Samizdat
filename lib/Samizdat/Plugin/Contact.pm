package Samizdat::Plugin::Contact;

use strict;
use warnings FATAL => 'all';

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::Home;
use Mojo::Template;

use Data::Dumper;

my $mt = Mojo::Template->new;
$mt->parse('');

sub register ($self, $app, $conf = {}) {
  my $r = $app->routes;
  $r->any([qw( GET POST                  )] => '/contact')->to(controller => 'Contact', action => 'index');

  $app->helper(
    sendmail => sub($c, $recipient, $subject = '', $options =  {}) {

    }
  );
}

1;