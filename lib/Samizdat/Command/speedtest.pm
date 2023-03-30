package Samizdat::Command::speedtest;

use Mojo::Base 'Mojolicious::Command', -signatures;
use Data::Dumper;
use Mojo::UserAgent;

has description => 'Run ab from apache2-utils to get metrics on speed and concurrency for the Samizdat application setup.';
has usage => sub ($self) { $self->extract_usage };

sub run ($self, @args) {
  my $mojourl =  undef;
  for (@{ $self->app->config->{hypnotoad}->{listen} }) {
    $mojourl = $_;
    last if (!/\+unix/);
  }
  say $mojourl;
  $mojourl = 'http://localhost:3000/';

  system('ab', '-n', 1000, '-c', 24, '-v', 1, $mojourl) if (defined $mojourl);
}

=head1 SYNOPSIS

  Usage: samizdat speedtest


=cut

1;