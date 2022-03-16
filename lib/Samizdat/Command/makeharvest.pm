package Samizdat::Command::makeharvest;
use Mojo::Base 'Mojolicious::Command', -signatures;
use Mojo::Home;
use YAML::LoadBundle;

has description => 'Fetches content from configured sources and stores locally.';
has usage => sub ($self) { $self->extract_usage };

sub run ($self, @args) {
  my $path = Mojo::Home->new('sources.d/');
  $path->list_tree({dir => 0})->each(sub ($file, $num) {
      if ('yml' eq $file->path->extname()) {
        say $file;
      }
  });
}

=head1 SYNOPSIS

  Usage: samizdat makeharvest


=cut

1;