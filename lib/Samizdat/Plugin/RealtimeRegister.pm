package Samizdat::Plugin::RealtimeRegister;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::RealtimeRegister;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  # Manager routes for domain and contact management
  my $manager = $r->manager('realtimeregister')->to(controller => 'RealtimeRegister');

  # Domain routes
  $manager->get('domains')                  ->to('#domains')          ->name('rtr_domains');
  $manager->get('domains/:domain')          ->to('#domain')           ->name('rtr_domain');
  $manager->post('domains')                 ->to('#create_domain')    ->name('rtr_create_domain');
  $manager->put('domains/:domain')          ->to('#update_domain')    ->name('rtr_update_domain');
  $manager->delete('domains/:domain')       ->to('#delete_domain')    ->name('rtr_delete_domain');

  # Contact routes
  $manager->get('contacts')                 ->to('#contacts')         ->name('rtr_contacts');
  $manager->get('contacts/:handle')         ->to('#contact')          ->name('rtr_contact');
  $manager->post('contacts')                ->to('#create_contact')   ->name('rtr_create_contact');
  $manager->put('contacts/:handle')         ->to('#update_contact')   ->name('rtr_update_contact');
  $manager->delete('contacts/:handle')      ->to('#delete_contact')   ->name('rtr_delete_contact');

  # Main page
  $manager->any('/')                        ->to('#index')            ->name('rtr_index');

  # Helper for accessing the RealtimeRegister API model
  $app->helper(realtimeregister => sub ($c) {
    state $model = Samizdat::Model::RealtimeRegister->new({
      config => $app->config->{manager}->{realtimeregister},
    });
    return $model;
  });
}

1;

=head1 NAME

Samizdat::Plugin::RealtimeRegister - RealtimeRegister API plugin

=head1 DESCRIPTION

This plugin provides RealtimeRegister domain registrar integration for Samizdat.
It includes routes for managing domains and contacts, plus a helper for API access.

=head1 ROUTES

All routes require admin access.

=head2 Domain Routes

=over 4

=item GET /manager/realtimeregister/domains

List all domains

=item GET /manager/realtimeregister/domains/:domain

Get specific domain details

=item POST /manager/realtimeregister/domains

Register a new domain

=item PUT /manager/realtimeregister/domains/:domain

Update domain information

=item DELETE /manager/realtimeregister/domains/:domain

Delete/cancel a domain

=back

=head2 Contact Routes

=over 4

=item GET /manager/realtimeregister/contacts

List all contacts

=item GET /manager/realtimeregister/contacts/:handle

Get specific contact details

=item POST /manager/realtimeregister/contacts

Create a new contact

=item PUT /manager/realtimeregister/contacts/:handle

Update contact information

=item DELETE /manager/realtimeregister/contacts/:handle

Delete a contact

=back

=head1 HELPERS

=head2 realtimeregister

  my $rtr = $c->realtimeregister;
  my $domains = $rtr->getDomains();

Returns the RealtimeRegister model instance for API operations.

=cut
