use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('Samizdat');
$t->get_ok('/test/missing')->status_is(404)->content_like(qr/missing/i);

done_testing();

