package Samizdat::Model::Markdown;

use strict;
use warnings;
use experimental qw(signatures);

use Mojo::Home;
use Text::MultiMarkdown;
my $md = Text::MultiMarkdown->new(
  empty_element_suffix => ' />',
  tab_width => 2,
  use_wikilinks => 1,
);

sub new ($class) { bless {}, $class }

sub list ($self) {
  my $options = shift // {};
  my $files = [];

  my $path = Mojo::Home->new('public/');
  my $sources = {};
  $path->list_tree({dir => 0})->each(sub ($file, $num) {
    if ('md' eq $file->path->extname()) {
      push @{ $files }, $file;
      if ($options->{walk}) {

      }
    }
  });
  return $files;
}

sub readmd ($self, $path) {
  my $options = shift // {};
  my $content = Mojo::Home->new(sprintf('public/%s', $path))->slurp // undef;
}

sub writehtml ($self, $path, $content) {
  my $options = shift // {};
}

sub md2html ($self, $content) {
  my $options = shift // {};
  return $md->markdown($content);
}
1;