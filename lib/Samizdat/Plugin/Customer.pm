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
      users => $app->config->{account}->{admins}
    }
  );

  $manager->get('vatno/:vatno')->to('Customer#vatno')->name('customer_vatno');
  $manager->get('customers/first')->to('Customer#first')->name('customer_first');
  $manager->get('customers/newest')->to('Customer#newest')->name('customer_newest');
  $manager->get('customers/new')->to(controller => 'Customer', action => 'edit', customerid => 0)->name('customer_new');
  $manager->post('customers/new')->to(controller => 'Customer', action => 'create', customerid => 0)->name('customer_create');
  $manager->get('customers/:customerid/prev')->to('Customer#prev')->name('customer_prev');
  $manager->get('customers/:customerid/next')->to('Customer#next')->name('customer_next');
  $manager->get('customers/:customerid')->to(controller => 'Customer', action => 'edit')->name('customer_edit');
  $manager->put('customers/:customerid')->to(controller => 'Customer', action => 'update')->name('customer_update');
  $manager->any('customers/sync')->to('Customer#sync')->name('customer_sync');
  $manager->get('customers')->to('Customer#index')->name('customer_index');

  $app->helper(customer => sub {
    state $customer = Samizdat::Model::Customer->new({app => shift});
    return $customer;
  });

}

1;
