package Samizdat::Model::Markdown;

use strict;
use warnings;
use experimental qw(signatures);

use Mojo::DOM;
use Mojo::Home;
use Text::MultiMarkdown;
my $md = Text::MultiMarkdown->new(
  empty_element_suffix => ' />',
  tab_width => 2,
  use_wikilinks => 1,
);

sub new ($class) { bless {}, $class }

sub list ($self, $url, $options = {}) {
  my $files = [];
  my $path = Mojo::Home->new('public/')->child($url);
  my $sources = {};
  $path->list({ dir => 0 })->sort(sub { uc($a) cmp uc($b) })->each(sub ($file, $num) {
    if ('md' eq $file->path->extname()) {
      push @{ $files }, $file;
      if ($options->{walk}) {

      }
    }
  });
  return $files;
}

sub getpage ($self, $path, $options = {}) {
  my $web = {
    title => '',
    main => '',
    sidebars => [],
  };
  my $content = Mojo::Home->new(sprintf('public/%s', $path))->slurp // undef;
  say $path;
}

sub readmd ($self, $path, $options = {}) {
  my $content = Mojo::Home->new(sprintf('public/%s', $path))->slurp // undef;
}

sub writehtml ($self, $path, $content, $options = {}) {
}

sub md2html ($self, $content, $options = {}) {
  return $md->markdown($content);
}
1;