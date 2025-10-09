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
# Now checks database first before processing markdown files
sub getlist ($self, $url, $options = {}) {
  my $docs = {};
  
  # First check if we have database content for this path
  # Normalize the path to match what was saved (with leading slash)
  my $save_docpath = $url || '';
  $save_docpath =~ s|^/||;   # Remove leading slash
  $save_docpath =~ s|/$||;   # Remove trailing slash  
  $save_docpath = $save_docpath ? "/$save_docpath/" : "/";  # Add proper slashes
  
  if ($self->has_database_content($save_docpath, $options->{language} // 'en')) {
    return $self->get_database_content($save_docpath, $options->{language} // 'en');
  }
  
  # Fall back to markdown file processing
  my $path = Mojo::Home->new($self->config->{publicsrc})->child($url);
  my $found = 0;
  my $selectedimage = {};
  $path->list({ dir => 0 })->sort(sub { $a cmp $b })->each(sub ($file, $num) {
    my $docpath = $file->to_rel($self->config->{publicsrc})->to_string;
    my $datasrc = $docpath;
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

      # Get the HTML content with basic formatting
      $html = $dom->to_string;
      # Remove extra whitespace at start/end
      $html =~ s/^[\s\r\n]+//;
      $html =~ s/[\s\r\n]+$//;
      # Add newlines after block elements for readability
      $html =~ s/(<\/(p|div|h[1-6]|ul|ol|li|blockquote|section|article|aside|nav|header|footer|pre)>)/$1\n/gi;

      # Overwrite the docpath of the default language if a file with the preferred language exists
      $docpath =~ s/_($options->{language})\.md$/.md/;
      
      # Determine if this will be a sidecard (not an index file)
      my $will_be_index = 0;
      if ($docpath =~ /README\.md$/) {
        $will_be_index = 1;
      }
      
      # Extract first image for sidecards if it's the first element
      my $card_image = '';
      # Only process card images for files that will become sidecards
      if (!$will_be_index) {
        # Re-parse the HTML to work with DOM
        my $card_dom = Mojo::DOM->new($html);
        
        # Get the first child element
        my $first_elem = $card_dom->children->first;
        
        # Check if it's a picture or img element
        if ($first_elem && $first_elem->tag && ($first_elem->tag eq 'picture' || $first_elem->tag eq 'img')) {
          # Extract the element
          $card_image = $first_elem->to_string;
          
          # Add card-img-top class to the img element
          if ($first_elem->tag eq 'picture') {
            # For picture elements, find the img inside and add the class
            my $img = $first_elem->at('img');
            if ($img) {
              my $existing_class = $img->attr('class') // '';
              unless ($existing_class =~ /card-img-top/) {
                $img->attr('class', $existing_class ? "$existing_class card-img-top" : 'card-img-top');
              }
              $card_image = $first_elem->to_string;
            }
          } else {
            # For img elements, add the class directly
            my $existing_class = $first_elem->attr('class') // '';
            unless ($existing_class =~ /card-img-top/) {
              $first_elem->attr('class', $existing_class ? "$existing_class card-img-top" : 'card-img-top');
            }
            $card_image = $first_elem->to_string;
          }
          
          # Remove the element from the DOM
          $first_elem->remove;
          
          # Get the updated HTML
          $html = $card_dom->to_string;
          $html =~ s/^[\s\r\n]+//;
          $html =~ s/[\s\r\n]+$//;
        }
      }
      if ($docpath !~ /_(.+)\.md$/) {
        if ($docpath =~ s/README\.md/index.html/) {
          $found = $docpath;
        }
        $docs->{$docpath} = {
          docpath    => $docpath,
          title      => $title,
          main       => $html,
          children   => [],
          subdocs    => [],
          url        => $url,
          language   => $options->{language},
          head       => $head,
          card_image => $card_image,
          editable   => 1
        };
      }
      if ($docs->{$docpath}) {
        $docs->{$docpath}->{src} = $datasrc;
        $docs->{$docpath}->{editable} = 1;
      }
    }
  });
  if (!$found) {
    return $docs;
  }
  
  # Add image metadata to the main document
  if ($selectedimage->{src}) {
    my $pngsrc = $selectedimage->{src};
    $pngsrc =~ s/\.(webp|jpg|jpeg|png|gif|tiff|bmp)$/.png/;
    $docs->{$found}->{head}->{meta} //= {};
    $docs->{$found}->{head}->{meta}->{property} //= {};
    $docs->{$found}->{head}->{meta}->{property}->{'og:image'} = $pngsrc;
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
    
    # Provide all available image sizes and let the browser choose
    my $srcset_webp = "${base}_150.webp 150w, ${base}_216.webp 216w, ${base}_324.webp 324w, ${base}_360.webp 360w, ${base}_432.webp 432w, ${base}_516.webp 516w, ${base}_648.webp 648w, ${base}_696.webp 696w, ${base}_744.webp 744w, ${base}_864.webp 864w, ${base}_873.webp 873w, ${base}_936.webp 936w, ${base}_1116.webp 1116w, ${base}_1296.webp 1296w";
    
    # Define sizes based on column width - calculate actual rendered sizes
    # Container width - padding (24px) = content width
    # Then multiply by column fraction
    my $sizes;
    if ($col_size == 1) {
      $sizes = "(min-width: 1400px) 108px, (min-width: 1200px) 93px, (min-width: 992px) 78px, (min-width: 768px) 58px, (min-width: 576px) 43px, 8.33vw";
    } elsif ($col_size == 2) {
      $sizes = "(min-width: 1400px) 216px, (min-width: 1200px) 186px, (min-width: 992px) 156px, (min-width: 768px) 116px, (min-width: 576px) 86px, 16.66vw";
    } elsif ($col_size == 3) {
      $sizes = "(min-width: 1400px) 324px, (min-width: 1200px) 279px, (min-width: 992px) 234px, (min-width: 768px) 174px, (min-width: 576px) 129px, 25vw";
    } elsif ($col_size == 4) {
      $sizes = "(min-width: 1400px) 432px, (min-width: 1200px) 372px, (min-width: 992px) 312px, (min-width: 768px) 232px, (min-width: 576px) 172px, 33.33vw";
    } elsif ($col_size == 5) {
      $sizes = "(min-width: 1400px) 540px, (min-width: 1200px) 465px, (min-width: 992px) 390px, (min-width: 768px) 290px, (min-width: 576px) 215px, 41.66vw";
    } elsif ($col_size == 6) {
      $sizes = "(min-width: 1400px) 648px, (min-width: 1200px) 558px, (min-width: 992px) 468px, (min-width: 768px) 348px, (min-width: 576px) 258px, 50vw";
    } elsif ($col_size == 7) {
      $sizes = "(min-width: 1400px) 756px, (min-width: 1200px) 651px, (min-width: 992px) 546px, (min-width: 768px) 406px, (min-width: 576px) 301px, 58.33vw";
    } elsif ($col_size == 8) {
      # 8-column layout (2/3 width) - browser shows 872-873px at full viewport
      $sizes = "(min-width: 1400px) 873px, (min-width: 1200px) 744px, (min-width: 992px) 624px, (min-width: 768px) 464px, (min-width: 576px) 344px, 66.66vw";
    } elsif ($col_size == 9) {
      $sizes = "(min-width: 1400px) 972px, (min-width: 1200px) 837px, (min-width: 992px) 702px, (min-width: 768px) 522px, (min-width: 576px) 387px, 75vw";
    } elsif ($col_size == 10) {
      $sizes = "(min-width: 1400px) 1080px, (min-width: 1200px) 930px, (min-width: 992px) 780px, (min-width: 768px) 580px, (min-width: 576px) 430px, 83.33vw";
    } elsif ($col_size == 11) {
      $sizes = "(min-width: 1400px) 1188px, (min-width: 1200px) 1023px, (min-width: 992px) 858px, (min-width: 768px) 638px, (min-width: 576px) 473px, 91.66vw";
    } else {
      # 12-column layout (full width)
      $sizes = "(min-width: 1400px) 1296px, (min-width: 1200px) 1116px, (min-width: 992px) 936px, (min-width: 768px) 696px, (min-width: 576px) 516px, 100vw";
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
      my $class = 'img-fluid';
      if ($img_tag =~ /class="([^"]*)"/ || $img_tag =~ /class='([^']*)'/) {
        $class = $1;
      }
      my $alt = '';
      if ($img_tag =~ /alt="([^"]*)"/ || $img_tag =~ /alt='([^']*)'/) {
        $alt = $1;
      }

      # Check if this is the selected image (above the fold)
      my $is_selected = ($img_tag =~ /id=["']selectedimage["']/) ? 1 : 0;

      # Remove src, class, and alt from the original attributes
      my $other_attrs = $img_tag;
      $other_attrs =~ s/<img\s*//;                  # Remove opening tag
      $other_attrs =~ s/\s*src="[^"]*"//g;          # Remove double-quoted src
      $other_attrs =~ s/\s*src='[^']*'//g;          # Remove single-quoted src
      $other_attrs =~ s/\s*class="[^"]*"//g;        # Remove double-quoted class
      $other_attrs =~ s/\s*class='[^']*'//g;        # Remove single-quoted class
      $other_attrs =~ s/\s*alt="[^"]*"//g;          # Remove double-quoted alt
      $other_attrs =~ s/\s*alt='[^']*'//g;          # Remove single-quoted alt
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
        sprintf("  %s<source type=\"image/webp\"\n    %ssrcset=\"%s\"\n    %ssizes=\"%s\">",
          $indent,
          $indent,
          $srcset_webp,
          $indent,
          $sizes
        ),
        sprintf("  %s%s",
          $indent,
          sprintf('<img src="%s.png"%s%s%s%s>',
            $base,
            ($class ne '') ? sprintf(' class="%s"', $class) : '',
            ($alt ne '') ? sprintf(' alt="%s"', $alt) : '',
            $is_selected ? ' fetchpriority="high"' : '',
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

# Save editable content to database with new structure
sub save_content ($self, $params) {
  my $docpath = $params->{docpath};
  my $element_id = $params->{element_id};
  my $content = $params->{content};
  my $language = $params->{language};
  my $user_id = $params->{user_id};
  
  # Get language ID from language code (languages table is in public schema)
  my $language_id = $self->database->db->query(
    'SELECT languageid FROM public.languages WHERE code = ?', 
    $language
  )->hash->{languageid} // 1;
  
  # Convert docpath to source markdown path and determine alias
  my ($alias, $markdown_src, $field_to_update, $sidecard_base);
  
  if ($element_id eq 'headline' || $element_id eq 'thecontent' || $element_id eq 'element-0') {
    # Main content: has alias, points to README.md
    $alias = $docpath;
    $markdown_src = $docpath;
    $markdown_src =~ s|^/||;  # Remove leading slash
    $markdown_src =~ s|/$||;  # Remove trailing slash
    $markdown_src = $markdown_src ? "${markdown_src}/README.md" : "README.md";
    $field_to_update = ($element_id eq 'headline') ? 'title' : 'content';
  } elsif ($element_id =~ /^(.+)-(title|content)$/) {
    # Sidecard elements: project/features-title, project/features-content
    $sidecard_base = $1;
    $alias = '';  # Sidecards have empty alias
    # The sidecard_base is already the full path without .md, just add .md
    $markdown_src = "${sidecard_base}.md";
    $field_to_update = $2 eq 'title' ? 'title' : 'content';
  } else {
    # Other elements - default to content with empty alias
    $alias = '';
    $markdown_src = $element_id;
    $field_to_update = 'content';
  }
  
  # Check if resource already exists using unique constraint (src + languageid)
  my $existing = $self->database->db->query(
    'SELECT resourceid FROM web.resources WHERE src = ? AND languageid = ?',
    $markdown_src, $language_id
  )->hash;
  
  if ($existing) {
    # Update existing resource
    my $update_sql = $field_to_update eq 'title' 
      ? 'UPDATE web.resources SET title = ?, modified = NOW() WHERE resourceid = ?'
      : 'UPDATE web.resources SET content = ?, modified = NOW() WHERE resourceid = ?';
    
    $self->database->db->query($update_sql, $content, $existing->{resourceid});
    return $existing->{resourceid};
  } else {
    # Insert new resource with authenticated user
    my $result;
    if ($field_to_update eq 'title') {
      $result = $self->database->db->query(
        'INSERT INTO web.resources (alias, src, title, owner, creator, publisher, languageid, contenttype, templateid, webserviceid) 
         VALUES (?, ?, ?, ?, ?, ?, ?, 1, 1, 1) RETURNING resourceid',
        $alias, $markdown_src, $content, $user_id, $user_id, $user_id, $language_id
      );
    } else {
      $result = $self->database->db->query(
        'INSERT INTO web.resources (alias, src, content, owner, creator, publisher, languageid, contenttype, templateid, webserviceid) 
         VALUES (?, ?, ?, ?, ?, ?, ?, 1, 1, 1) RETURNING resourceid',
        $alias, $markdown_src, $content, $user_id, $user_id, $user_id, $language_id
      );
    }
    
    my $resource_id = $result->hash->{resourceid};
    
    # If this is a sidecard, create connection to main resource in current language only
    if ($alias eq '' && $sidecard_base) {
      # Find the main resource for this docpath in current language
      my $main_alias = $docpath;
      my $main_src = $docpath;
      $main_src =~ s|^/||;  # Remove leading slash
      $main_src =~ s|/$||;  # Remove trailing slash
      $main_src = $main_src ? "${main_src}/README.md" : "README.md";
      
      my $main_resource = $self->database->db->query(
        'SELECT resourceid FROM web.resources WHERE alias = ? AND src = ? AND languageid = ?',
        $main_alias, $main_src, $language_id
      )->hash;
      
      if ($main_resource) {
        # Create connection between main resource and sidecard in current language
        $self->database->db->query(
          'INSERT INTO web.resourceconnections (parent, child) VALUES (?, ?) 
           ON CONFLICT DO NOTHING',
          $main_resource->{resourceid}, $resource_id
        );
      }
    }
    
    return $resource_id;
  }
}

# Get content from database for a specific docpath and element_id
sub get_content ($self, $docpath, $element_id, $language) {
  my $language_id = $self->database->db->query(
    'SELECT languageid FROM public.languages WHERE code = ?', 
    $language
  )->hash->{languageid} // 1;
  
  my $resource = $self->database->db->query(
    'SELECT content, modified FROM web.resources 
     WHERE alias = ? AND src = ? AND languageid = ?',
    $docpath, $element_id, $language_id
  )->hash;
  
  return $resource;
}

# Check if docpath has any database content
sub has_database_content ($self, $docpath, $language) {
  my $language_id = $self->database->db->query(
    'SELECT languageid FROM public.languages WHERE code = ?', 
    $language
  )->hash->{languageid} // 1;
  
  my $count = $self->database->db->query(
    'SELECT COUNT(*) as count FROM web.resources 
     WHERE alias = ? AND languageid = ?',
    $docpath, $language_id
  )->hash->{count};
  
  return $count > 0;
}

# Get complete document structure from database using new schema
sub get_database_content ($self, $save_docpath, $language) {
  my $language_id = $self->database->db->query(
    'SELECT languageid FROM public.languages WHERE code = ?', 
    $language
  )->hash->{languageid} // 1;
  
  # Get main resource (has alias matching save_docpath)
  my $main_resource = $self->database->db->query(
    'SELECT resourceid, src, content, title, description FROM web.resources 
     WHERE alias = ? AND languageid = ?',
    $save_docpath, $language_id
  )->hash;
  
  return {} unless $main_resource;
  
  # For non-default languages, ensure consistency by cloning missing sidecards from default
  if ($language ne $self->locale->{default_language}) {
    my $default_language_id = $self->database->db->query(
      'SELECT languageid FROM public.languages WHERE code = ?', 
      $self->locale->{default_language}
    )->hash->{languageid} // 1;
    
    # Find the default language main resource to get its sidecards
    my $default_main = $self->database->db->query(
      'SELECT resourceid FROM web.resources WHERE src = ? AND languageid = ? AND alias != \'\'',
      $main_resource->{src}, $default_language_id
    )->hash;
    
    if ($default_main) {
      $self->ensure_language_consistency($default_main->{resourceid}, $language_id, $default_language_id, $main_resource->{resourceid});
    }
  }
  
  # Get connected sidecard resources via resourceconnections
  my $sidecards = $self->database->db->query(
    'SELECT r.resourceid, r.src, r.content, r.title, r.description 
     FROM web.resources r 
     JOIN web.resourceconnections rc ON r.resourceid = rc.child 
     WHERE rc.parent = ? AND r.languageid = ? 
     ORDER BY r.src',
    $main_resource->{resourceid}, $language_id
  )->hashes;
  
  my $docs = {};
  my $subdocs = [];
  
  # Process sidecard resources
  for my $sidecard (@$sidecards) {
    push @$subdocs, {
      docpath => $sidecard->{src} =~ s|\.md$||r,  # Remove .md extension for display
      title => $sidecard->{title} || 'Untitled',
      main => $sidecard->{content} || '',
      editable => 1,
      card_image => '',
      src => $sidecard->{src}
    };
  }
  
  # Convert save_docpath back to expected docpath format
  my $display_docpath = $save_docpath;
  $display_docpath =~ s|^/||;  # Remove leading slash
  $display_docpath =~ s|/$||;  # Remove trailing slash
  $display_docpath = $display_docpath ? "${display_docpath}/index.html" : "index.html";
  
  $docs->{$display_docpath} = {
    docpath => $display_docpath,
    title => $main_resource->{title} || 'Untitled',
    main => $main_resource->{content} || '',
    subdocs => $subdocs,
    children => [],
    url => $save_docpath =~ s|^/||r =~ s|/$||r,
    language => $language,
    head => {},
    editable => 1,
    src => $main_resource->{src}
  };
  
  return $docs;
}


# Ensure sidecard consistency across languages by cloning missing resources
sub ensure_language_consistency ($self, $default_main_id, $target_language_id, $default_language_id, $target_main_id) {
  # Get all sidecards connected to main resource in default language
  my $default_sidecards = $self->database->db->query(
    'SELECT r.src, r.title, r.content, r.description, r.owner, r.creator, r.publisher, 
            r.contenttype, r.templateid, r.webserviceid
     FROM web.resources r 
     JOIN web.resourceconnections rc ON r.resourceid = rc.child 
     WHERE rc.parent = ? AND r.languageid = ?',
    $default_main_id, $default_language_id
  )->hashes;
  
  for my $default_sidecard (@$default_sidecards) {
    # Check if this sidecard exists in target language
    my $existing = $self->database->db->query(
      'SELECT resourceid FROM web.resources WHERE src = ? AND languageid = ?',
      $default_sidecard->{src}, $target_language_id
    )->hash;
    
    unless ($existing) {
      # Clone the sidecard resource for target language
      my $new_resource = $self->database->db->query(
        'INSERT INTO web.resources (alias, src, title, content, description, owner, creator, publisher, 
                                   languageid, contenttype, templateid, webserviceid) 
         VALUES (\'\', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING resourceid',
        $default_sidecard->{src},
        $default_sidecard->{title},
        $default_sidecard->{content}, 
        $default_sidecard->{description},
        $default_sidecard->{owner},
        $default_sidecard->{creator},
        $default_sidecard->{publisher},
        $target_language_id,
        $default_sidecard->{contenttype},
        $default_sidecard->{templateid},
        $default_sidecard->{webserviceid}
      );
      
      my $new_resource_id = $new_resource->hash->{resourceid};
      
      # Create connection between target main resource and new sidecard
      $self->database->db->query(
        'INSERT INTO web.resourceconnections (parent, child) VALUES (?, ?) 
         ON CONFLICT DO NOTHING',
        $target_main_id, $new_resource_id
      );
    }
  }
}

# Invalidate cache for a docpath and specific language
sub invalidate_cache ($self, $docpath, $language = undef) {
  my $public = Mojo::Home->new('public');
  $language //= $self->locale->{default_language};
  
  # Normalize docpath - remove leading slash if present
  $docpath =~ s|^/||;
  
  # For directory paths like "/project/", we need to invalidate "project/index.html"
  if ($docpath =~ m|/$| || $docpath eq '' || !($docpath =~ m|\.|)) {
    $docpath = $docpath ? "${docpath}index.html" : 'index.html';
  }
  
  # Adjust path for non-default language
  my $cache_path = $docpath;
  if ($language ne $self->locale->{default_language}) {
    $cache_path =~ s/\.html$/.$language.html/;
  }
  
  # Remove cached HTML file for this language only
  my $cache_file = $public->child($cache_path);
  $cache_file->remove if -e $cache_file;
  
  # Remove gzipped version for this language only
  my $gz_file = $public->child("${cache_path}.gz");
  $gz_file->remove if -e $gz_file;
}

1;
