package Samizdat::Model::Markdown;

use strict;
use warnings;
use experimental qw(signatures);

use Mojo::Home;
use Text::Markdown;

sub new ($class) { bless {}, $class }

sub list ($self) {
  my $files = undef;
  my $home = Mojo::Home->new;
  $home = $home->rel_file('public');
  $home->list_tree({dir =>0})->each( sub ($file, $num) {
    say $file;
  });


  return $files;
}

sub getcontent ($self) {
  my $content = undef;
}
1;