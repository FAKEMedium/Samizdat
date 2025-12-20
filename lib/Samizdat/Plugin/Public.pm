package Samizdat::Plugin::Public;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Public;
use Mojo::Home;
use Mojo::JSON qw(decode_json encode_json);
use Data::Dumper;

my $countriesrepo = Mojo::Home->new('src/countries-data-json/data/');

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  $r->get('/country')->to(controller => 'Public', action => 'countries');
  $r->get('/country/#country')->to(controller => 'Public', action => 'country');

  # Store some data in the app
  $app->{countries} = { translations => {}, countrydata => {}, reverse => {} };
  for my $lang (sort {$a cmp $b} keys %{ $app->config->{locale}->{languages} }) {
    $app->{countries}->{translations}->{$lang} = decode_json(
      $countriesrepo->child(sprintf('translations/countries-%s.json', lc $lang))->slurp
    );
    for my $cc (keys %{$app->{countries}->{translations}->{$lang}}) {
      my $name = $app->{countries}->{translations}->{$lang}->{$cc};
      my $search = lc $name;
      $search =~ s/[^a-z]+//g;
      $app->{countries}->{reverse}->{$lang}->{$search} = $cc;
    }
  }


  $app->helper(
    countrylist => sub($c, $options = {}) {
      my $lang = $options->{language} // $app->language;
      return $app->{countries}->{translations}->{$lang} // eval {
        return $app->{countries}->{translations}->{$lang} = decode_json(
          $countriesrepo->child(sprintf('translations/countries-%s.json', lc $lang))->slurp
        );
      };
    }
  );


  $app->helper(
    country => sub($c, $cc, $options =  {}) {
      $cc = uc($cc);
      return $app->{countries}->{countrydata}->{$cc} // eval {
        $app->{countries}->{countrydata}->{$cc} = decode_json($countriesrepo->child(
          sprintf('countries/%s.json', $cc)
        )->slurp);
      };
    }
  );


  $app->helper(public => sub {
    state $model = Samizdat::Model::Public->new(pg => $app->pg);
    return $model;
  });

  # Helper to get languages hash (code => languageid mapping)
  # Cached in state for performance
  $app->helper(languages => sub ($c) {
    state $languages = $c->public->languages();
    return $languages;
  });

  # Helper to get pagination items per page
  # Checks: 1) session, 2) config, 3) default (10)
  # This allows user preferences to be added later via session
  $app->helper(perpage => sub ($c) {
    return $c->session('perpage')
        // $app->config->{pagination}->{perpage}
        // 10;
  });

}

=head1 NAME

Samizdat::Plugin::Public - Public data helpers and country information

=head1 SYNOPSIS

  # In your application
  $app->plugin('Public');

  # Use helpers in controllers/templates
  my $countries = $c->countrylist();
  my $sweden = $c->country('SE');
  my $items = $c->perpage;

=head1 DESCRIPTION

This plugin provides public data helpers including country information,
language mappings, and pagination settings. It loads country data from
JSON files and caches translations for all configured languages.

=head1 NGINX CONFIGURATION

Samizdat is designed to work with Nginx (or OpenResty) as a reverse proxy
with static file caching. The application generates static HTML files that
Nginx serves directly, bypassing the Perl application for improved performance.

=head2 Static Cache Architecture

The L<Samizdat::Plugin::Web> C<after_render> hook automatically:

=over 4

=item * Saves rendered HTML to C<public/> directory

=item * Creates gzip-compressed versions (C<.gz>) for C<gzip_static>

=item * Creates Brotli-compressed versions (C<.br>) for C<brotli_static>

=back

=head2 Recommended Nginx Configuration

  server {
      listen 443 ssl http2;
      server_name example.com;
      root /path/to/samizdat/public;

      # Enable static compression modules
      gzip_static on;
      brotli_static on;

      # Try static files first, then proxy to application
      location / {
          try_files $uri $uri/index.html @app;
      }

      # API routes always go to application
      location /api/ {
          proxy_pass http://127.0.0.1:3000;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
      }

      # Manager routes require authentication
      location /manager/ {
          proxy_pass http://127.0.0.1:3000;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
      }

      # Fallback to application
      location @app {
          proxy_pass http://127.0.0.1:3000;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
      }
  }

=head2 OpenResty Extensions

For OpenResty, Lua scripts can be used for:

=over 4

=item * Session validation via Redis (C<access_by_lua_block>)

=item * Injecting user data into cookies

=item * Rate limiting and request filtering

=item * Direct database queries for simple REST endpoints

=back

Example access control:

  location /manager/ {
      access_by_lua_block {
          local redis = require "resty.redis"
          local red = redis:new()
          red:connect("127.0.0.1", 6379)
          local session = ngx.var.cookie_session
          if not session or not red:get("session:" .. session) then
              ngx.exit(ngx.HTTP_UNAUTHORIZED)
          end
      }
      proxy_pass http://127.0.0.1:3000;
  }

=head1 HELPERS

=head2 countrylist

  my $countries = $c->countrylist();
  my $countries = $c->countrylist({ language => 'sv' });

Returns a hashref of country codes to localized country names.

=head2 country

  my $data = $c->country('SE');

Returns detailed country data including name, capital, currencies, etc.

=head2 public

  my $model = $c->public;

Returns the L<Samizdat::Model::Public> instance.

=head2 languages

  my $langs = $c->languages;

Returns cached language code to ID mappings from the database.

=head2 perpage

  my $items = $c->perpage;

Returns pagination items per page from session, config, or default (10).

=head1 SEE ALSO

L<Samizdat::Plugin::Web> - Static cache generation

L<Samizdat::Model::Public> - Public data model

=cut

1;