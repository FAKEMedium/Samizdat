use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use YAML::XS qw(Load);
use Mojo::Home;
use Data::Dumper;


my $t = Test::Mojo->new('Samizdat');
$t->get_ok('/login/')
  ->status_is(200)
  ->content_like(qr/get_login_like/);

for my $username (sort {$a cmp $b} keys %{ $t->app->config->{account}->{superadmins} }) {
  my $password = $t->app->config->{account}->{superadmins}->{$username};
  $t->post_ok('/login/' => form => {
    username => $username, 'password' => $password
  })
    ->status_is(200)
    ->content_type_is('application/json')
    ->json_has('/username', $username);

  say $t->tx->res->body;
}

done_testing();

