package Samizdat::Command::makestatic;
use Mojo::Base 'Mojolicious::Command', -signatures;
use Data::Dumper;

has description => 'Apply templates to markdown files and dump resulting files in the public dir';
has usage => sub ($self) { $self->extract_usage };

sub run ($self, @args) {
  my $uris = $self->app->markdown()->geturis();
say Dumper $uris;

}

=head1 SYNOPSIS

  Usage: samizdat makestatic


=cut

1;