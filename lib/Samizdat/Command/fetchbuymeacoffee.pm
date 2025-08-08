package Samizdat::Command::fetchbuymeacoffee;

use Mojo::Base 'Mojolicious::Command';
use Mojo::UserAgent;

# Add a cron job to run this command every hour
# Not neded if we use the webhook
# 0 * * * * cd /path/to/samizdat && script/samizdat fetchbuymeacoffee

has description => 'Fetch Buy Me a Coffee supporter count';
has usage => sub { shift->extract_usage };

sub run ($self, @args) {
  my $app = $self->app;
  my $slug = $app->config->{buymeacoffee}->{slug};
  
  unless ($slug) {
    say "No Buy Me a Coffee slug configured";
    return;
  }
  
  my $ua = Mojo::UserAgent->new;
  my $url = "https://www.buymeacoffee.com/$slug";
  
  say "Fetching supporter count for $slug...";
  
  my $tx = $ua->get($url);
  
  if ($tx->success) {
    my $html = $tx->res->body;
    my $supporters = 0;
    
    # Try multiple patterns to find supporter count
    if ($html =~ /(\d+)\s*(?:supporters?|members?)/i) {
      $supporters = $1;
    } elsif ($html =~ /"supporters":\s*(\d+)/i) {
      $supporters = $1;
    } elsif ($html =~ /data-supporters=["'](\d+)["']/i) {
      $supporters = $1;
    }
    
    # Store in Redis with 24 hour expiry
    my $cache_key = "buymeacoffee:supporters:$slug";
    $app->redis->db->set($cache_key => $supporters);
    $app->redis->db->expire($cache_key => 86400);
    
    # Also store in a file as backup
    my $cache_file = "/tmp/buymeacoffee_$slug.txt";
    Mojo::File->new($cache_file)->spurt($supporters);
    
    say "Supporter count: $supporters (cached)";
  } else {
    my $err = $tx->error;
    say "Failed to fetch: $err->{code} $err->{message}" if $err->{code};
    say "Connection error: $err->{message}" if !$err->{code};
  }
}

=encoding utf8

=head1 NAME

Samizdat::Command::fetchbuymeacoffee - Fetch Buy Me a Coffee supporter count

=head1 SYNOPSIS

  Usage: APPLICATION fetchbuymeacoffee

    script/samizdat fetchbuymeacoffee

=head1 DESCRIPTION

L<Samizdat::Command::fetchbuymeacoffee> fetches the current supporter count
from Buy Me a Coffee and caches it locally.

=head1 ATTRIBUTES

=head2 description

  my $description = $fetch->description;
  $fetch = $fetch->description('Foo');

Short description of this command, used for the command list.

=head2 usage

  my $usage = $fetch->usage;
  $fetch = $fetch->usage('Foo');

Usage information for this command, used for the help screen.

=cut

1;