package Samizdat::Plugin::DNSAdmin;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::DNSAdmin;

sub register($self, $app, $conf) {

  my $r = $app->routes;
  my $manager = $r->under($app->config->{managerurl})->under('dnsadmin')->to(
    controller => 'Account',
    action     => 'authorize',
    require    => {
      users => $app->config->{account}->{admins}
    }
  );

#  my $manager = $app->routes->under('/powerdns')->to('DNSAdmin#check_auth');
  $manager->get('/zones/#zone_id/records/#record_id')->to('DNSAdmin#edit_record')->name('dnsadmin_record_edit');
  $manager->patch('/zones/#zone_id/records/#record_id')->to('DNSAdmin#update_record')->name('dnsadmin_record_update');
  $manager->delete('/zones/#zone_id/records/#record_id')->to('DNSAdmin#delete_record')->name('dnsadmin_record_delete');
  $manager->get('/zones/#zone_id/records')->to('DNSAdmin#list_records')->name('dnsadmin_record_index');
  $manager->post('/zones/#zone_id/records')->to('DNSAdmin#create_record')->name('dnsadmin_record_create');
  $manager->get('/zones/#zone_id/edit')->to('DNSAdmin#edit_zone')->name('dnsadmin_zone_edit');
  $manager->patch('/zones/#zone_id')->to('DNSAdmin#update_zone')->name('dnsadmin_zone_update');
  $manager->delete('/zones/#zone_id')->to('DNSAdmin#delete_zone')->name('dnsadmin_zone_delete');
  $manager->post('/zones')->to('DNSAdmin#create_zone')->name('dnsadmin_zone_create');
  $manager->get('/zones')->to('DNSAdmin#zones')->name('dnsadmin_zones');
  $manager->get('/')->to('DNSAdmin#index')->name('dnsadmin_index');


  # Helper for accessing the DNSAdmin API model.
  $app->helper(dnsadmin_api => sub($c) {
    state $powerdnsadmin_api = Samizdat::Model::DNSAdmin->new({
      api_url => $c->config->{dnsadmin}->{api}->{url},
      api_key => $c->config->{dnsadmin}->{api}->{key},
    });
  });

}


1;
