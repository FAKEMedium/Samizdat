package Samizdat::Command::bisimport;

use Mojo::Base 'Mojolicious::Command', -signatures;
use Mojo::File;
use Mojo::JSON qw(decode_json);
use Text::CSV;

has description => 'Import BIS domains from CSV or JSON file';
has usage => sub { shift->extract_usage };

sub run ($self, @args) {
  my $app = $self->app;
  my $bis = $app->bis;

  unless (@args) {
    die "Usage: samizdat bisimport <file.csv|file.json>\n";
  }

  my $file = shift @args;
  unless (-f $file) {
    die "File not found: $file\n";
  }

  say "Importing domains from: $file";

  my $domains;
  if ($file =~ /\.json$/i) {
    $domains = import_json($file);
  } elsif ($file =~ /\.csv$/i) {
    $domains = import_csv($file);
  } else {
    die "Unsupported file format. Use .csv or .json\n";
  }

  say "Found " . scalar(@$domains) . " domains to import";

  my $imported = 0;
  my $failed = 0;

  for my $domain (@$domains) {
    eval {
      # First, add the domain (or get existing ID)
      my $domain_id = $bis->add_domain(
        domain => $domain->{domain},
        tags => $domain->{tags} || []
      );

      # Add translations for all available languages
      my $translations = $domain->{translations} || {};

      # If no translations structure, use legacy title/description
      if (!%$translations && ($domain->{title} || $domain->{description})) {
        $translations->{en} = {
          title => $domain->{title} || '',
          description => $domain->{description} || ''
        };
      }

      # Add each translation
      for my $lang (keys %$translations) {
        my $trans = $translations->{$lang};
        if ($trans->{title} || $trans->{description}) {
          $bis->add_domain(
            domain => $domain->{domain},
            title => $trans->{title} || '',
            description => $trans->{description} || '',
            tags => $domain->{tags} || [],
            lang => $lang
          );
        }
      }

      my $lang_count = scalar keys %$translations;
      say "✓ Imported: $domain->{domain} (ID: $domain_id, $lang_count languages)";
      $imported++;
    };

    if ($@) {
      say "✗ Failed: $domain->{domain} - $@";
      $failed++;
    }
  }

  say "\n" . "=" x 60;
  say "Import complete!";
  say "Imported: $imported";
  say "Failed:   $failed";
  say "=" x 60;
}

sub import_json ($file) {
  my $content = Mojo::File->new($file)->slurp;
  my $data = decode_json($content);

  # Support both array and single object
  return ref $data eq 'ARRAY' ? $data : [$data];
}

sub import_csv ($file) {
  my $csv = Text::CSV->new({ binary => 1, auto_diag => 1 });
  open my $fh, '<:encoding(utf8)', $file or die "Cannot open $file: $!";

  # Read header
  my $header = $csv->getline($fh);
  my @columns = @$header;

  my @domains;

  while (my $row = $csv->getline($fh)) {
    my %domain;

    for my $i (0 .. $#columns) {
      my $col = $columns[$i];
      $domain{$col} = $row->[$i];
    }

    # Handle tags (comma-separated or single)
    if ($domain{tags}) {
      $domain{tags} = [split /[,;]\s*/, $domain{tags}];
    } else {
      $domain{tags} = [];
    }

    push @domains, \%domain;
  }

  close $fh;
  return \@domains;
}

1;

=head1 NAME

Samizdat::Command::bisimport - Import BIS domains from CSV or JSON

=head1 SYNOPSIS

  Usage: APPLICATION bisimport FILE

    # Import from CSV
    ./samizdat bisimport domains.csv

    # Import from JSON
    ./samizdat bisimport domains.json

=head1 DESCRIPTION

This command imports domains into the BIS tracking system from CSV or JSON files.

=head2 CSV Format

CSV file should have a header row with these columns:

  domain,title,description,tags

Example:

  domain,title,description,tags
  regeringen.se,Swedish Government,Main government portal,government
  karolinska.se,Karolinska Hospital,Major hospital,healthcare
  stockholm.se,Stockholm Municipality,Municipal services,"municipality,government"

Notes:
- domain: Required
- title: Optional
- description: Optional
- tags: Optional, comma or semicolon separated

=head2 JSON Format

JSON file should contain an array of domain objects with translations:

  [
    {
      "domain": "regeringen.se",
      "tags": ["government"],
      "translations": {
        "en": {
          "title": "Swedish Government",
          "description": "Main government portal"
        },
        "sv": {
          "title": "Regeringen",
          "description": "Sveriges regeringsportal"
        }
      }
    }
  ]

Legacy format (single language) is also supported:

  [
    {
      "domain": "regeringen.se",
      "title": "Swedish Government",
      "description": "Main government portal",
      "tags": ["government"]
    }
  ]

=head1 SEE ALSO

L<Samizdat::Model::BIS>, L<Samizdat::Command::bischeck>

=cut
