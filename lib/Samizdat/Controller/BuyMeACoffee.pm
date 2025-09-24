package Samizdat::Controller::BuyMeACoffee;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::JSON qw(decode_json);
use Data::Dumper;

sub webhook ($self) {
  my $body = $self->req->body;
  my $signature = $self->req->headers->header('x-signature-sha256');

  # Use the model to verify signature
  unless ($self->buymeacoffee->verify_webhook_signature($body, $signature)) {
    $self->app->log->warn('Invalid Buy Me a Coffee webhook signature');
    return $self->render(json => {error => 'Invalid signature'}, status => 401);
  }

  # Parse webhook data
  my $data = decode_json($body);

  # Debug logging
  $self->app->log->debug("Buy Me a Coffee webhook received: " . Dumper($data)) if $self->app->mode eq 'development';

  # Process webhook through model
  my $result = $self->buymeacoffee->process_webhook($data);

  # Log the result
  $self->app->log->info("Buy Me a Coffee webhook processed: $result->{type} - action: $result->{action}");

  # Store event for audit trail if database is available
  $self->buymeacoffee->store_webhook_event($data);

  # Trigger a full refresh to get accurate count
  $self->_refresh_supporter_count;

  $self->render(json => {success => 1, result => $result});
}

sub _refresh_supporter_count ($self) {
  # Run the fetch command in the background
  system("script/samizdat fetchbuymeacoffee &");
}

1;

=head1 NAME

Samizdat::Controller::BuyMeACoffee - Buy Me a Coffee webhook controller

=head1 SYNOPSIS

  # Routes are set up by the plugin
  $r->home('/buymeacoffee/webhook')->to('buy_me_a_coffee#webhook');

=head1 DESCRIPTION

This controller handles Buy Me a Coffee webhook events, verifying signatures
and updating supporter counts through the model.

=head1 METHODS

=head2 webhook

Processes incoming webhook requests from Buy Me a Coffee, verifying the
signature and updating supporter counts accordingly.

=cut