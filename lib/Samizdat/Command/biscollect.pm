package Samizdat::Command::biscollect;

use Mojo::Base 'Mojolicious::Command', -signatures;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::Util qw(html_unescape decode encode);
use utf8;
use open ':std', ':encoding(UTF-8)';
use Encode qw(decode_utf8 encode_utf8);

has description => 'Collect and translate BIS domains using AI';
has usage => sub { shift->extract_usage };

sub run ($self, @args) {
  my $app = $self->app;
  my $bis = $app->bis;
  my $config = $app->config->{manager}->{bis} || {};

  unless (@args) {
    die "Usage: samizdat biscollect <command> [options]\n\n" .
        "Commands:\n" .
        "  regions              - Collect Swedish regions\n" .
        "  municipalities       - Collect Swedish municipalities\n" .
        "  newspapers           - Collect Swedish newspapers\n" .
        "  translate <file.json> - Translate existing domains\n" .
        "  scrape <domain>      - Scrape and analyze a domain\n";
  }

  my $command = shift @args;

  if ($command eq 'regions') {
    collect_regions($self);
  }
  elsif ($command eq 'newspapers') {
    collect_newspapers($self);
  }
  elsif ($command eq 'municipalities') {
    my $scope = shift @args || 'sv';
    collect_municipalities($self, $scope);
  }
  elsif ($command eq 'translate') {
    my $file = shift @args;
    translate_domains($self, $file);
  }
  elsif ($command eq 'scrape') {
    my $domain = shift @args;
    scrape_domain($self, $domain);
  }
  else {
    die "Unknown command: $command\n";
  }
}

=head2 collect_newspapers

Collect Swedish newspapers from worldbanksinfo.

=cut

sub collect_newspapers ($self) {
  my $app = $self->app;
  my $bis = $app->bis;

  say "Collecting Swedish newspapers...";

  my $ua = Mojo::UserAgent->new;
  $ua->transactor->name('Samizdat (see fakemedium.com)');

  my $newspapers = fetch_swedish_newspapers($ua);

  say "Found " . scalar(@$newspapers) . " newspapers";

  my $imported = 0;
  my $failed = 0;

  for my $newspaper (@$newspapers) {
    eval {
      say "\nProcessing: $newspaper->{domain}";

      # Scrape the website
      my $info = scrape_and_analyze($ua, $newspaper->{domain}, $app);

      # Add domain with translations
      my $domain_id = $bis->add_domain(
        domain => $newspaper->{domain},
        tags => ['newspaper']
      );

      # Add translations
      for my $lang (qw(en sv)) {
        if ($info->{translations}->{$lang}) {
          $bis->add_domain(
            domain => $newspaper->{domain},
            title => $info->{translations}->{$lang}->{title},
            description => $info->{translations}->{$lang}->{description},
            tags => ['newspaper'],
            lang => $lang
          );
        }
      }

      say "✓ Collected: $newspaper->{domain}";
      $imported++;

      # Rate limiting
      sleep 2;
    };

    if ($@) {
      say "✗ Failed: $newspaper->{domain} - $@";
      $failed++;
    }
  }

  say "\n" . "=" x 60;
  say "Collection complete!";
  say "Collected: $imported";
  say "Failed:    $failed";
  say "=" x 60;
}

=head2 collect_regions

Collect Swedish regions from SKR.

=cut

sub collect_regions ($self) {
  my $app = $self->app;
  my $bis = $app->bis;

  say "Collecting Swedish regions...";

  my $ua = Mojo::UserAgent->new;
  $ua->transactor->name('Samizdat (see fakemedium.com)');

  my $regions = fetch_swedish_regions($ua);

  say "Found " . scalar(@$regions) . " regions";

  my $imported = 0;
  my $failed = 0;

  for my $region (@$regions) {
    eval {
      say "\nProcessing: $region->{domain}";

      # Scrape the website
      my $info = scrape_and_analyze($ua, $region->{domain}, $app);

      # Add domain with translations
      my $domain_id = $bis->add_domain(
        domain => $region->{domain},
        tags => ['region']
      );

      # Add translations
      for my $lang (qw(en sv)) {
        if ($info->{translations}->{$lang}) {
          $bis->add_domain(
            domain => $region->{domain},
            title => $info->{translations}->{$lang}->{title},
            description => $info->{translations}->{$lang}->{description},
            tags => ['region'],
            lang => $lang
          );
        }
      }

      say "✓ Collected: $region->{domain}";
      $imported++;

      # Rate limiting
      sleep 2;
    };

    if ($@) {
      say "✗ Failed: $region->{domain} - $@";
      $failed++;
    }
  }

  say "\n" . "=" x 60;
  say "Collection complete!";
  say "Collected: $imported";
  say "Failed:    $failed";
  say "=" x 60;
}

=head2 collect_municipalities

Collect Swedish municipalities from data source.

=cut

sub collect_municipalities ($self, $scope) {
  my $app = $self->app;
  my $bis = $app->bis;

  say "Collecting Swedish municipalities...";

  # Fetch municipality data from Swedish open data or Wikipedia
  my $ua = Mojo::UserAgent->new;
  $ua->transactor->name('Samizdat (see fakemedium.com)');

  # Use SCB (Statistics Sweden) municipality codes or Wikipedia data
  my $municipalities = fetch_swedish_municipalities($ua);

  say "Found " . scalar(@$municipalities) . " municipalities";

  my $imported = 0;
  my $failed = 0;

  for my $muni (@$municipalities) {
    eval {
      say "\nProcessing: $muni->{domain}";

      # Scrape the website
      my $info = scrape_and_analyze($ua, $muni->{domain}, $app);

      # Add domain with translations
      my $domain_id = $bis->add_domain(
        domain => $muni->{domain},
        tags => ['municipality']
      );

      # Add translations
      for my $lang (qw(en sv)) {
        if ($info->{translations}->{$lang}) {
          $bis->add_domain(
            domain => $muni->{domain},
            title => $info->{translations}->{$lang}->{title},
            description => $info->{translations}->{$lang}->{description},
            tags => ['municipality'],
            lang => $lang
          );
        }
      }

      say "✓ Collected: $muni->{domain}";
      $imported++;

      # Rate limiting
      sleep 2;
    };

    if ($@) {
      say "✗ Failed: $muni->{domain} - $@";
      $failed++;
    }
  }

  say "\n" . "=" x 60;
  say "Collection complete!";
  say "Collected: $imported";
  say "Failed:    $failed";
  say "=" x 60;
}

=head2 fetch_swedish_municipalities

Fetch list of Swedish municipalities with their domains.

=cut

sub fetch_swedish_municipalities ($ua) {
  say "Fetching Swedish municipalities from SKR...";

  # Fetch from SKR (Sveriges Kommuner och Regioner) official list
  my $tx = $ua->get('https://skr.se/kommunerochregioner/kommunerlista.8288.html');

  unless ($tx->result->is_success) {
    warn "Failed to fetch municipality list from SKR, using fallback list";
    return get_fallback_municipalities();
  }

  my $html = $tx->result->body;
  my @municipalities;
  my %seen;

  # Extract actual municipality domains from SKR list
  # Look for links like: href="http://www.ale.se/" or href="https://www.danderyd.se/"
  while ($html =~ m{href="https?://(?:www\.)?([a-z0-9-]+\.se)/?"}g) {
    my $domain = $1;

    # Skip if we've seen this domain or if it's not a municipality domain
    next if $seen{$domain};
    next if $domain =~ /^(skr|lansstyrelsen|regeringen|riksdagen)/;

    $seen{$domain} = 1;

    # Try to extract municipality name from nearby text
    my $name = ucfirst($domain);
    $name =~ s/\.se$//;

    push @municipalities, {
      domain => $domain,
      name => $name
    };
  }

  if (@municipalities < 200) {
    warn "Only found " . scalar(@municipalities) . " municipalities, using fallback list";
    return get_fallback_municipalities();
  }

  say "Found " . scalar(@municipalities) . " municipalities from SKR";
  return \@municipalities;
}

sub get_fallback_municipalities {
  # Fallback list of major municipalities
  return [
    { domain => 'stockholm.se', name => 'Stockholm' },
    { domain => 'goteborg.se', name => 'Göteborg' },
    { domain => 'malmo.se', name => 'Malmö' },
    { domain => 'uppsala.se', name => 'Uppsala' },
    { domain => 'linkoping.se', name => 'Linköping' },
    { domain => 'orebro.se', name => 'Örebro' },
    { domain => 'vasteras.se', name => 'Västerås' },
    { domain => 'norrkoping.se', name => 'Norrköping' },
    { domain => 'helsingborg.se', name => 'Helsingborg' },
    { domain => 'jonkoping.se', name => 'Jönköping' },
    { domain => 'umea.se', name => 'Umeå' },
    { domain => 'lund.se', name => 'Lund' },
    { domain => 'boras.se', name => 'Borås' },
    { domain => 'sundsvall.se', name => 'Sundsvall' },
    { domain => 'gavle.se', name => 'Gävle' },
  ];
}

=head2 fetch_swedish_newspapers

Fetch list of Swedish newspapers with their domains.

=cut

sub fetch_swedish_newspapers ($ua) {
  say "Fetching Swedish newspapers from worldbanksinfo...";

  # Fetch from worldbanksinfo newspaper list
  my $tx = $ua->get('https://newspaper.worldbanksinfo.com/europe/sweden/');

  unless ($tx->result->is_success) {
    warn "Failed to fetch newspaper list";
    return [];
  }

  my $html = $tx->result->body;
  my @newspapers;
  my %seen;

  # Extract newspaper domains from the page
  # Look for links like: href="https://www.dn.se/" or href="http://www.gp.se/"
  while ($html =~ m{href="https?://(?:www\.)?([a-z0-9-]+\.se)/?"}g) {
    my $domain = $1;

    # Skip if we've seen this domain or if it's not a newspaper domain
    next if $seen{$domain};
    next if $domain =~ /^(worldbanksinfo|chatgpt|designux)/;

    $seen{$domain} = 1;

    # Extract name from domain
    my $name = ucfirst($domain);
    $name =~ s/\.se$//;

    push @newspapers, {
      domain => $domain,
      name => $name
    };
  }

  say "Found " . scalar(@newspapers) . " newspapers from worldbanksinfo";
  return \@newspapers;
}

=head2 fetch_swedish_regions

Fetch list of Swedish regions with their domains from SKR.

=cut

sub fetch_swedish_regions ($ua) {
  say "Fetching Swedish regions from SKR...";

  # Fetch from SKR (Sveriges Kommuner och Regioner) official list
  my $tx = $ua->get('https://skr.se/kommunerochregioner/regionerlista.8289.html');

  unless ($tx->result->is_success) {
    warn "Failed to fetch region list from SKR";
    return [];
  }

  my $html = $tx->result->body;
  my @regions;
  my %seen;

  # Extract actual region domains from SKR list
  # Look for links like: href="https://www.regionstockholm.se/" or href="http://www.skane.se/"
  while ($html =~ m{href="https?://(?:www\.)?([a-z0-9-]+\.se)/?"}g) {
    my $domain = $1;

    # Skip if we've seen this domain or if it's not a region domain
    next if $seen{$domain};
    next if $domain =~ /^(skr|lansstyrelsen|regeringen|riksdagen|1177|adda|equalis)/;

    $seen{$domain} = 1;

    # Try to extract region name from nearby text
    my $name = ucfirst($domain);
    $name =~ s/\.se$//;

    push @regions, {
      domain => $domain,
      name => $name
    };
  }

  say "Found " . scalar(@regions) . " regions from SKR";
  return \@regions;
}

=head2 scrape_and_analyze

Scrape a domain and use AI to extract and translate information.

=cut

sub scrape_and_analyze ($ua, $domain, $app) {
  my $url = "https://$domain";

  say "  Fetching: $url";
  # Set max redirects, timeout, and user agent
  $ua->max_redirects(5);
  $ua->connect_timeout(10);
  $ua->request_timeout(30);
  $ua->transactor->name('Samizdat (see fakemedium.com)');

  my $tx = $ua->get($url);

  unless ($tx->result->is_success) {
    die "Failed to fetch $url: " . $tx->result->message;
  }

  my $html = $tx->result->body;

  # Ensure HTML is decoded as UTF-8
  utf8::decode($html) unless utf8::is_utf8($html);

  # Extract title and meta description
  my $title_en = '';
  my $title_sv = '';
  my $desc_en = '';
  my $desc_sv = '';

  # Try to extract from HTML
  if ($html =~ m{<title[^>]*>([^<]+)</title>}i) {
    $title_sv = $1;
    $title_sv =~ s/^\s+|\s+$//g;
    $title_sv = html_unescape($title_sv);
    utf8::decode($title_sv) unless utf8::is_utf8($title_sv);
  }

  if ($html =~ m{<meta\s+name=["']description["']\s+content=["']([^"']+)["']}i) {
    $desc_sv = $1;
    $desc_sv =~ s/^\s+|\s+$//g;
    $desc_sv = html_unescape($desc_sv);
    utf8::decode($desc_sv) unless utf8::is_utf8($desc_sv);
  }

  # Use AI to translate if we have Swedish content
  if ($title_sv || $desc_sv) {
    say "  Using AI to translate...";
    my $translations = translate_with_ai($app, {
      sv => {
        title => $title_sv,
        description => $desc_sv
      }
    });

    if ($translations && $translations->{en}) {
      $title_en = $translations->{en}->{title};
      $desc_en = $translations->{en}->{description};
    }
  }

  # If no Swedish content found, try to use AI to analyze the page
  unless ($title_sv || $desc_sv) {
    say "  Using AI to analyze page...";
    my $summary = analyze_with_ai($app, $domain, $html);
    if ($summary) {
      $title_en = $summary->{en}->{title} || '';
      $desc_en = $summary->{en}->{description} || '';
      $title_sv = $summary->{sv}->{title} || '';
      $desc_sv = $summary->{sv}->{description} || '';
    }
  }

  return {
    translations => {
      en => {
        title => $title_en,
        description => $desc_en
      },
      sv => {
        title => $title_sv,
        description => $desc_sv
      }
    }
  };
}

=head2 translate_with_ai

Translate content using Claude AI.

=cut

sub translate_with_ai ($app, $content) {
  my $config = $app->config->{anthropic} || {};
  my $api_key = $config->{api_key} || $ENV{ANTHROPIC_API_KEY};
  my $model = $config->{model} || 'claude-sonnet-4-20250514';

  unless ($api_key) {
    warn "No Anthropic API key configured, skipping translation";
    return undef;
  }

  my $ua = Mojo::UserAgent->new;

  my $sv_title = $content->{sv}->{title} || '';
  my $sv_desc = $content->{sv}->{description} || '';

  my $prompt = "Translate the following Swedish municipality website content to English. " .
               "Provide only the translation in JSON format with 'title' and 'description' fields.\n\n" .
               "Swedish content:\n" .
               "Title: $sv_title\n" .
               "Description: $sv_desc";

  $ua->transactor->name('Samizdat (see fakemedium.com)');

  # Build the request payload - encode to bytes manually
  my $json_body = encode_json({
    model => $model,
    max_tokens => 500,
    messages => [
      {
        role => 'user',
        content => $prompt
      }
    ]
  });

  my $tx = $ua->post('https://api.anthropic.com/v1/messages' => {
    'Content-Type' => 'application/json',
    'x-api-key' => $api_key,
    'anthropic-version' => '2023-06-01'
  } => $json_body);

  if ($tx->result->is_success) {
    my $response = $tx->result->json;
    if ($response->{content} && @{$response->{content}}) {
      my $text = $response->{content}->[0]->{text};

      # Remove markdown code blocks if present
      $text =~ s/```json\s*//g;
      $text =~ s/```\s*//g;
      $text =~ s/^\s+|\s+$//g;  # Trim whitespace

      # Try to parse the entire response as JSON
      # Convert UTF-8 string back to bytes before decode_json
      my $json;
      eval {
        $json = decode_json(encode_utf8($text));
      };

      if ($@ || !$json) {
        warn "JSON parsing error: $@" if $@;
      } else {
        return {
          en => {
            title => $json->{title} || '',
            description => $json->{description} || ''
          }
        };
      }
    }
  }

  warn "Translation failed: " . ($tx->result->message || 'Unknown error');
  return undef;
}

=head2 analyze_with_ai

Analyze a webpage using Claude AI to extract and translate content.

=cut

sub analyze_with_ai ($app, $domain, $html) {
  my $config = $app->config->{anthropic} || {};
  my $api_key = $config->{api_key} || $ENV{ANTHROPIC_API_KEY};
  my $model = $config->{model} || 'claude-sonnet-4-20250514';

  unless ($api_key) {
    warn "No Anthropic API key configured, skipping analysis";
    return undef;
  }

  # Extract text content from HTML (simple approach)
  my $text = $html;
  $text =~ s/<script[^>]*>.*?<\/script>//gis;
  $text =~ s/<style[^>]*>.*?<\/style>//gis;
  $text =~ s/<[^>]+>//g;
  $text =~ s/\s+/ /g;
  $text = substr($text, 0, 2000);  # Limit to first 2000 chars

  my $ua = Mojo::UserAgent->new;

  my $prompt = "Analyze this Swedish municipality website ($domain) and provide:\n" .
               "1. A concise title in both English and Swedish\n" .
               "2. A brief description in both English and Swedish\n\n" .
               "Respond in JSON format:\n" .
               '{"en": {"title": "...", "description": "..."}, "sv": {"title": "...", "description": "..."}}'.
               "\n\nWebsite content:\n$text";

  $ua->transactor->name('Samizdat (see fakemedium.com)');
  my $tx = $ua->post('https://api.anthropic.com/v1/messages' => {
    'Content-Type' => 'application/json',
    'x-api-key' => $api_key,
    'anthropic-version' => '2023-06-01'
  } => json => {
    model => $model,
    max_tokens => 800,
    messages => [
      {
        role => 'user',
        content => $prompt
      }
    ]
  });

  if ($tx->result->is_success) {
    my $response = $tx->result->json;
    if ($response->{content} && @{$response->{content}}) {
      my $text = $response->{content}->[0]->{text};

      # Remove markdown code blocks if present
      $text =~ s/```json\s*//g;
      $text =~ s/```\s*//g;
      $text =~ s/^\s+|\s+$//g;  # Trim whitespace

      # Try to parse the entire response as JSON
      # Convert UTF-8 string back to bytes before decode_json
      my $json;
      eval {
        $json = decode_json(encode_utf8($text));
      };

      if ($@ || !$json) {
        warn "JSON parsing error: $@" if $@;
      } elsif ($json->{en} && $json->{sv}) {
        return $json;
      }
    }
  }

  warn "Analysis failed: " . ($tx->result->message || 'Unknown error');
  return undef;
}

=head2 translate_domains

Translate domains from a JSON file.

=cut

sub translate_domains ($self, $file) {
  my $app = $self->app;

  say "Translating domains from: $file";

  # Implementation for batch translation
  say "Not yet implemented";
}

=head2 scrape_domain

Scrape and analyze a single domain.

=cut

sub scrape_domain ($self, $domain) {
  my $app = $self->app;
  my $ua = Mojo::UserAgent->new;
  $ua->transactor->name('Samizdat (see fakemedium.com)');

  say "Scraping: $domain";

  my $info = scrape_and_analyze($ua, $domain, $app);

  say "\nResults:";
  say "=" x 60;
  say "English:";
  say "  Title: " . ($info->{translations}->{en}->{title} || 'N/A');
  say "  Desc:  " . ($info->{translations}->{en}->{description} || 'N/A');
  say "\nSwedish:";
  say "  Title: " . ($info->{translations}->{sv}->{title} || 'N/A');
  say "  Desc:  " . ($info->{translations}->{sv}->{description} || 'N/A');
  say "=" x 60;
}

1;

=head1 NAME

Samizdat::Command::biscollect - Collect and translate BIS domains using AI

=head1 SYNOPSIS

  Usage: samizdat biscollect <command> [options]

  Commands:
    municipalities [sv|all]  - Collect Swedish municipalities
    translate <file.json>    - Translate existing domains
    scrape <domain>          - Scrape and analyze a domain

  # Collect all Swedish municipalities
  ./samizdat biscollect municipalities

  # Scrape and analyze a single domain
  ./samizdat biscollect scrape stockholm.se

  # Translate domains from a file
  ./samizdat biscollect translate domains.json

=head1 DESCRIPTION

This command uses AI (Claude) to collect, scrape, analyze, and translate
domain information for the BIS (Based in Sweden) tracking system.

Features:
- Automatic web scraping of domain content
- AI-powered content extraction and summarization
- Automatic translation between Swedish and English
- Integration with Swedish municipality databases

=head1 CONFIGURATION

Add Anthropic API key to samizdat.yml:

  anthropic:
    api_key: sk-ant-...

Or set environment variable:

  export ANTHROPIC_API_KEY=sk-ant-...

=head1 SEE ALSO

L<Samizdat::Model::BIS>, L<Samizdat::Command::bisimport>

=cut
