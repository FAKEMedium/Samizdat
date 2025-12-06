package Samizdat::Plugin::Zone;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Zone;
use Mojo::Pg;

sub register($self, $app, $conf) {
  my $r = $app->routes;

  my $manager = $r->manager('zones')->to(controller => 'Zone');
  # Record routes
  $manager->get('/#zone_id/records/new')                    ->to('#new_record')         ->name('zone_record_new');
  $manager->get('/#zone_id/records/#record_id')             ->to('#edit_record')        ->name('zone_record_edit');
  $manager->patch('/#zone_id/records/#record_id')           ->to('#update_record')      ->name('zone_record_update');
  $manager->delete('/#zone_id/records/#record_id')          ->to('#delete_record')      ->name('zone_record_delete');
  $manager->get('/#zone_id/records')                        ->to('#records')            ->name('zone_record_index');
  $manager->post('/#zone_id/records')                       ->to('#create_record')      ->name('zone_record_create');
  # DNSSEC routes
  $manager->delete('/#zone_id/cryptokeys/#key_id')          ->to('#delete_cryptokey')   ->name('zone_cryptokey_delete');
  $manager->get('/#zone_id/cryptokeys')                     ->to('#cryptokeys')         ->name('zone_cryptokeys');
  $manager->post('/#zone_id/cryptokeys')                    ->to('#create_cryptokey')   ->name('zone_cryptokey_create');
  # Template routes
  $manager->get('/templates/:template_id/records/:record_id')    ->to('#get_template_record')       ->name('zone_template_record_get');
  $manager->patch('/templates/:template_id/records/:record_id')  ->to('#update_template_record')    ->name('zone_template_record_update');
  $manager->delete('/templates/:template_id/records/:record_id') ->to('#delete_template_record')    ->name('zone_template_record_delete');
  $manager->post('/templates/:template_id/records')         ->to('#create_template_record')    ->name('zone_template_record_create');
  $manager->get('/templates/:template_id')                  ->to('#get_template')              ->name('zone_template_get');
  $manager->post('/templates/:template_id/duplicate')       ->to('#duplicate_template')        ->name('zone_template_duplicate');
  $manager->patch('/templates/:template_id')                ->to('#update_template')           ->name('zone_template_update');
  $manager->delete('/templates/:template_id')               ->to('#delete_template')           ->name('zone_template_delete');
  $manager->get('/templates')                               ->to('#templates')                 ->name('zone_templates');
  $manager->post('/templates')                              ->to('#create_template')           ->name('zone_template_create');
  # Zone routes
  $manager->get('/#zone_id/edit')                           ->to('#edit_zone')          ->name('zone_edit');
  $manager->get('/#zone_id/export')                         ->to('#export_zone')        ->name('zone_export');
  $manager->get('/new')                                     ->to('#new_zone')           ->name('zone_new');
  $manager->get('/import')                                  ->to('#import_zone_form')   ->name('zone_import_form');
  $manager->post('/import')                                 ->to('#import_zone')        ->name('zone_import');
  $manager->patch('/#zone_id')                              ->to('#update_zone')        ->name('zone_update');
  $manager->delete('/#zone_id')                             ->to('#delete_zone')        ->name('zone_delete');
  $manager->post('/')                                       ->to('#create_zone')        ->name('zone_create');
  $manager->get('/')                                        ->to('#index')              ->name('zone_index');

  # Customer specific zone routes
  my $customer = $r->manager('customers/:customerid/zones')->to(controller => 'Zone');
  $customer->get('/')                                      ->to('#index')              ->name('customer_zones');

  # Helper for PowerDNS database connection
  $app->helper(pdns => sub($c) {
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
      pdns   => $c->pdns,   # PowerDNS database
      pg     => $c->pg,     # Main Samizdat database (for templates)
    });
    return $model;
  });
}


1;
