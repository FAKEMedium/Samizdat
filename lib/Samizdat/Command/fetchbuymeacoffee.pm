package Samizdat::Command::fetchbuymeacoffee;

use Mojo::Base 'Mojolicious::Command', -signatures;
use Samizdat::Model::BuyMeACoffee;

# Add a cron job to run this command every hour
# Not needed if we use the webhook
# 0 * * * * cd /path/to/samizdat && bin/samizdat fetchbuymeacoffee

has description => 'Fetch Buy Me a Coffee supporter count';
has usage => sub { shift->extract_usage };

sub run ($self, @args) {
  my $app = $self->app;
  my $config = $app->config->{buymeacoffee};

  unless ($config && $config->{slug}) {
    say "No Buy Me a Coffee slug configured";
    return;
  }

  say "Fetching supporter count for $config->{slug}...";

  # Create model instance
  my $bmc = Samizdat::Model::BuyMeACoffee->new({
    config => $config,
    redis  => $app->redis,
    pg     => $app->pg,
  });

  # Fetch fresh supporter count
  my $supporters = $bmc->fetch_supporters;

  if ($supporters) {
    say "Supporter count: $supporters (cached)";
  } else {
    say "Failed to fetch supporter count";
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