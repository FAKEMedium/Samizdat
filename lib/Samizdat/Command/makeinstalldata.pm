package Samizdat::Command::makeinstalldata;

use Mojo::Base 'Mojolicious::Command', -signatures;
use Mojo::Home;
use Mojo::JSON qw(decode_json encode_json from_json);
use Mojo::DOM;

use Data::Dumper;

has description => 'Import data from some open sources into Postgresql data base.';
has usage => sub ($self) { $self->extract_usage };

my $languagesrepo = Mojo::Home->new('src/i18n-iso-languages/');
my $countriesrepo = Mojo::Home->new('src/countries-data-json/');
my $flagsrepo = Mojo::Home->new('src/flag-icons/');

my $xml = Mojo::DOM->new->xml(1);

sub run ($self, @args) {
  my $db = $self->app->pg->db;

  say "Be patient. Importing data may take many minutes.";
  my $languages = {};
  $languagesrepo->child('langs')->list->each(sub($file, $num) {
    my $lang = decode_json $file->slurp;
    $languages->{ $lang->{locale} } = $lang->{languages};
  });

  say "Importing language codes...";
  # English (en) is always first
  my $languagecodes = { 'en' => 1 };
  my $i = 1;
  for my $lang (sort {$a cmp $b} keys %{$self->app->config->{locale}->{languages}}) {
    if (!exists($languagecodes->{$lang})) {
      eval {
        my $tx = $db->begin;
        $db->query('INSERT INTO languages (languageid, code) VALUES (?, ?);', $i + 1, $lang);
        $tx->commit;
      };
      if ($@) {
        say $@;
      } else {
        $i++;
        $languagecodes->{$lang} = $i;
      }
    }
  }
  for my $lang (sort {$a cmp $b} keys %{$languages->{en}}) {
    if (!exists($languagecodes->{$lang})) {
      eval {
        my $tx = $db->begin;
        $db->query('INSERT INTO languages (languageid, code) VALUES (?, ?);', $i + 1, $lang);
        $tx->commit;
      };
      if ($@) {
        say $@;
      } else {
        $i++;
        $languagecodes->{$lang} = $i;
      }
    }
  }

  say "Importing translations of languages...";
  # English is always first, already inserted
  $i = 1;
  my $translations = { 'en' => $i };

  for my $lang (sort {$a cmp $b} keys %{$self->app->config->{locale}->{languages}}) {
    if (!exists($translations->{$lang})) {
      eval {
        my $tx = $db->begin;
        $db->query('INSERT INTO languagenames (languagenameid, languagename, languageid, language) VALUES (?, ?, ?, ?);',
          $i + 1, $languages->{en}->{$lang}, $languagecodes->{$lang}, $languagecodes->{en});
        $tx->commit;
      };
      if ($@) {
        say $@;
      } else {
        $i++;
        $translations->{$lang} = $i;
      }
    }
  }

  for my $lang (sort {$a cmp $b} keys %{$languages->{en}}) {
    if (!exists($translations->{$lang})) {
      eval {
        my $tx = $db->begin;
        $db->query('INSERT INTO languagenames (languagenameid, languagename, languageid, language) VALUES (?, ?, ?, ?);',
          $i + 1, $languages->{en}->{$lang}, $languagecodes->{$lang}, $languagecodes->{en});
        $tx->commit;
      };
      if ($@) {
        say $@;
      } else {
        $i++;
        $translations->{$lang} = $i;
      }
    }
  }

  for my $translation (sort {$a cmp $b} keys %{$languages}) {
    next if ('en' eq $translation);
    $translations = {};
    for my $lang (sort {$a cmp $b} keys %{$languages->{$translation}}) {
      if (!exists($translations->{$lang})) {
        eval {
          my $tx = $db->begin;
          $db->query('INSERT INTO languagenames (languagenameid, languagename, languageid, language) VALUES (?, ?, ?, ?);',
            $i + 1, $languages->{$translation}->{$lang}, $languagecodes->{$lang}, $languagecodes->{$translation});
          $tx->commit;
        };
        if ($@) {
          say $@;
        } else {
          $i++;
          $translations->{$lang} = $i;
        }
      }
    }
  }

  my $countries = {};
  my $currencies = {};
  my $j = 1;
  $i = 1;

  say "Inserting continents...";
  my $continents = {
    'Europe'        => 1,
    'Asia'          => 2,
    'Africa'        => 3,
    'North America' => 4,
    'South America' => 5,
    'Australia'     => 6,
    'Antarctica'    => 7,
  };
  for my $continent (sort {$continents->{$a} <=> $continents->{$b}} keys %$continents) {
    $db->query('INSERT INTO continents (continentid, continent, code) VALUES (?, ?, ?)', $continents->{$continent}, $continent, '');
  }

  say "Importing countries and currency codes...";
  $countriesrepo->child('/data/countries/')->list->each(sub($file, $num) {
    my $country = decode_json $file->slurp;
    my $cc = '';
    if ($file =~ /([A-Z]{2})\.json$/) {
      $cc = $1;
      $country = $country->{$cc};
    } else {
      die "No country code";
    }
    # Add a default guess of format
    if (!exists($country->{address_format})) {
      $country->{address_format} = "{{recipient}}\n{{street}}\n{{postalcode}} {{city}}\n{{country}}";
    }
    if (!exists($country->{postal_code_format})) {
      $country->{postal_code_format} = '';
    }
    if (!exists($currencies->{$country->{currency_code}})) {
      eval {
        my $tx = $db->begin;
        $db->query('INSERT INTO currencies (currencyid, symbol) VALUES (?, ?)', $j, $country->{currency_code});
        $tx->commit;
      };
      if ($@) {
        die $@;
      } else {
        $currencies->{$country->{currency_code}} = $j;
        $j++;
      }
    }
    eval {
      my $tx = $db->begin;
      $db->query('INSERT INTO countries
          (countryid, continentid, currencyid, cc, pcformat, addressformat, geonameid, phone, start_of_week, tld)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        $i, $continents->{$country->{continent}}, $currencies->{$country->{currency_code}}, $cc,
        $country->{postal_code_format}, $country->{address_format}, $country->{number},
        $country->{country_code}, $country->{start_of_week}, lc $cc
      );
      $tx->commit;
    };
    if ($@) {
      die $@;
    } else {
      $countries->{$cc} = $i;
      $i++;
    }
  });

  say "Adding svg country flags...";
  $flagsrepo->child('flags/4x3/')->list->each(sub($file, $num) {
    if ($file =~ /([a-z]+)\.svg/) {
      my $cc = uc $1;
      my $svg = $file->slurp;
      $xml->parse($svg);
#      $svg = $xml->at('svg')->content;
      $svg = $xml->content;
      $svg =~ s/[\r\n]+//gms;
      $svg =~ s/[\t]+//gms;
      $svg =~ s/[\s]{2,}//gms;
      if (exists($countries->{$cc})) {
        $db->query('UPDATE countries SET svgflag = ? WHERE countryid = ?', $svg, $countries->{$cc});
      }
    }
  });

  say "Importing country names (slow)...";
  $i = 1;
  $countriesrepo->child('/data/translations/')->list->each(sub($file, $num) {
    if ($file =~ /countries\-([a-zA-Z]+)\.json/) {
      my $lang = $1;
      $lang = 'zh' if ($lang eq 'zh_CN');
      if (exists($languagecodes->{$lang})) {
        my $countrynames = decode_json $file->slurp;
        for my $cc (sort {$a cmp $b} keys %$countrynames) {
          if (exists($countries->{$cc})) {
            eval {
              my $tx = $db->begin;
              $db->query('INSERT INTO countrynames (countrynameid, countryname, languageid, countryid) VALUES (?, ?, ?, ?)',
                $i, $countrynames->{$cc}, $languagecodes->{$lang}, $countries->{$cc}
              );
              $tx->commit;
            };
            if ($@) {
              die $@;
            } else {
              $i++;
            }
          }
        }
      }
    }
  });

  say "Importing regions and translations (slow)...";
  $j = 1;
  $i = 1;
  $countriesrepo->child('/data/subdivisions/')->list->each( sub($file, $num) {
    if ($file =~ /([A-Z]{2})\.json/) {
      my $cc = $1;
      if (exists($countries->{$cc})) {
        my $divisions = decode_json $file->slurp;
        for my $division (sort {$a cmp $b} keys %$divisions) {
          eval {
            my $tx = $db->begin;
            $db->query('INSERT INTO states (stateid, code, countryid, type) VALUES (?, ?, ?, ?)',
              $i, $division, $countries->{$cc}, $divisions->{$division}->{type}
            );
            $tx->commit;
          };
          if ($@) {
            die $@;
          } else {
            for my $lang (sort {$a cmp $b} keys %{$divisions->{$division}->{translations}}){
              $lang = 'zh' if ($lang eq 'zh_CN');
              if (exists($languagecodes->{$lang})) {
                eval {
                  my $tx = $db->begin;
                  $db->query('INSERT INTO statenames (statenameid, statename, stateid, languageid) VALUES (?, ?, ?, ?)',
                    $j, $divisions->{$division}->{translations}->{$lang}, $i, $languagecodes->{$lang}
                  );
                  $tx->commit;
                };
                if ($@) {
                  die $@;
                } else {
                  $j++;
                }
              }
            }
            $i++;
          }
        }
      }
    }
  });
  say "Done!";
}


1;