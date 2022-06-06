use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('Samizdat');
$t->get_ok('/login/')
  ->status_is(200)
  ->content_like(qr/p4ss_word/);


done_testing();

