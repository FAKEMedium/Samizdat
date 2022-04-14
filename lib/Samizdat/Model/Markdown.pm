package Samizdat::Model::Markdown;

use strict;
use warnings;
use experimental qw(signatures);

use Mojo::DOM;
use Mojo::Home;
use Text::MultiMarkdown;
use Imager::File::WEBP;
use Mojo::Util qw(decode);

my $md = Text::MultiMarkdown->new(
  empty_element_suffix => ' />',
  tab_width => 2,
  use_wikilinks => 1,
);

sub new ($class) { bless {}, $class }

sub list ($self, $url, $options = {}) {
  my $docs = {};
  my $path = Mojo::Home->new('public/')->child($url);
  $path->list({ dir => 0 })->each(sub ($file, $num) {
    if ('md' eq $file->path->extname()) {
      my $content = $file->slurp;
      my $html = decode 'UTF-8', $md->markdown($content);
      my $dom = Mojo::DOM->new($html);
      my $title = $dom->at('h1')->text;
      $dom->at('h1')->remove;
      $html = $dom->content;
      $html =~s/^[\s\r\n]+//;
      $html =~s/[\s\r\n]+$//;

      my $docpath = $file->to_rel('public/')->to_string;
      $docpath =~ s/README\.md/index.html/;
      $docs->{$docpath} = {
        docpath     => $docpath,
        title       => $title,
        main        => $html,
        children    => [],
        subdocs     => [],
        description => undef,
        keywords    => [],
      };
    }
  });

  my $subdocs = [];
  for my $docpath (sort {$a cmp $b} keys %{ $docs }) {
    if ($docpath !~ /index\.html$/) {
      push @{ $subdocs }, delete $docs->{$docpath};
    }
  }
  for (@{ $subdocs }) {
    push @{ $docs->{'index.html'}->{subdocs} }, $_;
  }
  return $docs;
}


1;