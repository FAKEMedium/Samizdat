package Samizdat::Plugin::Customer;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Customer;


sub register ($self, $app, $conf) {
  my $r = $app->routes;

  my $manager = $r->manager('customers')->to(controller => 'Customer');
  $manager->get('vatno/:vatno')           ->to('Customer#vatno')                        ->name('customer_vatno');
  $manager->any('sync')                   ->to('#sync')                                 ->name('customer_sync');
  $manager->get('first')                  ->to('Customer#first')                        ->name('customer_first');
  $manager->get('newest')                 ->to('Customer#newest')                       ->name('customer_newest');
  $manager->get('new')                    ->to('#edit', customerid => 0)                ->name('customer_new');
  $manager->post('new')                   ->to('#create', customerid => 0)              ->name('customer_create');
  $manager->get('/:customerid/prev')      ->to('#prev')                                 ->name('customer_prev');
  $manager->get('/:customerid/next')      ->to('#next')                                 ->name('customer_next');
  $manager->get('/:customerid')           ->to('#edit')                                 ->name('customer_edit');
  $manager->put('/:customerid')           ->to('#update')                               ->name('customer_update');
  $manager->get('/')                      ->to('#index')                                ->name('customer_index');

  $app->helper(customer => sub {
    state $customer = Samizdat::Model::Customer->new({app => shift});
    return $customer;
  });

}

1;
