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
  my $selectedimage = {};
  $path->list({ dir => 0 })->sort(sub { $a cmp $b })->each(sub ($file, $num) {
    my $docpath = $file->to_rel($self->config->{publicsrc})->to_string;
    if ('md' eq $file->path->extname()) {
      my $content = decode 'UTF-8', $file->slurp;
      my $head = {};
      $self->transclude(\$content, $head, $file->dirname);
      my $html = $md->markdown($content);
      my $dom = Mojo::DOM->new->xml(0)->parse($html);
      my $title = $dom->at('h1')->text;
      $dom->at('h1')->remove;

      $dom->find('img')->each( sub ($img, $num) {
        $img->xml(0);
        
        # If img is the only child of a p tag, replace the p with the img
        my $parent = $img->parent;
        if ($parent && $parent->tag eq 'p' && $parent->children->size == 1) {
          $parent->replace($img);
        }
        
        my $src = $img->attr('src');
        if ($src !~ m{^(http|https)?://} && $src !~ m{^data:} && $src !~ m{^/captcha\.}) {
          if (!exists($selectedimage->{src}) || 'selectedimage' eq $img->attr('id')) {
            $selectedimage = {
              src    => $src,
              width  => $img->attr('width') // 0,
              height => $img->attr('height') // 0
            };
          }
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
    }
  });
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


sub transclude ($self, $contentref, $head, $dirname) {
  # Extract metadata from reference-style links like [key]: # "value"
  while ($$contentref =~ s/^\[([^\]]+)\]:\s*#\s*"([^"]+)"\s*$//m) {
    my $key = $1;
    my $value = $2;
    
    # Initialize nested hashes if they don't exist
    $head->{meta} //= {};
    $head->{meta}->{name} //= {};
    $head->{meta}->{property} //= {};
    $head->{meta}->{itemprop} //= {};
    
    if ($key =~ /^(description|keywords)$/) {
      $head->{meta}->{name}->{$key} = $value;
    } elsif ($key =~ /^og:(.+)$/) {
      $head->{meta}->{property}->{$key} = $value;
    } elsif ($key =~ /^twitter:(.+)$/) {
      $head->{meta}->{name}->{$key} = $value;
    } elsif ($key =~ /^itemprop:(.+)$/) {
      my $itemprop_key = $1;
      $head->{meta}->{itemprop}->{$itemprop_key} = $value;
    } elsif ($key =~ /^(title)$/) {
      $head->{$key} = $value;
    } else {
      # Store other metadata directly in head
      $head->{$key} = $value;
    }
  }

  # Process file transclusions
  $$contentref =~ s/\{\{([^{}]+)\}\}/ $self->includefile($dirname, $1) /ge;
}

sub includefile ($self, $dirname, $filename) {
  my $inclusion = Mojo::Home->new($dirname .'/')->rel_file($filename)->slurp;
  return $inclusion;
}

# Get the menu items for a given menu in a tree structure
sub menuitems ($self, $menuid = 1) {
  my $db = $self->database->db;
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


sub tidyup ($self, $htmlref) {
  # Remove indentation from <pre> blocks
  $$htmlref =~ s{<pre([^>]*?)>(.*?)</pre>}[
    my $attribs = $1;
    my $text = $2;
    $text =~ s/^[ ]+//gms;
    sprintf('<pre%s>%s</pre>', $attribs, $text);
  ]gexsmu;

  # Especially for converted indented markdown
  $$htmlref =~ s{<pre><code>(.*?)</code></pre>}[
    my $text = $1;
    $text =~ s/^[ ]+//gms;
    sprintf('<pre><code>%s</code></pre>', $text);
  ]gexsmu;

  # Remove indentation from <textarea> blocks
  $$htmlref =~ s{(^[\s]*)<textarea([^>]*?)>(.*?)</textarea>}[
    my $indent = $1;
    my $attribs = $2;
    my $text = $3;
    $text =~ s/^[ ]+//gms;
    sprintf('%s<textarea%s>%s</textarea>', $indent, $attribs, $text);
  ]gexsmu;

  $self->imgtopicture($htmlref);
}


# Convert <img> tags to <picture> with srcset and sizes attributes
sub imgtopicture ($self, $htmlref) {

  # Use DOM only for analysis, store info for each img
  my $dom = Mojo::DOM->new($$htmlref);
  my $img_info = {};

  # First pass: analyze all images and make a hash of the ones we want to process
  $dom->find('img')->each(sub ($img, $num) {
    my $src = $img->attr('src') // '';

    # Skip if src is empty or data URL
    return if !$src || $src =~ /^data:/;

    # Skip if src is a remote URL
    return if $src =~ m{^https?://};

    # Skip if src is local captcha
    return if $src =~ m{^/captcha\.};

    # Extract base filename
    my $base = $src;
    $base =~ s/\.[^.]+$//; # Remove extension

    # Determine column width by checking ancestor classes
    my $col_size = 12; # Default to full width
    my $parent = $img;

    for (1..5) {
      $parent = $parent->parent;
      last unless $parent;

      if (my $parent_class = $parent->attr('class')) {
        if ($parent_class =~ /col-(?:\w+-)?(\d+)/) {
          $col_size = $1;
          last;
        }
      }
    }

    # Define srcset and sizes based on column size
    my ($srcset_webp, $sizes);
    if ($col_size <= 4) {
      # 4-column layout
      $srcset_webp = "${base}_405.webp 405w, ${base}_426.webp 426w";
      $sizes = "(min-width: 1400px) 426px, (min-width: 1200px) 426px, (min-width: 992px) 426px, (min-width: 768px) 405px, 100vw";
    } elsif ($col_size <= 8) {
      # 8-column layout
      $srcset_webp = "${base}_426.webp 426w, ${base}_873.webp 873w";
      $sizes = "(min-width: 1400px) 873px, (min-width: 1200px) 873px, (min-width: 992px) 873px, (min-width: 768px) 426px, 100vw";
    } else {
      # 12-column layout
      $srcset_webp = "${base}_426.webp 426w, ${base}_873.webp 873w, ${base}_1320.webp 1320w";
      $sizes = "(min-width: 1400px) 1320px, (min-width: 1200px) 1320px, (min-width: 992px) 1320px, (min-width: 768px) 873px, (min-width: 576px) 873px, 100vw";
    }

    # Store info for this src
    $img_info->{$src} = {
      srcset_webp => $srcset_webp,
      sizes => $sizes,
      base => $base,
    };
  });

  # Second pass: use regex to replace img tags while preserving indentation
  $$htmlref =~ s{^([\s]*)(.*)(<img\s+[^>]*?src=(["']{1})([^"']+)\4[^>]*?)(/?)>(.*)$}{
    my $indent = $1;  # Preserve indentation
    my $prelude = $2; # Stuff before the img tag
    my $img_tag = $3;
    my $src = $5;
    my $closing = $6;
    my $postlude = $7; # Stuff after the img tag

    if (exists $img_info->{$src}) {
      # Extract class and alt
      my $class = $img_tag =~ /class=(["']{1})([^"']*)\1/ ? $2 : 'img-fluid';
      my $alt = $img_tag =~ /alt=(["']{1})([^"']*)\1/ ? $2 : '';

      # Remove src, class, and alt from the original attributes
      my $other_attrs = $img_tag;
      $other_attrs =~ s/<img\s*//;                    # Remove opening tag
      $other_attrs =~ s/\s*src=(["'])[^"']*\1//;    # Remove src
      $other_attrs =~ s/\s*class=(["'])[^"']*\1//;  # Remove class
      $other_attrs =~ s/\s*alt=(["'])[^"']*\1//;    # Remove alt
      $other_attrs =~ s/^\s+|\s+$//g;               # Trim whitespace

      # Get srcset and sizes
      my $info = $img_info->{$src};
      my $srcset_webp = $info->{srcset_webp};
      my $base = $info->{base};
      my $sizes = $info->{sizes};

      # Build the picture element on a single line
      sprintf("%s%s<picture>\n%s\n%s\n%s</picture>%s",
        $indent,
        $prelude,
        sprintf('  %s<source type="image/webp" srcset="%s" sizes="%s">',
          $indent,
          $srcset_webp,
        $sizes
        ),
        sprintf("  %s%s",
          $indent,
          sprintf('<img src="%s.png"%s%s%s>',
            $base,
            ($class ne '') ? sprintf(' class="%s"', $class) : '',
            ($alt ne '') ? sprintf(' alt="%s"', $alt) : '',
            $other_attrs ? ' ' . $other_attrs : ''
          ),
        ),
        $indent,
        $postlude
      );
    } else {
      # If no info available, return the original img tag
      "$indent$prelude$img_tag$closing>$postlude";
    }
  }gem;

}

sub indent ($self, $content = '', $indents = 0) {
  no warnings 'uninitialized';
  my $indent = "  " x $indents;
  $content =~ s/\n/\n$indent/gsm;
  $content =~s/$indent$//sm;
  chomp $content;
  return sprintf("%s%s\n", $indent, $content);
}

1;
