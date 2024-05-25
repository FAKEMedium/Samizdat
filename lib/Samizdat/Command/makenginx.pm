package Samizdat::Command::makenginx;

use Mojo::Base 'Mojolicious::Command', -signatures;
use Mojo::Home;
use Mojo::Template;

use Data::Dumper;

has description => 'Outputs a configuraton file for an Nginx server on the same machine.';
has usage => sub ($self) { $self->extract_usage };


sub run ($self, @args) {

}

=head1 SYNOPSIS

  Usage: samizdat makenginx


=cut

1;

__DATA__