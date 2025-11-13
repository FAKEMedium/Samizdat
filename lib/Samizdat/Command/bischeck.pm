package Samizdat::Command::bischeck;

use Mojo::Base 'Mojolicious::Command', -signatures;

has description => 'Run BIS (Based in Sweden) compliance checks';
has usage => sub { shift->extract_usage };

sub run ($self, @args) {
  my $app = $self->app;
  my $bis = $app->bis;

  # Enable autoflush for immediate output
  $| = 1;

  say "Starting BIS compliance check...";

  # Start a new run
  my $run_id = $bis->start_run();
  say "Created run #$run_id";

  # Get all active domains
  my $domains = $bis->pg->db->query(q{
    SELECT id, domain FROM bis.domains WHERE active = true
  })->hashes;

  my $total = scalar(@$domains);
  say "Found $total active domains to check";

  # Check each domain
  my $checked = 0;
  for my $domain (@$domains) {
    $checked++;
    say "[$checked/$total] Checking $domain->{domain}...";

    eval {
      my $result = $bis->check_domain($domain->{id}, $run_id);
      my $badge = $result->{has_bis_badge} ? '✓ BIS BADGE' : '';
      say "  Score: $result->{score}/100 ($result->{compliant_checks}/$result->{total_checks} compliant) $badge";
    };

    if ($@) {
      say "  ERROR: $@";
    }
  }

  # Complete the run and calculate statistics
  say "Calculating statistics...";
  my $stats = $bis->complete_run($run_id);

  say "\nRun #$run_id completed!";
  say "=" x 60;
  say "Total domains:     $stats->{total_domains}";
  say "Compliant domains: $stats->{compliant_domains}";
  say "Compliance rate:   " . sprintf("%.1f%%", ($stats->{compliant_domains} / $stats->{total_domains}) * 100);
  say "Average score:     " . sprintf("%.1f", $stats->{avg_score});
  say "";
  say "Record type compliance:";
  say "  A records:  " . sprintf("%.1f%%", $stats->{a_compliance_rate});
  say "  MX records: " . sprintf("%.1f%%", $stats->{mx_compliance_rate} // 0);
  say "  NS records: " . sprintf("%.1f%%", $stats->{ns_compliance_rate});
  say "=" x 60;
}

1;

=head1 NAME

Samizdat::Command::bischeck - Run BIS compliance checks

=head1 SYNOPSIS

  Usage: APPLICATION bischeck

    # Run from command line
    ./samizdat bischeck

    # Run from cron
    0 */6 * * * cd /path/to/samizdat && ./samizdat bischeck

  This command checks all active domains in the BIS database for
  hosting compliance, determining if infrastructure is located in
  Sweden or hosted by Swedish companies.

=head1 DESCRIPTION

This command:

1. Creates a new check run
2. Checks DNS records (A, AAAA, MX, NS) for all active domains
3. Performs IP geolocation and ASN lookups
4. Identifies hosting providers
5. Calculates compliance scores
6. Stores results in the database
7. Generates statistics

The command can be run manually or scheduled via cron for periodic checks.

=head1 SEE ALSO

L<Samizdat::Model::BIS>, L<Mojolicious::Command>

=cut
