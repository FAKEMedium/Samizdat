package Samizdat::Plugin::BIS;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::BIS;

sub register ($self, $app, $config = {}) {

  my $r = $app->routes;

  # Public routes (for public dashboard)
  my $bis = $r->home('bis')->to(controller => 'BIS');
  $bis->get('/domain/#domain')            ->to('#domain')               ->name('bis_domain');
  $bis->get('/sector/#sector')            ->to('#sector')               ->name('bis_sector');
  $bis->get('/providers')                 ->to('#providers')            ->name('bis_providers');
  $bis->get('/trends')                    ->to('#trends')               ->name('bis_trends');
  $bis->get('/')                          ->to('#index')                ->name('bis_index');

  # Manager routes
  my $manager = $r->manager('bis')->to(controller => 'BIS');
  $manager->put('/domains/#id')           ->to('#update_domain')        ->name('bis_update_domain');
  $manager->delete('/domains/#id')        ->to('#delete_domain')        ->name('bis_delete_domain');
  $manager->post('/runs/:id/check')       ->to('#check_run')            ->name('bis_check_run');
  $manager->post('/runs/start')           ->to('#start_run')            ->name('bis_start_run');
  $manager->get('/domains')               ->to('#domains')              ->name('bis_domains');
  $manager->post('/domains')              ->to('#add_domain')           ->name('bis_add_domain');
  $manager->get('/tags')                  ->to('#tags')                 ->name('bis_tags');
  $manager->post('/tags')                 ->to('#add_tag')              ->name('bis_add_tag');
  $manager->get('/runs')                  ->to('#runs')                 ->name('bis_runs');
  $manager->get('/providers')             ->to('#manage_providers')     ->name('bis_manage_providers');
  $manager->post('/providers')            ->to('#add_provider')         ->name('bis_add_provider');
  $manager->get('/')                      ->to('#manager')              ->name('bis_manager');


  # Register model helper
  $app->helper(bis => sub ($c) {
    state $model = Samizdat::Model::BIS->new({
      config => $c->config->{manager}->{bis},
      redis  => $c->app->redis,
      pg     => $c->app->pg,
    });
    return $model;
  });

}

1;

=head1 NAME

Samizdat::Plugin::BIS - Based in Sweden compliance tracking plugin

=head1 SYNOPSIS

  # In your application
  $app->plugin('BIS');

  # Use the helper
  my $bis = $c->bis;

  # Add a domain to track
  my $domain_id = $bis->add_domain(
    domain => 'example.se',
    title => 'Example Organization',
    tags => ['government']
  );

=head1 DESCRIPTION

This plugin integrates BIS (Based in Sweden) functionality into Samizdat, including:

=over 4

=item * DNS record checking (A, AAAA, MX, NS)

=item * IP geolocation and ASN lookup

=item * Hosting provider identification

=item * Compliance scoring and tracking

=item * Public dashboard for viewing compliance status

=item * Manager interface for administering tracked domains

=item * Historical trend analysis

=back

=head1 ROUTES

The plugin registers the following routes:

=head2 Public Routes

=over 4

=item * GET /bis - Public dashboard showing all domains

=item * GET /bis/domain/:domain - Details for a specific domain

=item * GET /bis/sector/:sector - View by sector (e.g., healthcare, government)

=item * GET /bis/providers - Hosting provider statistics

=item * GET /bis/trends - Historical compliance trends

=back

=head2 Manager Routes

=over 4

=item * GET /manager/bis - Main management panel

=item * GET /manager/bis/domains - List all tracked domains

=item * POST /manager/bis/domains - Add new domain

=item * PUT /manager/bis/domains/:id - Update domain

=item * DELETE /manager/bis/domains/:id - Delete domain

=item * GET /manager/bis/tags - Manage tags

=item * POST /manager/bis/tags - Add new tag

=item * GET /manager/bis/runs - View check runs

=item * POST /manager/bis/runs/start - Start new check run

=item * POST /manager/bis/runs/:id/check - Check all domains in run

=item * GET /manager/bis/providers - Manage provider database

=item * POST /manager/bis/providers - Add new provider

=back

=head1 HELPERS

=head2 bis

Returns the L<Samizdat::Model::BIS> instance.

  my $bis = $c->bis;
  my $domain_id = $bis->add_domain(domain => 'example.se');

=head1 CONFIGURATION

Configure in samizdat.yml under manager.bis:

  bis:
    cardnumber: 17
    dbtype: postgresql

=head1 SEE ALSO

L<Samizdat::Model::BIS>, L<Samizdat::Controller::BIS>

Based in Sweden initiative: L<https://basedinsweden.se/>

=cut
