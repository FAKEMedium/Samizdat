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

  $app->helper(
    contactform => sub($c, $recipient, $subject = '') {

    }
  );
}

1;