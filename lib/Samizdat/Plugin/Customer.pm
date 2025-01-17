package Samizdat::Plugin::Customer;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Customer;
use Mojo::Home;
use Mojo::File;
use Data::Dumper;

sub register ($self, $app, $conf) {
  my $r = $app->routes;
  my $manager = $r->under($app->config->{managerurl})->to(
    controller => 'Account',
    action     => 'authorize',
    require    => {
#      users => $app->config->{account}->{admins}
    }
  );

  $manager->get('customers')->to('Customer#index');
  $manager->get('vatno/:vatno')->to('Customer#vatno');
  $manager->get('customers')->to('Customer#index');
  $manager->get('customers/first')->to('Customer#first');
  $manager->get('customers/newest')->to('Customer#newest');
  $manager->get('customers/:customerid/prev')->to('Customer#prev');
  $manager->get('customers/:customerid/next')->to('Customer#next');
  $manager->get('customers/new')->to(controller => 'Customer', action => 'edit', customerid => 0);
  $manager->post('customers/new')->to(controller => 'Customer', action => 'create', customerid => 0);
  $manager->get('customers/:customerid')->to(controller => 'Customer', action => 'edit');
  $manager->put('customers/:customerid')->to(controller => 'Customer', action => 'update');
  $manager->any('customers/sync')->to('Customer#sync');

  $app->helper(customer => sub { state $customer = Samizdat::Model::Customer->new({app => shift}) });

}

1;
