package Samizdat::Command::makeicons;

use Mojo::Base 'Mojolicious::Command', -signatures;
use Data::Dumper;

has description => 'Makes small and large png icons from svg sources.';
has usage => sub ($self) { $self->extract_usage };


sub run ($self, @args) {
  for my $size (@{ $self->app->config->{icons}->{sizes} }) {
    my $src = (75 > $size) ? $self->app->config->{icons}->{small} : $self->app->config->{icons}->{large};
    my $dest = sprintf('public/media/images/icon.%04d.png', $size);
    system('rsvg-convert', '-w', $size, '-p', 300, '-d', '300', '-o', $dest, $src);
    system('convert', $dest,
      '-gravity', 'center',
      '-background', 'transparent',
      '-resize', sprintf('%dx%d', $size, $size),
      '-extent', sprintf('%dx%d', $size, $size),
      'tmp.png'
    );
    system('pngquant', 256, '-f', '-o', $dest, 'tmp.png');
    unlink 'tmp.png';
  }
}


1;