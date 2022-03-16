package Samizdat::Command::makeharvest;
use Mojo::Base 'Mojolicious::Command', -signatures;
use Mojo::Home;
use Hash::Merge qw( merge );
use YAML::XS qw(Load);
Hash::Merge::set_behavior('RETAINMENT_PRECEDENT');
use WWW::YouTube::Download;
use Data::Dumper;

has description => 'Fetches content from configured sources and stores locally.';
has usage => sub ($self) { $self->extract_usage };

sub run ($self, @args) {
  my $path = Mojo::Home->new('sources.d/');
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