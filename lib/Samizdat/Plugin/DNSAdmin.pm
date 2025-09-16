package Samizdat::Plugin::DNSAdmin;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::DNSAdmin;

sub register($self, $app, $conf) {
  my $r = $app->routes;

  my $manager = $r->manager('dnsadmin')->to(controller => 'DNSAdmin');
  $manager->get('/#zone_id/records/#record_id')             ->to('#edit_record')        ->name('dnsadmin_record_edit');
  $manager->patch('/#zone_id/records/#record_id')           ->to('#update_record')      ->name('dnsadmin_record_update');
  $manager->delete('/#zone_id/records/#record_id')          ->to('#delete_record')      ->name('dnsadmin_record_delete');
  $manager->get('/#zone_id/records')                        ->to('#records')            ->name('dnsadmin_record_index');
  $manager->post('/#zone_id/records')                       ->to('#create_record')      ->name('dnsadmin_record_create');
  $manager->get('/#zone_id/edit')                           ->to('#edit_zone')          ->name('dnsadmin_zone_edit');
  $manager->patch('/#zone_id')                              ->to('#update_zone')        ->name('dnsadmin_zone_update');
  $manager->delete('/#zone_id')                             ->to('#delete_zone')        ->name('dnsadmin_zone_delete');
  $manager->post('/')                                       ->to('#create_zone')        ->name('dnsadmin_zone_create');
  $manager->get('/')                                        ->to('#zones')              ->name('dnsadmin_zones');

  # Helper for accessing the DNSAdmin API model.
  $app->helper(dnsadmin => sub($self) {
    state $dnsadmin = Samizdat::Model::DNSAdmin->new({
      config => $self->config->{manager}->{dnsadmin},
    });
    return $dnsadmin;
  });
}


1;
