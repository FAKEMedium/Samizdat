package Samizdat::Plugin::Zone;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Zone;
use Mojo::Pg;

sub register($self, $app, $conf) {
  my $r = $app->routes;

  my $manager = $r->manager('zones')->to(controller => 'Zone');
  $manager->get('/#zone_id/records/new')                    ->to('#new_record')         ->name('zone_record_new');
  $manager->get('/#zone_id/records/#record_id')             ->to('#edit_record')        ->name('zone_record_edit');
  $manager->patch('/#zone_id/records/#record_id')           ->to('#update_record')      ->name('zone_record_update');
  $manager->delete('/#zone_id/records/#record_id')          ->to('#delete_record')      ->name('zone_record_delete');
  $manager->get('/#zone_id/records')                        ->to('#records')            ->name('zone_record_index');
  $manager->post('/#zone_id/records')                       ->to('#create_record')      ->name('zone_record_create');
  $manager->get('/new')                                     ->to('#new_zone')           ->name('zone_new');
  $manager->get('/#zone_id/edit')                           ->to('#edit_zone')          ->name('zone_edit');
  $manager->patch('/#zone_id')                              ->to('#update_zone')        ->name('zone_update');
  $manager->delete('/#zone_id')                             ->to('#delete_zone')        ->name('zone_delete');
  $manager->post('/')                                       ->to('#create_zone')        ->name('zone_create');
  $manager->get('/')                                        ->to('#index')              ->name('zone_index');

  # Helper for PowerDNS database connection
  $app->helper(zonedb => sub($c) {
    state $db = do {
      my $config = $c->config->{manager}->{zone};
      my $env = $config->{default_env} || 'production';
      my $dsn = $config->{env}->{$env}->{dsn};

      my $pg = Mojo::Pg->new($dsn);
      $pg->max_connections(5);
      $pg;
    };
    return $db;
  });

  # Helper for accessing the Zone API model.
  $app->helper(zone => sub($c) {
    state $model = Samizdat::Model::Zone->new({
      config => $c->config->{manager}->{zone},
      cache  => $c->cache,
      db     => $c->zonedb,
    });
    return $model;
  });
}


1;
