package Samizdat::Command::makestatic;
use Mojo::Base 'Mojolicious::Command', -signatures;

has description => 'Apply templates to markdown files and dump resulting files in the public dir';
has usage => sub ($self) { $self->extract_usage };

sub run ($self, @args) {
  foreach my $file (@{ $self->app->markdown()->list }) {
    my $md = $self->app->markdown()->readmd($file);
    my $html = $self->app->markdown()->md2html($md);
    say $self->template({vars => 1})->render_data('index', {main => $html});

  }
}

=head1 SYNOPSIS

  Usage: samizdat makestatic


=cut

1;