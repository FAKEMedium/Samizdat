package Samizdat::Plugin::DNSAdmin;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::DNSAdmin;

sub register($self, $app, $conf) {

  my $r = $app->routes;
  my $dnsadmin = $r->under($app->config->{managerurl})->under('dnsadmin')->to(
    controller => 'Account',
    action     => 'authorize',
    require    => {
      users => $app->config->{account}->{admins}
    }
  );

  $dnsadmin->get('/#zone_id/records/#record_id')->to('DNSAdmin#edit_record')->name('dnsadmin_record_edit');
  $dnsadmin->patch('/#zone_id/records/#record_id')->to('DNSAdmin#update_record')->name('dnsadmin_record_update');
  $dnsadmin->delete('/#zone_id/records/#record_id')->to('DNSAdmin#delete_record')->name('dnsadmin_record_delete');
  $dnsadmin->get('/#zone_id/records')->to('DNSAdmin#records')->name('dnsadmin_record_index');
  $dnsadmin->post('/#zone_id/records')->to('DNSAdmin#create_record')->name('dnsadmin_record_create');
  $dnsadmin->get('/#zone_id/edit')->to('DNSAdmin#edit_zone')->name('dnsadmin_zone_edit');
  $dnsadmin->patch('/#zone_id')->to('DNSAdmin#update_zone')->name('dnsadmin_zone_update');
  $dnsadmin->delete('/#zone_id')->to('DNSAdmin#delete_zone')->name('dnsadmin_zone_delete');
  $dnsadmin->post('/')->to('DNSAdmin#create_zone')->name('dnsadmin_zone_create');
  $dnsadmin->get('/')->to('DNSAdmin#zones')->name('dnsadmin_zones');


  # Helper for accessing the DNSAdmin API model.
  $app->helper(dnsadmin => sub($c) {
    state $dnsadmin = Samizdat::Model::DNSAdmin->new({
      config => $c->config->{dnsadmin},
    });
  });

}


1;
