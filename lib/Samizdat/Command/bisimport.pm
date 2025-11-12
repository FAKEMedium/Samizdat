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
      my $domain_id = $bis->add_domain(
        domain => $domain->{domain},
        title => $domain->{title} || '',
        description => $domain->{description} || '',
        tags => $domain->{tags} || [],
        lang => 'en'  # Default to English for imports
      );

      say "✓ Imported: $domain->{domain} (ID: $domain_id)";
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

JSON file should contain an array of domain objects:

  [
    {
      "domain": "regeringen.se",
      "title": "Swedish Government",
      "description": "Main government portal",
      "tags": ["government"]
    },
    {
      "domain": "karolinska.se",
      "title": "Karolinska Hospital",
      "description": "Major hospital",
      "tags": ["healthcare"]
    }
  ]

Or a single object:

  {
    "domain": "regeringen.se",
    "title": "Swedish Government",
    "tags": ["government"]
  }

=head1 SEE ALSO

L<Samizdat::Model::BIS>, L<Samizdat::Command::bischeck>

=cut
