package Samizdat::Model::Web;

use Mojo::Base -base, -signatures;
use Mojo::DOM;
use Mojo::Home;
use Text::MultiMarkdown;
use Mojo::Util qw(decode);
use MojoX::MIME::Types;
use YAML::XS;
use Data::Dumper;

has 'config';
has 'database';
has 'locale';
has 'routes';

my $types = MojoX::MIME::Types->new;
my $md = Text::MultiMarkdown->new(
  empty_element_suffix     => ' />',
  tab_width                => 2,
  use_wikilinks            => 0,
  use_metadata             => 1,
  disable_definition_lists => 0,
);

# Return a list of all markdown files in the publicsrc/url directory, with their metadata
sub getlist ($self, $url, $options = {}) {
  my $docs = {};
  my $path = Mojo::Home->new($self->config->{publicsrc})->child($url);
  my $found = 0;
  my $meta = {};
  my $selectedimage = {};
  $path->list({ dir => 0 })->sort(sub { $a cmp $b })->each(sub ($file, $num) {
    my $docpath = $file->to_rel($self->config->{publicsrc})->to_string;
    if ('md' eq $file->path->extname()) {
      my $content = decode 'UTF-8', $file->slurp;
      my $head = {};
      transclude(\$content, $head, $file->dirname);
      my $html = $md->markdown($content);
      my $dom = Mojo::DOM->new->xml(0)->parse($html);
      my $title = $dom->at('h1')->text;
      $dom->at('h1')->remove;

      # Locate img tags, make webp alternative, and use the picture tag to wrap things
      # Start by reversing existing picture tags
      $dom->find('picture')->each( sub ($picture, $num) {
        my $img = $picture->at('img');
        $picture->replace($img);
      });

      $dom->find('img')->each( sub ($img, $num) {
        $img->xml(0);
        my $picture = Mojo::DOM->new_tag('picture');
        $picture->xml(0);
        my $src = $img->attr('src');
        my $alt = $img->attr('alt');

        $picture->at('picture')->content($img->to_string);
        $picture->at('picture')->prepend_content(sprintf('<source srcset="%s" type="%s">',
          $src,
          $types->file_type($src)
        ));
        my $webpsrc = $src;
        my $svg = 0;
        if ($webpsrc =~ s/\.([^\.]+)$//) {
          $svg = 1 if ('svg' eq $1);
          $picture->at('picture')->prepend_content(
            sprintf('<source srcset="%s.webp" type="image/webp" media="(min-width: 300px)">', $webpsrc)
          );
        }
        if (!$svg) {
          if (!exists($selectedimage->{src}) || 'selectedimage' eq $img->attr('id')) {
            $selectedimage = {
              src    => $src,
              width  => $img->attr('width') // 0,
              height => $img->attr('height') // 0
            };
          }
          $img->replace($picture);
        }
      });

      $html = $dom->content;
      $html =~ s/^[\s\r\n]+//;
      $html =~ s/[\s\r\n]+$//;

      # Overwrite the docpath of the default language if a file with the preferred language exists
      $docpath =~ s/_($options->{language})\.md$/.md/;
      if ($docpath !~ /\_(.+)\.md$/) {
        if ($docpath =~ s/README\.md/index.html/) {
          $found = $docpath;
        }
        $docs->{$docpath} = {
          docpath     => $docpath,
          title       => $title,
          main        => $html,
          children    => [],
          subdocs     => [],
          url         => $url,
          language    => $options->{language},
          head        => $head,
        };
      }
    } elsif ('yml' eq $file->path->extname()) {
=pod
      my $yaml = $file->slurp;
      my $data = Load($yaml);
      $meta = $data->{meta};
=cut
    }
  });
 # say Dumper $docs;
  if (!$found) {
    return $docs;
  }
  
  # Add image metadata to the main document
  if ($selectedimage->{src}) {
    $docs->{$found}->{head}->{meta} //= {};
    $docs->{$found}->{head}->{meta}->{property} //= {};
    $docs->{$found}->{head}->{meta}->{property}->{'og:image'} = $selectedimage->{src};
  }
  if ($selectedimage->{width}) {
    $docs->{$found}->{head}->{meta} //= {};
    $docs->{$found}->{head}->{meta}->{property} //= {};
    $docs->{$found}->{head}->{meta}->{property}->{'og:image:width'} = $selectedimage->{width};
  }
  if ($selectedimage->{height}) {
    $docs->{$found}->{head}->{meta} //= {};
    $docs->{$found}->{head}->{meta}->{property} //= {};
    $docs->{$found}->{head}->{meta}->{property}->{'og:image:height'} = $selectedimage->{height};
  }
  
  my $subdocs = [];
  for my $docpath (sort {$a cmp $b} keys %{ $docs }) {
    if ($docpath !~ /index\.html$/) {
      push @{ $subdocs }, delete $docs->{$docpath};
    }
  }
  for my $subdoc (@{ $subdocs }) {
    push @{ $docs->{$found}->{subdocs} }, $subdoc;
  }
  return $docs;
}


# Find every README.md markdown file, including the ones with language suffixes, and return a hash of URIs
sub geturis ($self, $options = {}) {
  my $uris = {};
  my $path = Mojo::Home->new($self->config->{publicsrc});
  $path->list_tree({ dir => 0 })->each(sub ($file, $num) {
    if ('md' eq $file->path->extname()) {
      my $filename = $file->to_rel($self->config->{publicsrc})->to_string;
      my $size = $file->stat->size;
      if ($filename =~ s/README([^\/]*)\.md$/README.md/) {
        my $lang = $1;
        $lang =~ s/^_//;
        if ($lang) {
          $uris->{$filename}->{$lang} = $size;
        } else {
          $uris->{$filename}->{$self->{locale}->{default_language}} = $size;
        }
      }
    }
  });
  return $uris;
}


sub transclude ($contentref, $head, $dirname) {
  # Extract metadata from reference-style links like [key]: # "value"
  while ($$contentref =~ s/^\[([^\]]+)\]:\s*#\s*"([^"]+)"\s*$//m) {
    my $key = $1;
    my $value = $2;
    
    # Initialize nested hashes if they don't exist
    $head->{meta} //= {};
    $head->{meta}->{name} //= {};
    $head->{meta}->{property} //= {};
    $head->{meta}->{itemprop} //= {};
    
    if ($key =~ /^(title|description|keywords)$/) {
      $head->{meta}->{name}->{$key} = $value;
    } elsif ($key =~ /^og:(.+)$/) {
      $head->{meta}->{property}->{$key} = $value;
    } elsif ($key =~ /^twitter:(.+)$/) {
      $head->{meta}->{name}->{$key} = $value;
    } elsif ($key =~ /^itemprop:(.+)$/) {
      my $itemprop_key = $1;
      $head->{meta}->{itemprop}->{$itemprop_key} = $value;
    } else {
      # Store other metadata directly in head
      $head->{$key} = $value;
    }
  }

  # Process file transclusions
  $$contentref =~ s/\{\{([^{}]+)\}\}/ includefile($dirname, $1) /ge;
}

sub includefile ($dirname, $filename) {
  my $inclusion = Mojo::Home->new($dirname .'/')->rel_file($filename)->slurp;
  return $inclusion;
}

# Get the menu items for a given menu in a tree structure
sub menuitems ($self, $menuid = 1) {
  my $db = $self->app->pg->db;
  my $childrenof = {};
  $db->select(['menuitems', ['menuitemtitles', 'menuitemid' => 'menuitemid']],
    '*',
    {'menuitems.menuid' => $menuid}, { order_by => {-asc => 'menuitemid', -asc => 'position'} })->hashes->each(
    sub($item, $num) {
      if (defined($item->{parent})) {
        push @{ $childrenof->{ $item->{parent} }}, $item;
      } else {
        push @{ $childrenof->{0}}, $item;
      }
    }
  );
  my $menuitems = [];
}

1;
