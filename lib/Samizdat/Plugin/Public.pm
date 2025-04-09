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
    state $public = Samizdat::Model::Public->new(pg => $app->pg);
    return $public;
  });

}


1;