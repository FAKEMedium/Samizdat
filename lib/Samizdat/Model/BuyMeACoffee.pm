package Samizdat::Model::BuyMeACoffee;

use Mojo::Base -base, -signatures;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json);
use Mojo::File;
use Digest::SHA qw(hmac_sha256_hex);

has 'config';
has 'redis';
has 'pg';
has 'ua' => sub {
  my $ua = Mojo::UserAgent->new;
  $ua->max_redirects(5);
  $ua->request_timeout(30);
  # Set a browser-like user agent to avoid being blocked
  $ua->transactor->name('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
  return $ua;
};


sub get_supporters ($self) {
  my $slug = $self->config->{slug};
  return 0 unless $slug;

  # Try Redis first
  my $cache_key = "buymeacoffee:supporters:$slug";
  my $supporters = $self->redis->db->get($cache_key) if $self->redis;

  # Fall back to file cache if Redis fails
  if (!defined $supporters) {
    my $cache_file = "/tmp/buymeacoffee_$slug.txt";
    if (-f $cache_file) {
      $supporters = Mojo::File->new($cache_file)->slurp;
      chomp $supporters if defined $supporters;
    }
  }

  return $supporters // 0;
}


sub fetch_supporters ($self) {
  my $slug = $self->config->{slug};
  return 0 unless $slug;

  my $url = "https://www.buymeacoffee.com/$slug";
  my $tx = $self->ua->get($url);

  if ($tx->result->is_success) {
    my $html = $tx->result->body;
    my $count = 0;

    # Try multiple patterns to find supporter count
    # BMC uses different formats depending on the page
    if ($html =~ /(\d+)\s*(?:supporters?|members?)/i) {
      $count = $1;
    } elsif ($html =~ /"supporters":\s*(\d+)/i) {
      $count = $1;
    } elsif ($html =~ /data-supporters=["'](\d+)["']/i) {
      $count = $1;
    } elsif ($html =~ />(\d+)<\/.*?supporters?/si) {
      $count = $1;
    }

    # Cache in Redis if available
    if ($self->redis) {
      my $cache_key = "buymeacoffee:supporters:$slug";
      $self->redis->db->set($cache_key => $count);
      $self->redis->db->expire($cache_key => 86400); # 24 hours
    }

    # Also cache in file as fallback
    my $cache_file = "/tmp/buymeacoffee_$slug.txt";
    Mojo::File->new($cache_file)->spurt($count);

    return $count;
  } else {
    # Log error for debugging
    my $err = $tx->result->error;
    warn "Failed to fetch BMC page: " . ($err->{message} // 'Unknown error');
  }

  return 0;
}


sub increment_supporters ($self) {
  my $slug = $self->config->{slug};
  return unless $slug && $self->redis;

  my $cache_key = "buymeacoffee:supporters:$slug";

  my $current = $self->redis->db->get($cache_key) || 0;
  $self->redis->db->set($cache_key => $current + 1);
  $self->redis->db->expire($cache_key => 86400);

  # Update file cache too
  my $cache_file = "/tmp/buymeacoffee_$slug.txt";
  Mojo::File->new($cache_file)->spurt($current + 1);

  return $current + 1;
}


sub decrement_supporters ($self) {
  my $slug = $self->config->{slug};
  return unless $slug && $self->redis;

  my $cache_key = "buymeacoffee:supporters:$slug";

  my $current = $self->redis->db->get($cache_key) || 0;
  $current = $current - 1 if $current > 0;

  $self->redis->db->set($cache_key => $current);
  $self->redis->db->expire($cache_key => 86400);

  # Update file cache too
  my $cache_file = "/tmp/buymeacoffee_$slug.txt";
  Mojo::File->new($cache_file)->spurt($current);

  return $current;
}


sub verify_webhook_signature ($self, $body, $signature) {
  my $secret = $self->config->{webhook_secret} // $self->config->{webhook}->{secret};

  return 0 unless $secret && $signature;

  my $expected_signature = hmac_sha256_hex($body, $secret);

  return $signature eq $expected_signature;
}


sub process_webhook ($self, $data) {
  return unless $data && ref($data) eq 'HASH';

  # Process based on event type
  if ($data->{type} =~ /^(donation\.created|membership\.started)$/) {
    $self->increment_supporters;
    return {action => 'incremented', type => $data->{type}};
  } elsif ($data->{type} eq 'membership.cancelled') {
    $self->decrement_supporters;
    return {action => 'decremented', type => $data->{type}};
  }

  return {action => 'none', type => $data->{type}};
}


sub store_webhook_event ($self, $data) {
  return unless $self->pg && $data;

  # Store webhook events in database for audit trail
  eval {
    $self->pg->db->insert('buymeacoffee_events', {
      event_type => $data->{type},
      data => decode_json($data),
      created_at => \'NOW()',
    });
  };
}

1;

=head1 NAME

Samizdat::Model::BuyMeACoffee - Buy Me a Coffee integration model

=head1 SYNOPSIS

  use Samizdat::Model::BuyMeACoffee;

  my $bmc = Samizdat::Model::BuyMeACoffee->new({
    config => $config->{buymeacoffee},
    redis  => $redis,
    pg     => $pg,
  });

  my $count = $bmc->get_supporters;
  my $fresh_count = $bmc->fetch_supporters;

  # Process webhook
  if ($bmc->verify_webhook_signature($body, $signature)) {
    my $result = $bmc->process_webhook($data);
  }

=head1 DESCRIPTION

This model handles Buy Me a Coffee integration including:

=over 4

=item * Fetching and caching supporter counts

=item * Processing webhook events

=item * Verifying webhook signatures

=item * Managing supporter count increments/decrements

=back

=head1 METHODS

=head2 get_supporters

Returns the cached supporter count from Redis or file cache.

=head2 fetch_supporters

Fetches fresh supporter count from Buy Me a Coffee website.

=head2 increment_supporters

Increments the cached supporter count.

=head2 decrement_supporters

Decrements the cached supporter count.

=head2 verify_webhook_signature

Verifies the HMAC SHA256 signature of a webhook request.

=head2 process_webhook

Processes webhook data and updates supporter count accordingly.

=head2 store_webhook_event

Stores webhook event in database for audit trail.

=cut