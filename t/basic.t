use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('Samizdat');
$t->get_ok('/')->status_is(200)->content_like(qr/Fake News is everywhere/i);

done_testing();

