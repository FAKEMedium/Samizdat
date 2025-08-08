package Samizdat::Plugin::BuyMeACoffee;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json);

sub register ($self, $app, $config = {}) {
  
  # Add webhook route
  my $r = $app->routes;
  $r->post(sprintf('/buymeacoffee/%s', $app->config->{buymeacoffee}->{webhook}))->to('buy_me_a_coffee#webhook');
  
  # Add helper to get cached supporter count
  $app->helper('buymeacoffee.supporters' => sub ($c) {
    my $cache_key = 'buymeacoffee:supporters:' . $c->config->{buymeacoffee}->{slug};
    
    # Try to get from cache first
    my $supporters = $c->redis->get($cache_key);
    
    if (!defined $supporters) {
      # Fetch from API if not in cache
      $supporters = $self->_fetch_supporters($c);
      
      # Cache for 1 hour
      if (defined $supporters) {
        $c->redis->set($cache_key => $supporters);
        $c->redis->expire($cache_key => 3600);
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