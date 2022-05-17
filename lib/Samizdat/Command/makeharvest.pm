package Samizdat::Command::makeharvest;

use Mojo::Base 'Mojolicious::Command', -signatures;
use Mojo::Home;
use Hash::Merge qw( merge );
use YAML::XS qw(Load);
use WWW::YouTube::Download;
use Data::Dumper;

has description => 'Fetches content from configured sources and stores locally.';
has usage => sub ($self) { $self->extract_usage };

Hash::Merge::set_behavior('RETAINMENT_PRECEDENT');

sub run ($self, @args) {
  my $path = Mojo::Home->new('public/');
  my $sources = {};
  $path->list_tree({dir => 0})->each(sub ($file, $num) {
      if ('yml' eq $file->path->extname()) {
        my $yml = $file->slurp();
        $sources = merge($sources, Load($yml)) if ($yml);
      }
  });
  print Dumper $sources;
}

=head1 SYNOPSIS

  Usage: samizdat makeharvest


=cut

1;