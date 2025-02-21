package Samizdat::Plugin::PowerDNS;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::PowerDNS;

sub register($self, $app, $conf) {
  # Helper for accessing the PowerDNS API model.
  $app->helper(powerdns_api => sub($c) {
    state $powerdns_api = Samizdat::Model::PowerDNS->new({
      api_url => $c->config->{powerdns}->{api}->{url},
      api_key => $c->config->{powerdns}->{api}->{key},
    });
  });

  my $r = $app->routes->under('/powerdns')->to('PowerDNS#check_auth');
  $r->get('/zones/#zone_id/records/#record_id')->to('PowerDNS#show_record')->name('powerdns_record_show');
  $r->patch('/zones/#zone_id/records/#record_id')->to('PowerDNS#update_record')->name('powerdns_record_update');
  $r->delete('/zones/#zone_id/records/#record_id')->to('PowerDNS#delete_record')->name('powerdns_record_delete');
  $r->get('/zones/#zone_id/records')->to('PowerDNS#list_records')->name('powerdns_record_index');
  $r->post('/zones/#zone_id/records')->to('PowerDNS#create_record')->name('powerdns_record_create');
  $r->get('/zones/#zone_id')->to('PowerDNS#show_zone')->name('powerdns_zone_show');
  $r->patch('/zones/#zone_id')->to('PowerDNS#update_zone')->name('powerdns_zone_update');
  $r->delete('/zones/#zone_id')->to('PowerDNS#delete_zone')->name('powerdns_zone_delete');
  $r->post('/zones')->to('PowerDNS#create_zone')->name('powerdns_zone_create');
  $r->get('/zones')->to('PowerDNS#index')->name('powerdns_index');
}


1;
