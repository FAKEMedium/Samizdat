package Samizdat::Model::Markdown;

use strict;
use warnings;
use experimental qw(signatures);

use Mojo::DOM;
use Mojo::Home;
use Text::MultiMarkdown;
use Mojo::Util qw(decode);
use MojoX::MIME::Types;

my $types = MojoX::MIME::Types->new;

my $md = Text::MultiMarkdown->new(
  empty_element_suffix     => ' />',
  tab_width                => 2,
  use_wikilinks            => 0,
  use_metadata             => 1,
  disable_definition_lists => 0,
);

sub new ($class) { bless {}, $class }

sub list ($self, $url, $options = {}) {
  my $docs = {};
  my $path = Mojo::Home->new('public/')->child($url);
  my $found = 0;
  $path->list({ dir => 0 })->each(sub ($file, $num) {
    if ('md' eq $file->path->extname()) {
      my $content = $file->slurp;
      my $html = decode 'UTF-8', $md->markdown($content);
      my $dom = Mojo::DOM->new->xml(1)->parse($html);
      my $title = $dom->at('h1')->text;
      $dom->at('h1')->remove;

      # Locate img tags, make webp alternative, and use the picture tag to wrap things
      # Start by reversing existing picture tags
      $dom->find('picture')->each( sub ($picture, $num) {
        my $img = $picture->at('img');
        $picture->replace($img);
      });
      $dom->find('img')->each( sub ($img, $num) {
        $img->xml(1);
        my $picture = Mojo::DOM->new_tag('picture');
        $picture->xml(1);
        my $src = $img->attr('src');

        $picture->at('picture')->content($img->to_string);
        $picture->at('picture')->prepend_content(sprintf('<source srcset="%s" type="%s" />',
          $src,
          $types->file_type($src)
        ));
        my $webpsrc = $src;
        my $svg = 0;
        if ($webpsrc =~ s/\.([^\.]+)$//) {
          $svg = 1 if ('svg' eq $1);
          $picture->at('picture')->prepend_content(sprintf('<source srcset="%s.webp" type="image/webp" />', $webpsrc));
        }
        $img->replace($picture) if (!$svg);
      });
      $html = $dom->content;
      $html =~ s/\`\`\`([^\`]+?)\`\`\`/<pre><code>$1<\/code><\/pre>/gms;
      $html =~ s/^[\s\r\n]+//;
      $html =~ s/[\s\r\n]+$//;

      my $docpath = $file->to_rel('public/')->to_string;
      if ($docpath =~ s/README\.md/index.html/) {
        $found = 1;
      }
      $docs->{$docpath} = {
        docpath     => $docpath,
        title       => $title,
        main        => $html,
        children    => [],
        subdocs     => [],
        description => undef,
        keywords    => [],
        url         => $url,
      };
    }
  });
  if (!$found) {
    return $docs;
  }
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