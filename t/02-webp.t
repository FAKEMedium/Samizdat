use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('Samizdat');
$t->get_ok('/test/')
  ->status_is(200)
  ->content_like(qr/Brown_Mushroom_on_the_Green_Grass.webp/);

$t->get_ok('/test/Brown_Mushroom_on_the_Green_Grass.webp')
  ->status_is(200)
  ->content_type_is('image/webp');

done_testing();

