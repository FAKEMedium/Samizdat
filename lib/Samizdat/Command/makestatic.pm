package Samizdat::Command::makestatic;
use Mojo::Base 'Mojolicious::Command', -signatures;
use Mojo::Template;

has description => 'Apply templates to markdown files and dump resulting files in the public dir';
has usage => sub ($self) { $self->extract_usage };

sub run ($self, @args) {
  foreach my $file (@{ $self->app->markdown()->list }) {
    my $md = $self->app->markdown()->readmd($file);
    my $content = {
      main => $self->app->markdown()->md2html($md),
    };
  }
}

=head1 SYNOPSIS

  Usage: samizdat makestatic


=cut

1;