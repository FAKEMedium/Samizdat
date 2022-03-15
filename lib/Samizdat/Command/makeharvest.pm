package Samizdat::Command::makeharvest;
use Mojo::Base 'Mojolicious::Command', -signatures;

has description => 'Fetches content from configured sources and stores locally.';
has usage => sub ($self) { $self->extract_usage };

sub run ($self, @args) {

}

=head1 SYNOPSIS

  Usage: samizdat makeharvest


=cut