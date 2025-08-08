package Samizdat::Controller::BuyMeACoffee;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::JSON qw(decode_json);
use Digest::SHA qw(hmac_sha256_hex);
use Data::Dumper;

sub webhook ($self) {
  my $body = $self->req->body;
  my $signature = $self->req->headers->header('X-BMC-Signature');
  
  # Get webhook secret from config
  my $secret = $self->config->{buymeacoffee}->{webhook_secret};
  
  unless ($secret) {
    $self->app->log->error('Buy Me a Coffee webhook secret not configured');
    return $self->render(json => {error => 'Configuration error'}, status => 500);
  }
  
  # Verify webhook signature
  my $expected_signature = hmac_sha256_hex($body, $secret);
  
  unless ($signature && $signature eq $expected_signature) {
    $self->app->log->warn('Invalid Buy Me a Coffee webhook signature');
    return $self->render(json => {error => 'Invalid signature'}, status => 401);
  }
  
  # Parse webhook data
  my $data = decode_json($body);
  say Dumper($data);

  # Log the event
  $self->app->log->info("Buy Me a Coffee webhook: $data->{type}");
  
  # Update supporter count based on event type
  if ($data->{type} =~ /^(donation\.created|membership\.started)$/) {
    $self->_increment_supporters;
  } elsif ($data->{type} eq 'membership.cancelled') {
    $self->_decrement_supporters;
  }
  
  # Trigger a full refresh to get accurate count
  $self->_refresh_supporter_count;
  
  $self->render(json => {success => 1});
}

sub _increment_supporters ($self) {
  my $slug = $self->config->{buymeacoffee}->{slug};
  my $cache_key = "buymeacoffee:supporters:$slug";
  
  my $current = $self->app->redis->db->get($cache_key) || 0;
  $self->app->redis->db->set($cache_key => $current + 1);
  $self->app->redis->db->expire($cache_key => 86400);
}

sub _decrement_supporters ($self) {
  my $slug = $self->config->{buymeacoffee}->{slug};
  my $cache_key = "buymeacoffee:supporters:$slug";
  
  my $current = $self->app->redis->db->get($cache_key) || 0;
  $current = $current - 1 if $current > 0;
  $self->app->redis->db->set($cache_key => $current);
  $self->app->redis->db->expire($cache_key => 86400);
}

sub _refresh_supporter_count ($self) {
  # Run the fetch command in the background
  system("script/samizdat fetchbuymeacoffee &");
}

1;