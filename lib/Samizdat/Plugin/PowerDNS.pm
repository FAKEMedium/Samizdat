package Samizdat::Plugin::PowerDNS;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

sub register ($self, $app, $conf) {
  # Helper for accessing the PowerDNS API model.
  $app->helper(powerdns_api => sub ($c) {
    return Samizdat::Model::PowerDNS->new(
      api_url => $app->config('powerdns_api_url'),
      api_key => $app->config('powerdns_api_key'),
    );
  });

  # Define routes under /powerdns (authentication assumed via check_auth)
  my $r = $app->routes->under('/powerdns')->to('PowerDNS#check_auth');

  # Zone CRUD
  $r->get('/')->to('PowerDNS#index')->name('powerdns_index');
  $r->get('/zone/new')->to('PowerDNS#new_zone')->name('powerdns_zone_new');
  $r->post('/zone')->to('PowerDNS#create_zone')->name('powerdns_zone_create');
  $r->get('/zone/:id/edit')->to('PowerDNS#edit_zone')->name('powerdns_zone_edit');
  $r->put('/zone/:id')->to('PowerDNS#update_zone')->name('powerdns_zone_update');
  $r->delete('/zone/:id')->to('PowerDNS#delete_zone')->name('powerdns_zone_delete');

  # Record CRUD (records belong to a zone)
  $r->get('/zone/:zone_id/records')->to('PowerDNS#list_records')->name('powerdns_records');
  $r->get('/zone/:zone_id/record/new')->to('PowerDNS#new_record')->name('powerdns_record_new');
  $r->post('/zone/:zone_id/record')->to('PowerDNS#create_record')->name('powerdns_record_create');
  $r->get('/zone/:zone_id/record/:record_id/edit')->to('PowerDNS#edit_record')->name('powerdns_record_edit');
  $r->put('/zone/:zone_id/record/:record_id')->to('PowerDNS#update_record')->name('powerdns_record_update');
  $r->delete('/zone/:zone_id/record/:record_id')->to('PowerDNS#delete_record')->name('powerdns_record_delete');
}

1;
