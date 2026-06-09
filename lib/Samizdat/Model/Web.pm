package Samizdat::Model::Web;

use Mojo::Base -base, -signatures;
use Mojo::DOM;
use Mojo::Home;
use Text::MultiMarkdown;
use Mojo::Util qw(decode);
use YAML::XS;
use Data::Dumper;
use IPC::Open2;
use Encode ();
use Samizdat::Model::Public;

has 'config';
has 'database';
has 'locale';
has 'routes';
has 'datadir';     # mutable static-cache output base (install-aware; see MIGRATION.md A1)
has 'contentdir';  # per-site content root (manager.web.src/public; install-aware)
has 'public' => sub ($self) {
  return Samizdat::Model::Public->new(pg => $self->database);
};
has 'languages' => sub ($self) {
  # Cache the languages hash for fast lookups
  return $self->public->languages();
};

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
say $save_docpath;
  if ($self->has_database_content($save_docpath, $options->{language} // 'en')) {
    return $self->get_database_content($save_docpath, $options->{language} // 'en');
  }

  # Fall back to markdown file processing
  my $path = $self->contentdir->child($url);
  my $found = 0;
  my $selectedimage = {};
  my $requested_language = $options->{language} // $self->locale->{default_language} // 'en';
  my $default_language = $self->locale->{default_language} // 'en';
  my $using_fallback = 0;

  # Helper to process files for a given language
  my $process_files = sub ($target_lang) {
    $path->list({ dir => 0 })->sort(sub { $a cmp $b })->each(sub ($file, $num) {
      my $docpath = $file->to_rel($self->contentdir)->to_string;
      my $datasrc = $docpath;
      if ('md' eq $file->path->extname()) {
        # Only process files matching the target language
        return unless $docpath =~ /_${target_lang}\.md$/;

        my $content = decode 'UTF-8', $file->slurp;
        my $head = {};
        $self->transclude(\$content, $head, $file->dirname);
        my $html = $md->markdown($content);
        my $dom = Mojo::DOM->new->xml(0)->parse($html);
        my $title = $dom->at('h1')->text;
        $dom->at('h1')->remove;

        $dom->find('img')->each( sub ($img, $num) {
          $img->xml(0);

          # If img is the only child of a p tag (no text content), replace the p with the img
          my $parent = $img->parent;
          if ($parent && $parent->tag eq 'p' && $parent->children->size == 1) {
            my $text_content = $parent->all_text // '';
            $text_content =~ s/^\s+|\s+$//g;
            if ($text_content eq '' || $text_content eq ($img->attr('alt') // '')) {
              $parent->replace($img);
            }
          }
          # Handle p > a > img (linked images)
          elsif ($parent && $parent->tag eq 'a') {
            my $grandparent = $parent->parent;
            if ($grandparent && $grandparent->tag eq 'p' && $grandparent->children->size == 1) {
              my $text_content = $grandparent->all_text // '';
              $text_content =~ s/^\s+|\s+$//g;
              if ($text_content eq '' || $text_content eq ($img->attr('alt') // '')) {
                $grandparent->replace($parent);  # Replace p with the a>img
              }
            }
          }

          my $src = $img->attr('src');
          if ($src !~ m{^(http|https)?://} && $src !~ m{^data:} && $src !~ m{^/captcha\.}) {
            if (!exists($selectedimage->{src}) || 'selectedimage' eq ($img->attr('id') // '')) {
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

        # Strip language suffix for output path
        $docpath =~ s/_${target_lang}\.md$/.md/;

        # NOTE: Image extraction for sidecards is now done at render time in getdoc controller
        # This preserves full content for editing and database storage
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
          card_image => '',  # Extracted at render time in getdoc controller
          editable   => 1,
          using_fallback => $using_fallback,
          src        => $datasrc
        };
      }
    });
  };

  # Try requested language first
  $process_files->($requested_language);

  # If no content found and requested language differs from default, try default language
  if (!$found && $requested_language ne $default_language) {
    $using_fallback = 1;
    $process_files->($default_language);
  }

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


# Find every README_xx.md markdown file and return a hash of URIs by language
# All markdown files now require language suffix (e.g., README_en.md, README_sv.md)
sub geturis ($self, $options = {}) {
  my $uris = {};
  my $publicsrc = $self->contentdir;
  my $path = $publicsrc;
  $path->list_tree({ dir => 0 })->each(sub ($file, $num) {
    if ('md' eq $file->path->extname()) {
      my $filename = $file->to_rel($publicsrc)->to_string;
      my $size = $file->stat->size;
      # Match README_xx.md pattern (language suffix required)
      if ($filename =~ s/README_([a-z]{2})\.md$/README.md/) {
        my $lang = $1;
        $uris->{$filename}->{$lang} = $size;
      }
    }
  });
  return $uris;
}


sub transclude ($self, $contentref, $head, $dirname) {
  # Initialize nested hashes
  $head->{meta} //= {};
  $head->{meta}->{name} //= {};
  $head->{meta}->{property} //= {};
  $head->{meta}->{itemprop} //= {};

  # Try YAML front matter first (between --- markers)
  if ($$contentref =~ s/^---\s*\n(.*?)\n---\s*\n//s) {
    my $yaml_content = $1;
    my $frontmatter = eval { YAML::XS::Load($yaml_content) } // {};

    for my $key (keys %$frontmatter) {
      my $value = $frontmatter->{$key};

      if ($key eq 'description') {
        $head->{meta}->{name}->{description} = $value;
      } elsif ($key eq 'keywords') {
        # Keywords can be array or string
        $head->{meta}->{name}->{keywords} = ref $value eq 'ARRAY' ? join(', ', @$value) : $value;
      } elsif ($key eq 'title') {
        $head->{title} = $value;
      } elsif ($key =~ /^og[_:](.+)$/) {
        my $og_key = "og:$1";
        $head->{meta}->{property}->{$og_key} = $value;
      } elsif ($key =~ /^twitter[_:](.+)$/) {
        my $tw_key = "twitter:$1";
        $head->{meta}->{name}->{$tw_key} = $value;
      } elsif ($key eq 'tags') {
        # Tags as array - store as comma-separated for meta, keep array in head
        $head->{tags} = $value;
        $head->{meta}->{name}->{keywords} //= ref $value eq 'ARRAY' ? join(', ', @$value) : $value;
      } else {
        # Store other metadata directly in head (author, category, etc.)
        $head->{$key} = $value;
      }
    }
  } else {
    # Fall back to reference-style links like [key]: # "value"
    while ($$contentref =~ s/^\[([^\]]+)\]:\s*#\s*"([^"]+)"\s*$//m) {
      my $key = $1;
      my $value = $2;

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
  }

  # Process file transclusions
  $$contentref =~ s/\{\{([^{}]+)\}\}/ $self->includefile($dirname, $1) /ge;
}

sub includefile ($self, $dirname, $filename) {
  my $inclusion = Mojo::Home->new($dirname .'/')->rel_file($filename)->slurp;
  return $inclusion;
}

# ============================================================================
# MENU MANAGEMENT METHODS
# ============================================================================

# Get all menus
sub getMenus ($self) {
  return $self->database->db->select('web.menus', '*', {}, { order_by => 'menuid' })->hashes->to_array;
}

# Get a single menu by ID or name
sub getMenu ($self, $id_or_name) {
  my $where = $id_or_name =~ /^\d+$/ ? { menuid => $id_or_name } : { name => $id_or_name };
  return $self->database->db->select('web.menus', '*', $where)->hash;
}

# Add a new menu
sub addMenu ($self, $name, $websiteid = 1) {
  my $result = $self->database->db->insert('web.menus', {
    name => $name,
    websiteid => $websiteid
  }, { returning => 'menuid' });
  return $result->hash->{menuid};
}

# Update a menu
sub updateMenu ($self, $menuid, $data) {
  return $self->database->db->update('web.menus', $data, { menuid => $menuid });
}

# Delete a menu and all its items
sub deleteMenu ($self, $menuid) {
  my $db = $self->database->db;
  $db->query('DELETE FROM web.menuitemtitles WHERE menuitemid IN (SELECT menuitemid FROM web.menuitems WHERE menuid = ?)', $menuid);
  $db->delete('web.menuitems', { menuid => $menuid });
  return $db->delete('web.menus', { menuid => $menuid });
}

# Get menu items as a flat list with titles for a specific language
# Falls back to default language if translation is missing
sub getMenuItemsFlat ($self, $menuid, $languageid = 1) {
  my $default_lang = $self->languages->{$self->locale->{default_language} // 'en'} // 1;
  return $self->database->db->query(q{
    SELECT mi.menuitemid, mi.parentid, mi.position, mi.uriid, mi.menuid, mi.children,
           u.path, COALESCE(mit.title, mit_default.title) AS title
    FROM web.menuitems mi
    LEFT JOIN web.uris u ON mi.uriid = u.uriid
    LEFT JOIN web.menuitemtitles mit ON mi.menuitemid = mit.menuitemid AND mit.languageid = ?
    LEFT JOIN web.menuitemtitles mit_default ON mi.menuitemid = mit_default.menuitemid AND mit_default.languageid = ?
    WHERE mi.menuid = ?
    ORDER BY mi.position, mi.menuitemid
  }, $languageid, $default_lang, $menuid)->hashes->to_array;
}

# Get menu items as a tree structure for a specific language
sub getMenuItems ($self, $menuid, $languageid = 1) {
  my $items = $self->getMenuItemsFlat($menuid, $languageid);

  my %by_id = map { $_->{menuitemid} => $_ } @$items;
  my @roots;

  for my $item (@$items) {
    $item->{items} = [];  # child items array
    if ($item->{parentid} && exists $by_id{$item->{parentid}}) {
      push @{ $by_id{$item->{parentid}}->{items} }, $item;
    } else {
      push @roots, $item;
    }
  }

  return \@roots;
}

# Get localized menu by name or ID with language code
# Returns { menu => {...}, items => [...] } or undef if menu doesn't exist
sub getLocalizedMenu ($self, $name_or_id, $lang = undef) {
  # Get the menu
  my $menu = $self->getMenu($name_or_id);
  return undef unless $menu;

  # Resolve language code to ID
  $lang //= $self->locale->{default_language} // 'en';
  my $languageid = $self->languages->{$lang} // $self->languages->{en} // 1;

  # Get localized menu items
  my $items = $self->getMenuItems($menu->{menuid}, $languageid);

  return {
    menu  => $menu,
    items => $items
  };
}

# Get a single menu item with all its titles
sub getMenuItem ($self, $menuitemid) {
  my $item = $self->database->db->select('web.menuitems', '*', { menuitemid => $menuitemid })->hash;
  return undef unless $item;

  if ($item->{uriid}) {
    my $uri = $self->database->db->select('web.uris', 'path', { uriid => $item->{uriid} })->hash;
    $item->{path} = $uri->{path} if $uri;
  }

  $item->{titles} = $self->database->db->query(q{
    SELECT mit.languageid, l.code, mit.title
    FROM web.menuitemtitles mit
    JOIN languages l ON mit.languageid = l.languageid
    WHERE mit.menuitemid = ?
  }, $menuitemid)->hashes->to_array;

  return $item;
}

# Add a new menu item
sub addMenuItem ($self, $menuid, $data) {
  my $db = $self->database->db;

  my $uriid = undef;
  if ($data->{path}) {
    my $uri = $db->select('web.uris', 'uriid', { path => $data->{path} })->hash;
    if ($uri) {
      $uriid = $uri->{uriid};
    } else {
      my $result = $db->insert('web.uris', { path => $data->{path} }, { returning => 'uriid' });
      $uriid = $result->hash->{uriid};
    }
  }

  my $max_pos = $db->query(
    'SELECT COALESCE(MAX(position), 0) as maxpos FROM web.menuitems WHERE menuid = ? AND parentid IS NOT DISTINCT FROM ?',
    $menuid, $data->{parentid}
  )->hash->{maxpos};

  my $result = $db->insert('web.menuitems', {
    menuid => $menuid,
    parentid => $data->{parentid},
    position => $max_pos + 1,
    uriid => $uriid,
    children => 0
  }, { returning => 'menuitemid' });

  my $menuitemid = $result->hash->{menuitemid};

  if ($data->{parentid}) {
    $db->query('UPDATE web.menuitems SET children = children + 1 WHERE menuitemid = ?', $data->{parentid});
  }

  if ($data->{titles}) {
    for my $lang_key (keys %{$data->{titles}}) {
      my $languageid = $lang_key =~ /^\d+$/ ? $lang_key
        : $db->select('languages', 'languageid', { code => $lang_key })->hash->{languageid};
      $self->setMenuItemTitle($menuitemid, $languageid, $data->{titles}{$lang_key}) if $languageid;
    }
  }

  return $menuitemid;
}

# Update a menu item
sub updateMenuItem ($self, $menuitemid, $data) {
  my $db = $self->database->db;

  if (exists $data->{path}) {
    my $uriid = undef;
    if ($data->{path}) {
      my $uri = $db->select('web.uris', 'uriid', { path => $data->{path} })->hash;
      if ($uri) {
        $uriid = $uri->{uriid};
      } else {
        my $result = $db->insert('web.uris', { path => $data->{path} }, { returning => 'uriid' });
        $uriid = $result->hash->{uriid};
      }
    }
    $db->update('web.menuitems', { uriid => $uriid }, { menuitemid => $menuitemid });
  }

  if (exists $data->{parentid}) {
    my $old = $db->select('web.menuitems', 'parentid', { menuitemid => $menuitemid })->hash;
    if (($old->{parentid} // 0) != ($data->{parentid} // 0)) {
      if ($old->{parentid}) {
        $db->query('UPDATE web.menuitems SET children = children - 1 WHERE menuitemid = ?', $old->{parentid});
      }
      if ($data->{parentid}) {
        $db->query('UPDATE web.menuitems SET children = children + 1 WHERE menuitemid = ?', $data->{parentid});
      }
      $db->update('web.menuitems', { parentid => $data->{parentid} }, { menuitemid => $menuitemid });
    }
  }

  if (exists $data->{position}) {
    $db->update('web.menuitems', { position => $data->{position} }, { menuitemid => $menuitemid });
  }

  if ($data->{titles}) {
    for my $lang_key (keys %{$data->{titles}}) {
      my $languageid = $lang_key =~ /^\d+$/ ? $lang_key
        : $db->select('languages', 'languageid', { code => $lang_key })->hash->{languageid};
      $self->setMenuItemTitle($menuitemid, $languageid, $data->{titles}{$lang_key}) if $languageid;
    }
  }

  return 1;
}

# Delete a menu item and its children
sub deleteMenuItem ($self, $menuitemid) {
  my $db = $self->database->db;

  my $item = $db->select('web.menuitems', '*', { menuitemid => $menuitemid })->hash;
  return unless $item;

  my $children = $db->select('web.menuitems', 'menuitemid', { parentid => $menuitemid })->hashes;
  for my $child (@$children) {
    $self->deleteMenuItem($child->{menuitemid});
  }

  $db->delete('web.menuitemtitles', { menuitemid => $menuitemid });
  $db->delete('web.menuitems', { menuitemid => $menuitemid });

  if ($item->{parentid}) {
    $db->query('UPDATE web.menuitems SET children = children - 1 WHERE menuitemid = ?', $item->{parentid});
  }

  return 1;
}

# Reorder menu items (also handles parent changes)
sub reorderMenuItems ($self, $menuid, $order) {
  my $db = $self->database->db;
  my $pos = 0;
  for my $item (@$order) {
    # Handle both formats: [{menuitemid: 1, position: 1, parentid: 2}, ...] or [1, 2, 3, ...]
    my ($menuitemid, $position, $parentid);
    if (ref($item) eq 'HASH') {
      $menuitemid = $item->{menuitemid};
      $position = $item->{position};
      $parentid = $item->{parentid}; # may be undef for root level
    } else {
      $menuitemid = $item;
      $position = ++$pos;
      $parentid = undef;
    }

    # Get current parentid to update children counts
    my $current = $db->select('web.menuitems', ['parentid'], { menuitemid => $menuitemid })->hash;
    my $oldParentId = $current->{parentid} if $current;

    # Update position and parentid
    $db->update('web.menuitems', { position => $position, parentid => $parentid }, { menuitemid => $menuitemid, menuid => $menuid });

    # Update children counts if parent changed
    if (defined $oldParentId && (!defined $parentid || $oldParentId != $parentid)) {
      $db->query('UPDATE web.menuitems SET children = GREATEST(children - 1, 0) WHERE menuitemid = ?', $oldParentId);
    }
    if (defined $parentid && (!defined $oldParentId || $parentid != $oldParentId)) {
      $db->query('UPDATE web.menuitems SET children = children + 1 WHERE menuitemid = ?', $parentid);
    }
  }
  return 1;
}

# Get all titles for a menu item
sub getMenuItemTitles ($self, $menuitemid) {
  return $self->database->db->query(q{
    SELECT mit.languageid, l.code, mit.title
    FROM web.menuitemtitles mit
    JOIN languages l ON mit.languageid = l.languageid
    WHERE mit.menuitemid = ?
  }, $menuitemid)->hashes->to_array;
}

# Set/update a menu item title for a specific language
sub setMenuItemTitle ($self, $menuitemid, $languageid, $title) {
  my $db = $self->database->db;

  my $existing = $db->select('web.menuitemtitles', 'menuitemtitles', {
    menuitemid => $menuitemid,
    languageid => $languageid
  })->hash;

  if ($existing) {
    return $db->update('web.menuitemtitles', { title => $title }, {
      menuitemid => $menuitemid,
      languageid => $languageid
    });
  } else {
    return $db->insert('web.menuitemtitles', {
      menuitemid => $menuitemid,
      languageid => $languageid,
      title => $title
    });
  }
}

# Legacy method kept for backwards compatibility
sub menuitems ($self, $menuid = 1, $languageid = 1) {
  return $self->getMenuItems($menuid, $languageid);
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


# Save metadata to meta tables (metakeys, metavalues, metaconnections)
sub save_resource_meta ($self, $resourceid, $meta_hash, $language_id) {
  my $db = $self->database->db;

  # Clear existing metaconnections for this resource
  $db->query('DELETE FROM web.metaconnections WHERE resourceid = ?', $resourceid);

  for my $key (keys %$meta_hash) {
    my $value = $meta_hash->{$key};
    next unless defined $value && $value ne '';

    # Handle arrays (e.g., keywords, tags) - join with comma
    $value = join(', ', @$value) if ref $value eq 'ARRAY';

    # Find or create metakey
    my $metakey = $db->query(
      'SELECT metakeyid FROM web.metakeys WHERE metakey = ?', $key
    )->hash;

    my $metakeyid;
    if ($metakey) {
      $metakeyid = $metakey->{metakeyid};
    } else {
      $metakeyid = $db->query(
        'INSERT INTO web.metakeys (metakey) VALUES (?) RETURNING metakeyid', $key
      )->hash->{metakeyid};
    }

    # Find or create metavalue for this key+language
    my $metavalue = $db->query(
      'SELECT metavalueid FROM web.metavalues WHERE metakeyid = ? AND languageid = ?',
      $metakeyid, $language_id
    )->hash;

    my $metavalueid;
    if ($metavalue) {
      $metavalueid = $metavalue->{metavalueid};
      # Update the value
      $db->query(
        'UPDATE web.metavalues SET metavalue = ? WHERE metavalueid = ?',
        $value, $metavalueid
      );
    } else {
      $metavalueid = $db->query(
        'INSERT INTO web.metavalues (metavalue, metakeyid, languageid) VALUES (?, ?, ?) RETURNING metavalueid',
        $value, $metakeyid, $language_id
      )->hash->{metavalueid};
    }

    # Create metaconnection
    $db->query(
      'INSERT INTO web.metaconnections (resourceid, metavalueid) VALUES (?, ?) ON CONFLICT DO NOTHING',
      $resourceid, $metavalueid
    );
  }
}


# Get metadata from meta tables for a resource
sub get_resource_meta ($self, $resourceid, $language_id) {
  my $meta = {};

  my $rows = $self->database->db->query(q{
    SELECT mk.metakey, mv.metavalue
    FROM web.metaconnections mc
    JOIN web.metavalues mv ON mc.metavalueid = mv.metavalueid
    JOIN web.metakeys mk ON mv.metakeyid = mk.metakeyid
    WHERE mc.resourceid = ? AND mv.languageid = ?
  }, $resourceid, $language_id)->hashes;

  for my $row (@$rows) {
    $meta->{$row->{metakey}} = $row->{metavalue};
  }

  return $meta;
}


# Convert flat meta hash to nested head structure for templates
sub meta_to_head ($self, $meta) {
  my $head = {
    meta => {
      name => {},
      property => {},
      itemprop => {}
    }
  };

  for my $key (keys %$meta) {
    my $value = $meta->{$key};

    if ($key eq 'title') {
      $head->{title} = $value;
    } elsif ($key eq 'description') {
      $head->{meta}->{name}->{description} = $value;
    } elsif ($key eq 'keywords') {
      $head->{meta}->{name}->{keywords} = $value;
    } elsif ($key =~ /^og[_:](.+)$/) {
      my $og_key = "og:$1";
      $head->{meta}->{property}->{$og_key} = $value;
    } elsif ($key =~ /^twitter[_:](.+)$/) {
      my $tw_key = "twitter:$1";
      $head->{meta}->{name}->{$tw_key} = $value;
    } elsif ($key =~ /^itemprop[_:](.+)$/) {
      my $itemprop_key = $1;
      $head->{meta}->{itemprop}->{$itemprop_key} = $value;
    } elsif ($key eq 'tags') {
      $head->{tags} = $value;
      $head->{meta}->{name}->{keywords} //= $value;
    } else {
      # Store other metadata directly in head
      $head->{$key} = $value;
    }
  }

  return $head;
}


# Save editable content to database with new structure
sub save_content ($self, $params) {
  my $docpath = $params->{docpath};
  my $element_id = $params->{element_id};
  my $content = $params->{content};
  my $frontmatter = $params->{frontmatter};
  my $language = $params->{language};
  my $user_id = $params->{user_id};

  # Parse frontmatter YAML to extract metadata (saved to meta tables, not content)
  my $meta_hash = {};
  if ($frontmatter && $frontmatter =~ /\S/) {
    $frontmatter =~ s/^\s+//;
    $frontmatter =~ s/\s+$//;
    # Strip YAML delimiters if present
    $frontmatter =~ s/^---\s*\n?//;
    $frontmatter =~ s/\n?---\s*$//;
    eval {
      $meta_hash = YAML::XS::Load($frontmatter) // {};
    };
    warn "Failed to parse frontmatter YAML: $@" if $@;
  }

  # Get language ID from language code using cached languages hash
  my $language_id = $self->languages->{$language} // 1;
  
  # Convert docpath to source markdown path and determine alias
  my ($alias, $markdown_src, $field_to_update, $sidecard_base);
  
  if ($element_id eq 'headline' || $element_id eq 'thecontent' || $element_id eq 'element-0') {
    # Main content: has alias, points to README_xx.md (with language suffix)
    $alias = $docpath;
    $markdown_src = $docpath;
    $markdown_src =~ s|^/||;  # Remove leading slash
    $markdown_src =~ s|/$||;  # Remove trailing slash
    $markdown_src = $markdown_src ? "${markdown_src}/README_${language}.md" : "README_${language}.md";
    # Store complete markdown in content field
    $field_to_update = 'content';
  } elsif ($element_id =~ /^(.+)-content$/) {
    # Sidecard content - store complete markdown (including # Title)
    # Sidecard files have language suffix: 01-sidecard_en.md
    # element_id may already contain the language suffix, strip it first
    $sidecard_base = $1;
    $sidecard_base =~ s/_[a-z]{2}$//;  # Remove existing language suffix if present
    $alias = '';  # Sidecards have empty alias
    my $dir_path = $docpath;
    $dir_path =~ s|^/||;  # Remove leading slash
    $dir_path =~ s|/$||;  # Remove trailing slash
    $markdown_src = $dir_path ? "${dir_path}/${sidecard_base}_${language}.md" : "${sidecard_base}_${language}.md";
    $field_to_update = 'content';
    # Don't extract title - keep complete markdown in content field
  } else {
    # Other elements - default to content with empty alias
    $alias = '';
    $markdown_src = $element_id;
    $field_to_update = 'content';
  }
  
  # Check by src alone since language is encoded in filename (e.g., test/01-sidecard_en.md)
  my $existing = $self->database->db->query(
    'SELECT resourceid FROM web.resources WHERE src = ?',
    $markdown_src
  )->hash;

  my $resource_id;
  if ($existing) {
    # Update existing resource
    $self->database->db->query(
      'UPDATE web.resources SET content = ?, modified = NOW() WHERE resourceid = ?',
      $content, $existing->{resourceid}
    );
    $resource_id = $existing->{resourceid};
  } else {
    # Insert new resource
    my $result = $self->database->db->query(
      'INSERT INTO web.resources (alias, src, content, owner, creator, publisher, languageid, contenttype, templateid, websiteid)
       VALUES (?, ?, ?, ?, ?, ?, ?, 1, 1, 1) RETURNING resourceid',
      $alias, $markdown_src, $content, $user_id, $user_id, $user_id, $language_id
    );
    $resource_id = $result->hash->{resourceid};
  }

  # Save metadata to meta tables
  $self->save_resource_meta($resource_id, $meta_hash, $language_id) if keys %$meta_hash;

  # For sidecards, ensure connection exists
  if ($alias eq '' && $sidecard_base) {
    $self->_ensure_sidecard_connection($docpath, $resource_id, $language_id, $language);
  }

  return $resource_id;
}


# Save content to file (markdown in src/public)
sub save_content_to_file ($self, $params) {
  my $docpath = $params->{docpath};
  my $element_id = $params->{element_id};
  my $content = $params->{content};
  my $frontmatter = $params->{frontmatter};
  my $language = $params->{language};

  my $src_public = $self->contentdir;

  # Determine the file path based on element_id
  my ($markdown_src, $sidecard_base);

  if ($element_id eq 'headline' || $element_id eq 'thecontent' || $element_id eq 'element-0') {
    # Main content: points to README_xx.md (with language suffix)
    $markdown_src = $docpath;
    $markdown_src =~ s|^/||;  # Remove leading slash
    $markdown_src =~ s|/$||;  # Remove trailing slash
    $markdown_src = $markdown_src ? "${markdown_src}/README_${language}.md" : "README_${language}.md";
  } elsif ($element_id =~ /^(.+)-content$/) {
    # Sidecard content
    $sidecard_base = $1;
    $sidecard_base =~ s/_[a-z]{2}$//;  # Remove existing language suffix if present
    my $dir_path = $docpath;
    $dir_path =~ s|^/||;  # Remove leading slash
    $dir_path =~ s|/$||;  # Remove trailing slash
    $markdown_src = $dir_path ? "${dir_path}/${sidecard_base}_${language}.md" : "${sidecard_base}_${language}.md";
  } else {
    # Other elements - use element_id as filename
    my $dir_path = $docpath;
    $dir_path =~ s|^/||;
    $dir_path =~ s|/$||;
    $markdown_src = $dir_path ? "${dir_path}/${element_id}_${language}.md" : "${element_id}_${language}.md";
  }

  my $file = $src_public->child($markdown_src);

  # Ensure parent directory exists
  eval { $file->dirname->make_path };

  # Build content with frontmatter if provided
  my $file_content = $content;
  if ($frontmatter && $frontmatter =~ /\S/) {
    $frontmatter =~ s/^\s+//;
    $frontmatter =~ s/\s+$//;
    # Ensure YAML delimiters
    $frontmatter =~ s/^---\s*\n?//;
    $frontmatter =~ s/\n?---\s*$//;
    $file_content = "---\n${frontmatter}\n---\n\n${content}";
  }

  # Write to file
  eval { $file->spew(Encode::encode('UTF-8', $file_content)) };
  if ($@) {
    warn "Failed to save to file $markdown_src: $@";
    die "Failed to save to file: $@";
  }

  # Return the file path as identifier (since we're not using database)
  return $markdown_src;
}


# Helper to ensure sidecard connection exists (for UPDATE case where connection may be missing)
sub _ensure_sidecard_connection ($self, $docpath, $sidecard_resource_id, $language_id, $language = undef) {
  # Find the main resource for this docpath in current language
  # Look up language code if not provided
  $language //= $self->database->db->query(
    'SELECT code FROM languages WHERE languageid = ?', $language_id
  )->hash->{code} // 'en';

  my $main_alias = $docpath;
  my $main_src = $docpath;
  $main_src =~ s|^/||;  # Remove leading slash
  $main_src =~ s|/$||;  # Remove trailing slash
  $main_src = $main_src ? "${main_src}/README_${language}.md" : "README_${language}.md";

  my $main_resource = $self->database->db->query(
    'SELECT resourceid FROM web.resources WHERE alias = ? AND src = ? AND languageid = ?',
    $main_alias, $main_src, $language_id
  )->hash;

  if ($main_resource) {
    # Check if connection already exists
    my $existing_conn = $self->database->db->query(
      'SELECT 1 FROM web.resourceconnections WHERE parent = ? AND child = ?',
      $main_resource->{resourceid}, $sidecard_resource_id
    )->hash;

    unless ($existing_conn) {
      # Create missing connection
      $self->database->db->query(
        'INSERT INTO web.resourceconnections (parent, child) VALUES (?, ?)
         ON CONFLICT DO NOTHING',
        $main_resource->{resourceid}, $sidecard_resource_id
      );
    }
  }
}


# Get content from database for a specific docpath and element_id
sub get_content ($self, $docpath, $element_id, $language) {
  my $language_id = $self->languages->{$language} // 1;
  
  my $resource = $self->database->db->query(
    'SELECT content, modified FROM web.resources 
     WHERE alias = ? AND src = ? AND languageid = ?',
    $docpath, $element_id, $language_id
  )->hash;
  
  return $resource;
}

# Convert HTML to markdown using Pandoc (for cleaning up legacy HTML content)
sub html_to_markdown ($self, $html) {
  return '' unless $html;

  # Check if content looks like HTML (contains tags)
  return $html unless $html =~ /<[a-z][^>]*>/i;

  # Use Pandoc to convert HTML to GFM (GitHub Flavored Markdown)
  # But keep tables as HTML (they're more flexible than pipe tables)
  my $markdown = '';
  eval {
    my ($reader, $writer);
    # Use gfm-raw_html to convert most HTML but keep tables
    my $pid = open2($reader, $writer, 'pandoc', '-f', 'html', '-t', 'gfm-pipe_tables');

    # Encode to UTF-8 bytes for Pandoc
    my $html_bytes = Encode::encode('UTF-8', $html);
    print $writer $html_bytes;
    close($writer);

    # Read and decode UTF-8 bytes from Pandoc
    local $/;
    my $output_bytes = <$reader>;
    close($reader);
    waitpid($pid, 0);

    $markdown = Encode::decode('UTF-8', $output_bytes);
  };

  if ($@ || !$markdown) {
    warn "Pandoc conversion failed: $@" if $@;
    return $html;  # Return original if Pandoc fails
  }

  # Clean up Pandoc output
  $markdown =~ s/^\s+//;
  $markdown =~ s/\s+$//;

  return $markdown;
}

# Get raw source content for editing (markdown from database or files)
# Database stores markdown directly - return it for editing
sub get_source_content ($self, $docpath, $language) {
  my $language_id = $self->languages->{$language} // 1;
  my $default_language = $self->locale->{default_language} // 'en';
  my $default_language_id = $self->languages->{$default_language} // 1;
  my $using_fallback = 0;
  my $result = {
    main => { title => '', content => '', src => '', frontmatter => '' },
    sidecards => [],
    using_fallback => 0,
    target_language => $language,
    default_language => $default_language,
    has_anthropic => exists($self->config->{anthropic}) && $self->config->{anthropic}->{api_key} ? 1 : 0
  };

  # Helper to extract and strip YAML front matter (returns YAML without --- delimiters)
  my $extract_frontmatter = sub ($content) {
    return ('', $content) unless $content;
    if ($content =~ s/^---\s*\n(.*?)\n---\s*\n//s) {
      return ($1, $content);  # Return just the YAML content, no delimiters
    }
    return ('', $content);
  };

  # Helper to strip title from markdown content
  my $strip_title = sub ($content) {
    return '' unless $content;
    # Remove the first h1 heading (# Title) from content
    $content =~ s/^#\s+[^\n]+\n*//;
    $content =~ s/^\s+//;  # Trim leading whitespace
    return $content;
  };

  # First check database for markdown content
  if ($self->has_database_content($docpath, $language)) {
    my $main = $self->database->db->query(
      'SELECT resourceid, src, content FROM web.resources
       WHERE alias = ? AND languageid = ?',
      $docpath, $language_id
    )->hash;

    # Fallback to default language if not found
    if (!$main && $language ne $default_language) {
      $main = $self->database->db->query(
        'SELECT resourceid, src, content FROM web.resources
         WHERE alias = ? AND languageid = ?',
        $docpath, $default_language_id
      )->hash;
      if ($main) {
        $using_fallback = 1;
        $language_id = $default_language_id;
        $result->{using_fallback} = 1;
      }
    }

    if ($main) {
      # Content field contains markdown (without frontmatter)
      my $markdown = $main->{content} // '';

      # Extract title from markdown (first # heading)
      my ($title) = $markdown =~ /^#\s+(.+)$/m;
      $title //= '';

      # Get frontmatter from meta tables and convert to YAML (without --- delimiters)
      my $meta = $self->get_resource_meta($main->{resourceid}, $language_id);
      my $frontmatter = '';
      if (keys %$meta) {
        $frontmatter = YAML::XS::Dump($meta);
        $frontmatter =~ s/\n$//;  # Remove trailing newline from YAML::XS::Dump
      }

      $result->{main} = {
        title => $title,
        content => $strip_title->($markdown),  # Body without title for display
        markdown => $markdown,  # Complete markdown for editing
        frontmatter => $frontmatter,
        src => $main->{src} // '',
        source => 'database'
      };

      # Get sidecards from database
      my $sidecards = $self->database->db->query(
        'SELECT r.resourceid, r.src, r.content
         FROM web.resources r
         JOIN web.resourceconnections rc ON r.resourceid = rc.child
         WHERE rc.parent = ? AND r.languageid = ?
         ORDER BY r.src',
        $main->{resourceid}, $language_id
      )->hashes;

      for my $sc (@$sidecards) {
        # Content field contains complete markdown (including # Title)
        my $sc_markdown = $sc->{content} // '';

        # Extract title from markdown
        my ($sc_title) = $sc_markdown =~ /^#\s+(.+)$/m;
        $sc_title //= '';

        push @{$result->{sidecards}}, {
          title => $sc_title,
          content => $strip_title->($sc_markdown),  # Body without title for display
          markdown => $sc_markdown,  # Complete markdown for editing
          src => $sc->{src} // '',
          source => 'database'
        };
      }

      return $result;
    }
  }

  # Fall back to reading source markdown files
  my $public_src = $self->contentdir;

  # Helper to read markdown file and extract title
  my $read_markdown = sub ($src_path) {
    return undef unless $src_path;
    my $file = $public_src->child($src_path);
    return undef unless -f $file;
    my $content = decode('UTF-8', $file->slurp);
    # Extract front matter before processing
    my ($frontmatter, $body) = $extract_frontmatter->($content);
    my ($title) = $body =~ /^#\s+(.+)$/m;
    # Note: Don't convert through pandoc - file is already markdown
    return {
      title => $title // '',
      content => $strip_title->($body),
      markdown => $body,  # Full markdown including title
      frontmatter => $frontmatter
    };
  };

  my $src_path = $docpath;
  $src_path =~ s|^/||;
  $src_path =~ s|/$||;

  my $dir = $public_src->child($src_path);
  return $result unless -d $dir;

  # Read README_xx.md for main content (language suffix required)
  my $readme_path = $src_path ? "$src_path/README_${language}.md" : "README_${language}.md";
  my $md_content = $read_markdown->($readme_path);

  # Fallback to default language if not found
  my $active_language = $language;
  if (!$md_content && $language ne $default_language) {
    $readme_path = $src_path ? "$src_path/README_${default_language}.md" : "README_${default_language}.md";
    $md_content = $read_markdown->($readme_path);
    if ($md_content) {
      $using_fallback = 1;
      $active_language = $default_language;
      $result->{using_fallback} = 1;
    }
  }

  if ($md_content) {
    $result->{main} = {
      title => $md_content->{title},
      content => $md_content->{content},
      markdown => $md_content->{markdown},
      frontmatter => $md_content->{frontmatter},
      src => $readme_path,
      source => 'file'
    };
  }

  # Read other .md files as sidecards (sorted) - match current language (or fallback)
  for my $file (sort $dir->list->each) {
    my $basename = $file->basename;
    # Match files like 01-sidecard_en.md for the active language
    next unless $basename =~ /^\d+.*_${active_language}\.md$/;

    my $src = $src_path ? "$src_path/$basename" : $basename;
    my $md_content = $read_markdown->($src);
    if ($md_content) {
      push @{$result->{sidecards}}, {
        title => $md_content->{title},
        content => $md_content->{content},
        markdown => $md_content->{markdown},
        frontmatter => $md_content->{frontmatter},
        src => $src,
        source => 'file'
      };
    }
  }

  return $result;
}


# Check if docpath has any database content
sub has_database_content ($self, $docpath, $language) {
  my $language_id = $self->languages->{$language} // 1;

  # Check ONLY for the specific requested language - no fallback here
  # Fallback logic is handled in get_editable_content after checking files
  my $count = $self->database->db->query(
    'SELECT COUNT(*) as count FROM web.resources
     WHERE alias = ? AND languageid = ?',
    $docpath, $language_id
  )->hash->{count};

  return $count > 0;
}


# Convert markdown content to HTML for display
sub markdown_to_html ($self, $markdown_content) {
  return '' unless $markdown_content;

  my $html = $md->markdown($markdown_content);
  my $dom = Mojo::DOM->new->xml(0)->parse($html);

  # Process images - unwrap from p tags if only child (no text content)
  $dom->find('img')->each(sub ($img, $num) {
    $img->xml(0);
    my $parent = $img->parent;

    # Handle direct p > img
    if ($parent && $parent->tag eq 'p' && $parent->children->size == 1) {
      # Check that p has no significant text content
      my $text_content = $parent->all_text // '';
      $text_content =~ s/^\s+|\s+$//g;
      if ($text_content eq '' || $text_content eq ($img->attr('alt') // '')) {
        $parent->replace($img);
      }
    }
    # Handle p > a > img (linked images)
    elsif ($parent && $parent->tag eq 'a') {
      my $grandparent = $parent->parent;
      if ($grandparent && $grandparent->tag eq 'p' && $grandparent->children->size == 1) {
        my $text_content = $grandparent->all_text // '';
        $text_content =~ s/^\s+|\s+$//g;
        if ($text_content eq '' || $text_content eq ($img->attr('alt') // '')) {
          $grandparent->replace($parent);  # Replace p with the a>img
        }
      }
    }
  });

  $html = $dom->to_string;
  $html =~ s/^[\s\r\n]+//;
  $html =~ s/[\s\r\n]+$//;
  $html =~ s/(<\/(p|div|h[1-6]|ul|ol|li|blockquote|section|article|aside|nav|header|footer|pre)>)/$1\n/gi;

  return $html;
}

# Get complete document structure from database using new schema
# Database stores markdown - convert to HTML for display
sub get_database_content ($self, $save_docpath, $language) {
  my $language_id = $self->languages->{$language} // 1;
  my $default_language = $self->locale->{default_language} // 'en';
  my $default_language_id = $self->languages->{$default_language} // 1;
  my $using_fallback = 0;

  # Get main resource (has alias matching save_docpath)
  # Title and description are extracted from markdown content, not stored separately
  my $main_resource = $self->database->db->query(
    'SELECT resourceid, src, content FROM web.resources
     WHERE alias = ? AND languageid = ?',
    $save_docpath, $language_id
  )->hash;

  # Fallback to default language if not found
  if (!$main_resource && $language ne $default_language) {
    $main_resource = $self->database->db->query(
      'SELECT resourceid, src, content FROM web.resources
       WHERE alias = ? AND languageid = ?',
      $save_docpath, $default_language_id
    )->hash;
    if ($main_resource) {
      $using_fallback = 1;
      $language_id = $default_language_id;
    }
  }

  return {} unless $main_resource;

  # For non-default languages, ensure consistency by cloning missing sidecards from default
  if ($language ne $self->locale->{default_language}) {
    my $default_language_id = $self->languages->{$self->locale->{default_language}} // 1;

    # Find the default language main resource to get its sidecards
    my $default_main = $self->database->db->query(
      'SELECT resourceid FROM web.resources WHERE src = ? AND languageid = ? AND alias != \'\'',
      $main_resource->{src}, $default_language_id
    )->hash;

    if ($default_main) {
      $self->ensure_language_consistency($default_main->{resourceid}, $language_id, $default_language_id, $main_resource->{resourceid});
    }
  }

  # Helper to extract title from markdown
  my $extract_title = sub ($markdown) {
    return 'Untitled' unless $markdown;
    my ($title) = $markdown =~ /^#\s+(.+)$/m;
    return $title // 'Untitled';
  };

  # Helper to strip title from markdown for body content
  my $strip_md_title = sub ($markdown) {
    return '' unless $markdown;
    $markdown =~ s/^#\s+[^\n]+\n*//;
    $markdown =~ s/^\s+//;
    return $markdown;
  };

  # Get connected sidecard resources via resourceconnections
  my $sidecards = $self->database->db->query(
    'SELECT r.resourceid, r.src, r.content
     FROM web.resources r
     JOIN web.resourceconnections rc ON r.resourceid = rc.child
     WHERE rc.parent = ? AND r.languageid = ?
     ORDER BY r.src',
    $main_resource->{resourceid}, $language_id
  )->hashes;

  my $docs = {};
  my $subdocs = [];

  # Process sidecard resources - extract title from markdown, convert to HTML
  for my $sidecard (@$sidecards) {
    my $sc_markdown = $sidecard->{content} // '';
    push @$subdocs, {
      docpath => $sidecard->{src} =~ s|\.md$||r,  # Remove .md extension for display
      title => $extract_title->($sc_markdown),
      main => $self->markdown_to_html($strip_md_title->($sc_markdown)),
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

  # Get main content markdown
  my $main_markdown = $main_resource->{content} // '';

  # Get metadata from meta tables and convert to head format
  my $meta = $self->get_resource_meta($main_resource->{resourceid}, $language_id);
  my $head = $self->meta_to_head($meta);

  # Set canonical URL - always points to the page in default language
  my $url_path = $save_docpath =~ s|^/||r =~ s|/$||r;
  my $siteurl = $self->config->{siteurl} // '';
  my $baseurl = $self->config->{baseurl} // '';
  my $canonical = "${siteurl}${baseurl}/${url_path}";
  $canonical =~ s|([^:])//+|$1/|g;  # Remove double slashes (but keep :// for protocol)
  $head->{canonical} = $canonical;

  $docs->{$display_docpath} = {
    docpath => $display_docpath,
    title => $head->{title} // $extract_title->($main_markdown),
    main => $self->markdown_to_html($strip_md_title->($main_markdown)),
    subdocs => $subdocs,
    children => [],
    url => $url_path,
    language => $language,
    head => $head,
    editable => 1,
    using_fallback => $using_fallback,
    src => $main_resource->{src}
  };

  return $docs;
}


# Ensure sidecard consistency across languages by cloning missing resources
sub ensure_language_consistency ($self, $default_main_id, $target_language_id, $default_language_id, $target_main_id) {
  # Get target language code
  my $target_lang = $self->database->db->query(
    'SELECT code FROM languages WHERE languageid = ?', $target_language_id
  )->hash->{code} // 'en';

  my $default_lang = $self->database->db->query(
    'SELECT code FROM languages WHERE languageid = ?', $default_language_id
  )->hash->{code} // 'en';

  # Get all sidecards connected to main resource in default language
  my $default_sidecards = $self->database->db->query(
    'SELECT r.src, r.content, r.owner, r.creator, r.publisher,
            r.contenttype, r.templateid, r.websiteid
     FROM web.resources r
     JOIN web.resourceconnections rc ON r.resourceid = rc.child
     WHERE rc.parent = ? AND r.languageid = ?',
    $default_main_id, $default_language_id
  )->hashes;

  for my $default_sidecard (@$default_sidecards) {
    # Convert src from default language to target language
    # e.g., 01-sidecard_en.md -> 01-sidecard_sv.md
    my $target_src = $default_sidecard->{src};
    $target_src =~ s/_${default_lang}\.md$/_${target_lang}.md/;

    # Check if this sidecard exists in target language
    my $existing = $self->database->db->query(
      'SELECT resourceid FROM web.resources WHERE src = ? AND languageid = ?',
      $target_src, $target_language_id
    )->hash;

    unless ($existing) {
      # Clone the sidecard resource for target language with correct src
      my $new_resource = $self->database->db->query(
        'INSERT INTO web.resources (alias, src, content, owner, creator, publisher,
                                   languageid, contenttype, templateid, websiteid)
         VALUES (\'\', ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING resourceid',
        $target_src,
        $default_sidecard->{content},
        $default_sidecard->{owner},
        $default_sidecard->{creator},
        $default_sidecard->{publisher},
        $target_language_id,
        $default_sidecard->{contenttype},
        $default_sidecard->{templateid},
        $default_sidecard->{websiteid}
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
  my $public = $self->datadir // Mojo::Home->new('public');
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


# File tree operations for content management

sub filetree_list ($self, $path = '') {
  my $src_public = $self->contentdir;

  # Sanitize path - prevent directory traversal
  $path =~ s|^/+||;
  $path =~ s|\.\./||g;

  my $dir = $path ? $src_public->child($path) : $src_public;

  return { success => 0, error => 'Directory not found' } unless -d $dir;

  my @items;
  my $languages = $self->locale->{languages} // {};
  my @lang_codes = keys %$languages;

  $dir->list({dir => 1})->each(sub ($file, $num) {
    my $name = $file->basename;

    # Skip hidden files
    return if $name =~ /^\./;

    my $rel_path = $path ? "$path/$name" : $name;
    my $is_dir = -d $file;

    if ($is_dir) {
      # Check if directory has children
      my $has_children = $file->list({dir => 1})->size > 0;

      # Check which README_xx.md languages exist in this directory
      my @readme_langs;
      for my $lang (@lang_codes) {
        my $readme = $file->child("README_${lang}.md");
        push @readme_langs, $lang if -f $readme;
      }

      push @items, {
        name => $name,
        path => $rel_path,
        type => 'directory',
        hasChildren => $has_children ? \1 : \0,
        readmeLanguages => \@readme_langs,
      };
    } else {
      # For markdown files with language suffix, group by base name
      if ($name =~ /^(.+)_([a-z]{2})\.md$/) {
        my ($base, $lang) = ($1, $2);
        # Find existing item for this base name or create new
        my ($existing) = grep { $_->{name} eq $base && $_->{type} eq 'file' } @items;
        if ($existing) {
          push @{$existing->{languages}}, $lang;
        } else {
          push @items, {
            name => $base,
            path => $rel_path,
            type => 'file',
            hasChildren => \0,
            languages => [$lang],
          };
        }
      }
      # Show other files too (images, etc.)
      elsif ($name !~ /^\./) {
        push @items, {
          name => $name,
          path => $rel_path,
          type => 'file',
          hasChildren => \0,
        };
      }
    }
  });

  # Sort: directories first, then alphabetically
  @items = sort {
    ($a->{type} eq 'directory' ? 0 : 1) <=> ($b->{type} eq 'directory' ? 0 : 1)
    || $a->{name} cmp $b->{name}
  } @items;

  return {
    success => 1,
    path => $path,
    items => \@items,
  };
}


sub filetree_create ($self, $path, $type, $language = undef, $target = 'file') {
  my $src_public = $self->contentdir;

  # Sanitize path
  $path =~ s|^/+||;
  $path =~ s|\.\./||g;

  return { success => 0, error => 'Invalid path' } unless $path;

  if ($type eq 'directory') {
    my $dir = $src_public->child($path);
    return { success => 0, error => 'Directory already exists' } if -e $dir;

    eval { $dir->make_path };
    return { success => 0, error => "Failed to create directory: $@" } if $@;

    return { success => 1, message => 'Directory created', path => $path };
  }
  elsif ($type eq 'file') {
    # Main content - always README_xx.md
    $language //= $self->locale->{default_language} // 'en';

    # Path is the folder, filename is always README_xx.md
    $path =~ s|/$||;
    my $alias = $path ? "/$path/" : "/";
    my $filename = $path ? "${path}/README_${language}.md" : "README_${language}.md";

    # Default content for new page
    my $content = "---\ntitle: New Page\ndescription: \n---\n\n# New Page\n\nContent goes here.\n";

    return $self->_create_content($src_public, $filename, $alias, $content, $language, $target);
  }
  elsif ($type eq 'sidecard') {
    # Side content - NN-name_xx.md
    $language //= $self->locale->{default_language} // 'en';

    # Strip any suffix patterns from the base name
    my $basename = $path;
    $basename =~ s|.*/||;  # Get just the filename part
    $basename =~ s/(_[a-z]{2})?\.md$//;  # Strip _xx.md or .md
    $basename =~ s/_[a-z]{2}$//;  # Strip _xx

    # Get directory part
    my $dir_part = $path;
    $dir_part =~ s|/[^/]+$|| or $dir_part = '';

    my $filename = $dir_part ? "${dir_part}/${basename}_${language}.md" : "${basename}_${language}.md";
    my $alias = '';  # Sidecards have empty alias

    # Default content for sidecard
    my $content = "# Side Content\n\nContent goes here.\n";

    return $self->_create_content($src_public, $filename, $alias, $content, $language, $target);
  }

  return { success => 0, error => 'Invalid type' };
}

# Helper to create content in file or database
sub _create_content ($self, $src_public, $filename, $alias, $content, $language, $target) {
  if ($target eq 'database') {
    my $language_id = $self->languages->{$language} // 1;

    # Check if already exists in database
    my $existing = $self->database->db->query(
      'SELECT resourceid FROM web.resources WHERE src = ?',
      $filename
    )->hash;
    return { success => 0, error => 'Resource already exists in database' } if $existing;

    # Insert new resource
    eval {
      $self->database->db->query(
        'INSERT INTO web.resources (alias, src, content, languageid, contenttype, templateid, websiteid)
         VALUES (?, ?, ?, ?, 1, 1, 1) RETURNING resourceid',
        $alias, $filename, $content, $language_id
      );
    };
    return { success => 0, error => "Failed to create in database: $@" } if $@;

    return { success => 1, message => 'Created in database', path => $filename, target => 'database' };
  }
  else {
    # Save to file (default behavior)
    my $file = $src_public->child($filename);
    return { success => 0, error => 'File already exists' } if -e $file;

    # Ensure parent directory exists
    eval { $file->dirname->make_path };

    eval { $file->spew(Encode::encode('UTF-8', $content)) };
    return { success => 0, error => "Failed to create file: $@" } if $@;

    return { success => 1, message => 'File created', path => $filename, target => 'file' };
  }
}


sub filetree_rename ($self, $old_path, $new_path) {
  my $src_public = $self->contentdir;

  # Sanitize paths
  $old_path =~ s|^/+||;
  $old_path =~ s|\.\./||g;
  $new_path =~ s|^/+||;
  $new_path =~ s|\.\./||g;

  return { success => 0, error => 'Invalid paths' } unless $old_path && $new_path;

  my $old_file = $src_public->child($old_path);
  my $new_file = $src_public->child($new_path);

  return { success => 0, error => 'Source not found' } unless -e $old_file;
  return { success => 0, error => 'Destination already exists' } if -e $new_file;

  # Ensure parent directory exists
  eval { $new_file->dirname->make_path };

  eval { rename($old_file->to_string, $new_file->to_string) or die $! };
  return { success => 0, error => "Failed to rename: $@" } if $@;

  return { success => 1, message => 'Renamed successfully' };
}


sub filetree_delete ($self, $path) {
  my $src_public = $self->contentdir;

  # Sanitize path
  $path =~ s|^/+||;
  $path =~ s|\.\./||g;

  return { success => 0, error => 'Invalid path' } unless $path;
  return { success => 0, error => 'Cannot delete root' } if $path eq '' || $path eq '/';

  my $target = $src_public->child($path);
  return { success => 0, error => 'Not found' } unless -e $target;

  if (-d $target) {
    # Check if directory is empty (only allow deleting empty dirs for safety)
    my $count = $target->list->size;
    return { success => 0, error => 'Directory not empty' } if $count > 0;

    eval { rmdir($target->to_string) or die $! };
    return { success => 0, error => "Failed to delete directory: $@" } if $@;
  } else {
    eval { unlink($target->to_string) or die $! };
    return { success => 0, error => "Failed to delete file: $@" } if $@;
  }

  return { success => 1, message => 'Deleted successfully' };
}

1;
