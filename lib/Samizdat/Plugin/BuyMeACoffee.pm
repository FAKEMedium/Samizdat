package Samizdat::Plugin::BuyMeACoffee;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json);

sub register ($self, $app, $config = {}) {
  
  # Add webhook route
  my $r = $app->routes;
  $r->post(sprintf('/buymeacoffee/%s', $app->config->{buymeacoffee}->{webhook}))->to('buy_me_a_coffee#webhook');


  # Add helper to get cached supporter count with Redis and file fallback
  $app->helper('buymeacoffee_supporters' => sub ($c) {
    my $slug = $app->config->{buymeacoffee}->{slug};
    return 0 unless $slug;
    
    # Try Redis first
    my $cache_key = "buymeacoffee:supporters:$slug";
    my $supporters = $app->redis->db->get($cache_key);
    
    # Fall back to file cache if Redis fails
    if (!defined $supporters) {
      my $cache_file = "/tmp/buymeacoffee_$slug.txt";
      if (-f $cache_file) {
        $supporters = Mojo::File->new($cache_file)->slurp;
        chomp $supporters if defined $supporters;
      }
    }
    
    return $supporters // 0;
  });
}

sub _fetch_supporters ($self, $c) {
  my $slug = $c->config->{buymeacoffee}->{slug};
  return 0 unless $slug;
  
  my $ua = Mojo::UserAgent->new;
  my $url = "https://www.buymeacoffee.com/$slug";
  
  eval {
    my $tx = $ua->get($url);
    if ($tx->success) {
      my $html = $tx->res->body;
      
      # Extract supporter count from the page
      # This regex might need adjustment based on BMC's HTML structure
      if ($html =~ /(\d+)\s*(?:supporters?|members?)/i) {
        return $1;
      }
    }
  };
  
  return 0;
}

1;