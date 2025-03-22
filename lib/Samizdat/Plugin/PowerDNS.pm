package Samizdat::Plugin::PowerDNS;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::PowerDNS;

sub register($self, $app, $conf) {

  my $r = $app->routes;
  my $manager = $r->under($app->config->{managerurl})->under('powerdns')->to(
    controller => 'Account',
    action     => 'authorize',
    require    => {
      users => $app->config->{account}->{admins}
    }
  );

#  my $manager = $app->routes->under('/powerdns')->to('PowerDNS#check_auth');
  $manager->get('/zones/#zone_id/records/#record_id')->to('PowerDNS#show_record')->name('powerdns_record_show');
  $manager->patch('/zones/#zone_id/records/#record_id')->to('PowerDNS#update_record')->name('powerdns_record_update');
  $manager->delete('/zones/#zone_id/records/#record_id')->to('PowerDNS#delete_record')->name('powerdns_record_delete');
  $manager->get('/zones/#zone_id/records')->to('PowerDNS#list_records')->name('powerdns_record_index');
  $manager->post('/zones/#zone_id/records')->to('PowerDNS#create_record')->name('powerdns_record_create');
  $manager->get('/zones/#zone_id')->to('PowerDNS#show_zone')->name('powerdns_zone_show');
  $manager->patch('/zones/#zone_id')->to('PowerDNS#update_zone')->name('powerdns_zone_update');
  $manager->delete('/zones/#zone_id')->to('PowerDNS#delete_zone')->name('powerdns_zone_delete');
  $manager->post('/zones')->to('PowerDNS#create_zone')->name('powerdns_zone_create');
  $manager->get('/zones')->to('PowerDNS#zones')->name('powerdns_zones');
  $manager->get('/')->to('PowerDNS#index')->name('powerdns_index');


  # Helper for accessing the PowerDNS API model.
  $app->helper(powerdns_api => sub($c) {
    state $powerdns_api = Samizdat::Model::PowerDNS->new({
      api_url => $c->config->{powerdns}->{api}->{url},
      api_key => $c->config->{powerdns}->{api}->{key},
    });
  });

}


1;
