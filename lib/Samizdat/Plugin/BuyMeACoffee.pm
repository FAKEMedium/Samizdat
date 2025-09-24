package Samizdat::Plugin::BuyMeACoffee;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::BuyMeACoffee;

sub register ($self, $app, $config = {}) {

  my $r = $app->routes;

  my $bmc = $r->home('/buymeacoffee')->to(controller => 'BuyMeACoffee');

  # Add webhook route
  $bmc->any($app->config->{buymeacoffee}->{webhook}->{url})
    ->to('#webhook')
    ->name('buymeacoffee_webhook');

  # Register model helper following the established pattern
  $app->helper(buymeacoffee => sub ($c) {
    state $bmc = Samizdat::Model::BuyMeACoffee->new({
      config => $c->config->{buymeacoffee},
      redis  => $c->app->redis,
      pg     => $c->app->pg,
    });
    return $bmc;
  });

}


1;

=head1 NAME

Samizdat::Plugin::BuyMeACoffee - Buy Me a Coffee integration plugin

=head1 SYNOPSIS

  # In your application
  $app->plugin('BuyMeACoffee');

  # Use the helper
  my $bmc = $c->buymeacoffee;
  my $supporters = $bmc->get_supporters;

=head1 DESCRIPTION

This plugin integrates Buy Me a Coffee functionality into Samizdat, including:

=over 4

=item * Webhook endpoint for processing BMC events

=item * Helper for accessing the BMC model

=back

=head1 HELPERS

=head2 buymeacoffee

Returns the L<Samizdat::Model::BuyMeACoffee> instance.

=cut