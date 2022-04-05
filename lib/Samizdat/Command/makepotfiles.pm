package Samizdat::Command::makepotfiles;
use Mojo::Base 'Mojolicious::Command', -signatures;
use Mojo::Home;

has description => 'Collects names of files that might have localization functions.';
has usage => sub ($self) { $self->extract_usage };

sub run ($self, @args) {
  my $path = Mojo::Home->new('lib/');
  my $files = [];
  $path->list_tree({dir => 0})->each(sub ($file, $num) {
    push @{$files}, '../' . $file;
  });
  $path = Mojo::Home->new('templates/');
  $path->list_tree({dir => 0})->each(sub ($file, $num) {
    push @{$files}, '../' . $file;
  });
  Mojo::Home->new('locale/POTFILES')->spurt(join "\n", @{$files});
}

=head1 SYNOPSIS

  Usage: samizdat potfiles


=cut

1;