package Samizdat::Controller::Web;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::DOM;
use Mojo::JSON qw(encode_json);

# Render site management panel
sub index ($self) {
  my $docpath = $self->stash('docpath');
  my $title = $self->app->__('Site content');

  if ($self->req->headers->accept =~ m{application/json}) {
    # Require admin access for JSON page listings
    return unless $self->access({ admin => 1 });

    my $searchterm = $self->param('searchterm') // undef;
    $self->render(json => {
      pages => $self->app->web->geturis({
        searchterm => $searchterm,
        language   => $self->_get_content_language(),
        languages  => $self->config->{locale}->{languages},
      })
    });
  } else {
    my $web = {
      docpath => $docpath,
      title   => $title,
      head    => {
        title => $title,
        meta => {
          name => {
            description => $self->app->__('Site content'),
            keywords    => [ "manage", "site" ]
          }
        }
      }
    };
    $web->{script} .= $self->render_to_string(template => 'web/index', format => 'js');
    $web->{css} .= $self->render_to_string(template => 'web/tree', format => 'css');
    $self->render(template => 'web/index', web => $web, title => $title, headline => 'web/chunks/headline');
  }
}


sub pass ($self) {
  return 1;
}


sub editor ($self) {
  my $docpath = $self->stash('docpath');
  my $content_language = $self->_get_content_language();
  my $docs = $self->app->web->getlist($docpath, {
    language => $content_language,
    languages => $self->config->{locale}->{languages},
  });
  if (!exists($docs->{$docpath})) {
    $self->stash('status', 404);
    return $self->reply->not_found;
  }
  my $title = $self->app->__x("Edit page {docpath}", docpath => '/' . $docpath);
  my $web = $docs->{$docpath};

  # Convert <picture> back to simple <img> for editing
  _simplify_pictures_for_editing(\$web->{main}) if $web->{main};
  for my $subdoc (@{ $web->{subdocs} // [] }) {
    _simplify_pictures_for_editing(\$subdoc->{main}) if $subdoc->{main};
  }

  $web->{script} .= $self->render_to_string(template => 'web/edit', format => 'js');
  $web->{css} .= $self->render_to_string(template => 'web/edit', format => 'css');
  $self->stash(web => $web, docpath => $web->{docpath}, title => $title);
  $self->render(template => 'web/edit', headline => 'web/chunks/headline');
}


sub languages ($self) {
  my $languages = $self->public->getLanguages($self->config->{locale}->{languages});
  $self->render(json => { languages => $languages });
}


# Menu management - list all menus or create new menu
sub menus ($self) {
  if ($self->req->headers->accept =~ m{application/json}) {
    return unless $self->access({ admin => 1 });

    if ($self->req->method eq 'POST') {
      # Create new menu
      my $data = $self->req->json;
      my $name = $data->{name};
      my $webserviceid = $data->{webserviceid} // 1;

      unless ($name) {
        return $self->render(json => { success => 0, error => 'Menu name is required' }, status => 400);
      }

      my $menuid = $self->app->web->addMenu($name, $webserviceid);
      return $self->render(json => { success => 1, menuid => $menuid });
    }

    # GET - list menus
    my $menus = $self->app->web->getMenus();
    $self->render(json => { menus => $menus });
  } else {
    # HTML page loads first, then JS makes authenticated API calls
    my $title = $self->app->__('Menus');
    my $docpath = $self->url_for('web_menus')->to_string;
    $docpath =~ s|^/||;  # Remove leading slash
    $docpath .= '/index.html';
    $self->stash(docpath => $docpath);
    my $web = {
      title   => $title,
      head    => { title => $title }
    };
    $web->{script} = $self->render_to_string(template => 'web/menus/index', format => 'js');
    $self->render(template => 'web/menus/index', web => $web, title => $title);
  }
}


# Single menu editor - view/update menu and its items
sub menu ($self) {
  my $menuid = $self->stash('menuid');

  if ($self->req->headers->accept =~ m{application/json}) {
    return unless $self->access({ admin => 1 });

    if ($self->req->method eq 'POST') {
      # Update menu
      my $data = $self->req->json;
      $self->app->web->updateMenu($menuid, $data);
      return $self->render(json => { success => 1 });
    }

    if ($self->req->method eq 'DELETE') {
      # Delete menu
      $self->app->web->deleteMenu($menuid);
      return $self->render(json => { success => 1 });
    }

    # GET - single menu with items
    my $menu = $self->app->web->getMenu($menuid);
    unless ($menu) {
      return $self->render(json => { success => 0, error => 'Menu not found' }, status => 404);
    }

    my $languageid = $self->param('languageid') // 1;
    my $items = $self->app->web->getMenuItems($menuid, $languageid);
    my $languages = $self->public->getLanguages($self->config->{locale}->{languages});

    $self->render(json => {
      menu      => $menu,
      items     => $items,
      languages => $languages
    });
  } else {
    # HTML page loads first, then JS makes authenticated API calls
    my $menu = $self->app->web->getMenu($menuid);
    unless ($menu) {
      return $self->reply->not_found;
    }

    my $title = $self->app->__x('Edit menu: {name}', name => $menu->{name});
    my $docpath = $self->url_for('web_menus')->to_string;
    $docpath =~ s|^/||;  # Remove leading slash
    $docpath .= '/menu/index.html';  # Generic path without menu ID
    $self->stash(docpath => $docpath);
    my $web = {
      title   => $title,
      head    => { title => $title }
    };
    $web->{script} = $self->render_to_string(template => 'web/menus/menu/index', format => 'js');
    $web->{css} = $self->render_to_string(template => 'web/menus/menu/index', format => 'css');
    $self->render(template => 'web/menus/menu/index', web => $web, title => $title, menu => $menu);
  }
}


# Menu item editor - view/create/update/delete menu item
sub menuitem ($self) {
  my $menuid = $self->stash('menuid');
  my $menuitemid = $self->stash('menuitemid');

  if ($self->req->headers->accept =~ m{application/json}) {
    return unless $self->access({ admin => 1 });

    if ($self->req->method eq 'DELETE') {
      # Delete menu item - must have valid ID
      return $self->render(json => { success => 0, error => 'Invalid menu item' }, status => 400)
        unless $menuitemid && $menuitemid ne 'new';
      $self->app->web->deleteMenuItem($menuitemid);
      return $self->render(json => { success => 1 });
    }

    if ($self->req->method eq 'POST') {
      my $data = $self->req->json;

      if (!$menuitemid || $menuitemid eq 'new') {
        # Create new menu item
        $data->{menuid} = $menuid;
        my $newid = $self->app->web->addMenuItem($menuid, $data);
        return $self->render(json => { success => 1, menuitemid => $newid });
      } else {
        # Update existing menu item
        $self->app->web->updateMenuItem($menuitemid, $data);
        return $self->render(json => { success => 1 });
      }
    }

    # GET - single item with all titles
    my $languages = $self->public->getLanguages($self->config->{locale}->{languages});
    my $languageid = $languages->[0]{languageid} // 1;
    my $allItems = $self->app->web->getMenuItemsFlat($menuid, $languageid);

    if (!$menuitemid || $menuitemid eq 'new') {
      return $self->render(json => {
        item      => { menuid => $menuid },
        titles    => [],
        languages => $languages,
        allItems  => $allItems
      });
    }

    my $item = $self->app->web->getMenuItem($menuitemid);
    unless ($item) {
      return $self->render(json => { success => 0, error => 'Menu item not found' }, status => 404);
    }

    my $titles = $self->app->web->getMenuItemTitles($menuitemid);

    $self->render(json => {
      item      => $item,
      titles    => $titles,
      languages => $languages,
      allItems  => $allItems
    });
  } else {
    # HTML page loads first, then JS makes authenticated API calls
    my $menu = $self->app->web->getMenu($menuid);
    unless ($menu) {
      return $self->reply->not_found;
    }

    my $item = {};
    my $title;
    if (!$menuitemid || $menuitemid eq 'new') {
      $title = $self->app->__('New menu item');
      $item = { menuid => $menuid };
    } else {
      $item = $self->app->web->getMenuItem($menuitemid);
      unless ($item) {
        return $self->reply->not_found;
      }
      $title = $self->app->__x('Edit menu item: {id}', id => $menuitemid);
    }

    my $docpath = $self->url_for('web_menus')->to_string;
    $docpath =~ s|^/||;  # Remove leading slash
    $docpath .= '/menu/item/index.html';  # Generic path without menu/item IDs
    $self->stash(docpath => $docpath);
    my $web = {
      title   => $title,
      head    => { title => $title }
    };
    $web->{script} = $self->render_to_string(template => 'web/menus/item/index', format => 'js');
    $self->render(template => 'web/menus/item/index', web => $web, title => $title, menu => $menu, item => $item);
  }
}


# Reorder menu items
sub menuitems_reorder ($self) {
  return unless $self->access({ admin => 1 });

  my $menuid = $self->stash('menuid');
  my $data = $self->req->json;
  my $order = $data->{order};

  unless ($order && ref($order) eq 'ARRAY') {
    return $self->render(json => { success => 0, error => 'Order array is required' }, status => 400);
  }

  $self->app->web->reorderMenuItems($menuid, $order);
  $self->render(json => { success => 1 });
}


# This is the main entry point for all web pages that sit in the src/public directory.
# It will also try to lookup the uri in the database.
sub getdoc ($self) {
  my $docpath = $self->stash('docpath');

  # Handle image requests - skip document lookup, let after_render handle conversion
  if ($docpath =~ /\.(webp|png|jpg|jpeg|gif|svg|ico)$/i) {
    $self->stash(web => { url => "/$docpath" });
    return $self->render(data => '', status => 404);
  }

  # Normalize: ensure trailing slash for non-empty docpath (but not for files)
  $docpath .= '/' if $docpath ne '' && $docpath !~ m|/$|;
  my $html = $self->app->__x("The page {docpath} wasn't found.", docpath => '/' . $docpath);
  my $title = $self->app->__('404: Missing document');

  # Check for language query parameter (for editing specific language versions)
  my $content_language = $self->_get_content_language();

  my $docs = $self->app->web->getlist($docpath, {
    language => $content_language,
    languages => $self->config->{locale}->{languages},
  });
  my $path = sprintf("%s%s", $docpath, 'index.html');
  if (!exists($docs->{$path})) {
    banbot($docpath, $self->getip);
    $path = '404.html';
    $self->stash('status', 404);
    $docs->{'404.html'} = {
      url         => $docpath,
      docpath     => '404.html',
      title       => $title,
      main        => $html,
      children    => [],
      subdocs     => [],
      head        => {
        title => $title,
        meta => {
          name => {
            description => $self->app->__('Missing file, our bad?'),
            keywords    => ["error","404"]
          }
        }
      },
      language => $self->app->language
    };
    if ($docpath !~ /\.(webp)$/) {
      $self->stash('docpath', '/404.html');
      return $self->reply->not_found;
    }
  } else {
    # Canonical URLs and meta tags are now set automatically by before_render hook in Web plugin
    # $docs->{$path}->{canonical} = sprintf('%s%s%s', $self->config->{siteurl}, $self->config->{baseurl}, $docpath);
    # $docs->{$path}->{head}->{meta}->{property}->{'og:title'} = $docs->{$path}->{title};
    # $docs->{$path}->{head}->{meta}->{property}->{'og:url'} = $docs->{$path}->{canonical};
    # $docs->{$path}->{head}->{meta}->{property}->{'og:canonical'} = $docs->{$path}->{canonical};
    # $docs->{$path}->{head}->{meta}->{name}->{'twitter:url'} = $docs->{$path}->{canonical};
    # $docs->{$path}->{head}->{meta}->{name}->{'twitter:title'} = $docs->{$path}->{title};
    # $docs->{$path}->{head}->{meta}->{itemprop}->{'name'} = $docs->{$path}->{title};
    # if (exists $docs->{$path}->{head}->{meta}->{name}->{description}) {
    #   $docs->{$path}->{head}->{meta}->{property}->{'og:description'} = $docs->{$path}->{head}->{meta}->{name}->{description};
    #   $docs->{$path}->{head}->{meta}->{name}->{'twitter:description'} = $docs->{$path}->{head}->{meta}->{name}->{description};
    #   $docs->{$path}->{head}->{meta}->{itemprop}->{'description'} = $docs->{$path}->{head}->{meta}->{name}->{description};
    # }
    if ($#{$docs->{$path}->{subdocs}} > -1) {
      my $sidebar = '';
      for my $subdoc (sort {$a->{docpath} cmp $b->{docpath}} @{ $docs->{$path}->{subdocs} }) {
        # Extract first image for card display (at render time, preserving full content for editing)
        _extract_card_image($subdoc);
        $sidebar .= $self->render_to_string(template => 'chunks/sidecard', card => $subdoc);
      }
      $docs->{$path}->{sidebar} = $sidebar;
    }
    $self->stash(headline => 'chunks/sharebuttons');
  }
  $self->stash(web => $docs->{$path}, docpath => $docs->{$path}->{docpath}, format => 'html');
  $self->stash(title => $docs->{$path}->{title} // $title);
  $self->render();
}


sub manifest ($self) {
  my $icons = [{
    src   => '/favicon.ico',
    sizes => '16x16 32x32 48x48 64x64'
  }];
  for my $size (@{ $self->config->{icons}->{sizes} }) {
    my $src = sprintf('/media/images/icon.%04d.png', $size);
    push @{ $icons }, {
      src     => $src,
      sizes   => sprintf('%dx%d', $size, $size),
      type    => 'image/png',
      purpose => 'maskable'
    };
  }
  push @{ $icons }, {
    src     => '/' . $self->config->{logotype},
    sizes   => 'any',
    type    => 'image/svg',
    purpose => 'any'
  };

  my $manifest = encode_json {
    manifest_version   => "2",
    name             => $self->config->{sitename},
    short_name       => $self->config->{shortsitename},
    start_url        => $self->config->{siteurl},
    display          => 'standalone',
    orientation      => 'any',
    scope            => $self->config->{siteurl},
    background_color => $self->config->{backgroundcolor},
    theme_color      => $self->config->{themecolor},
    description      => $self->config->{description},
    icons            => $icons,
    default_locale   => $self->config->{locale}->{default_language},
    screenshots      => $self->config->{screenshots}
  };

  # Slashes get escaped in Mojo::JSON. Undo that!
  $manifest =~ s/\\//g;

  $self->render(text => $manifest, docpath => 'manifest.json', web => {}, format => 'json');
}

sub robots ($self) {
  $self->render(text => $self->config->{robots}, docpath => 'robots.txt', format => 'txt');
}

sub humans ($self) {
  $self->render(text => $self->config->{humans}, docpath => 'humans.txt', format => 'txt');
}

sub ads ($self) {
  $self->render(text => $self->config->{ads}, docpath => 'ads.txt', format => 'txt');
}

# Service Worker routes configuration
# Returns JSON with route patterns for client-side caching
sub sw_routes ($self) {
  my $config = $self->config;
  my $manager_url = $config->{manager}->{url} || '/manager/';
  $manager_url =~ s|^/||;
  $manager_url =~ s|/$||;

  # Build routes from config or use defaults
  my $sw_config = $config->{serviceworker} || {};
  my @routes;

  # Get registered routes from config
  if ($sw_config->{routes}) {
    for my $route (@{$sw_config->{routes}}) {
      # Replace {manager} placeholder with actual manager URL
      my $pattern = $route->{pattern};
      my $cache_path = $route->{cachePath};
      $pattern =~ s/\{manager\}/$manager_url/g;
      $cache_path =~ s/\{manager\}/$manager_url/g;

      push @routes, {
        pattern    => $pattern,
        cachePath  => $cache_path,
        revalidate => $route->{revalidate} // 0,
      };
    }
  }

  $self->render(json => {
    routes          => \@routes,
    defaultLanguage => $config->{locale}->{default_language} || 'en',
    precache        => $sw_config->{precache} || [],
    version         => $sw_config->{version} || 1,
  });
}

# Service Worker JavaScript
# Renders the sw.js template (plain JS, no EP syntax)
# In production, nginx serves the static file generated by makeswcache
sub sw_js ($self) {
  $self->res->headers->content_type('application/javascript');
  $self->res->headers->header('Service-Worker-Allowed' => '/');
  $self->render(template => 'sw', format => 'js');
}

# Gather exploiting bots
sub banbot ($docpath, $ip) {
  if ($docpath =~ /(
    xmlrpc.php |
    wp-login.php |
    wp-admin
  )/ixx) {
    say sprintf("%s\t%s\t%s", time, $ip, $docpath);
  }
}

# Convert <picture> elements back to simple <img> for editing
# This reverses the tidyup transformation so editors work with simple img tags
sub _simplify_pictures_for_editing ($htmlref) {
  return unless $$htmlref;

  my $dom = Mojo::DOM->new($$htmlref);
  my $modified = 0;

  $dom->find('picture')->each(sub ($picture, $num) {
    my $img = $picture->at('img');
    if ($img) {
      # Remove card-img-top class if present (will be re-added at display time)
      my $class = $img->attr('class') // '';
      $class =~ s/\bcard-img-top\b//g;
      $class =~ s/^\s+|\s+$//g;
      $class =~ s/\s+/ /g;
      $img->attr('class', $class) if $class;
      $img->attr('class', undef) unless $class;

      # Replace <picture> with just the <img>
      $picture->replace($img);
      $modified = 1;
    }
  });

  if ($modified) {
    $$htmlref = $dom->to_string;
  }
}


# Extract first image from subdoc content for card display
# Modifies subdoc in place: sets card_image and removes image from main
sub _extract_card_image ($subdoc) {
  return unless $subdoc->{main};

  my $dom = Mojo::DOM->new($subdoc->{main});
  my $first_elem = $dom->children->first;
  return unless $first_elem && $first_elem->tag;

  my $image_elem;   # The img/picture element (for adding card-img-top class)
  my $store_elem;   # What to store in card_image (may include link wrapper)

  # Check if first element is directly a picture or img
  if ($first_elem->tag eq 'picture' || $first_elem->tag eq 'img') {
    $image_elem = $first_elem;
    $store_elem = $first_elem;
  }
  # Check if first element is a linked image (a > img or a > picture)
  elsif ($first_elem->tag eq 'a') {
    my $a_children = $first_elem->children;
    if ($a_children->size == 1) {
      my $child = $a_children->first;
      if ($child && $child->tag && ($child->tag eq 'picture' || $child->tag eq 'img')) {
        $image_elem = $child;
        $store_elem = $first_elem;  # Store the full link with image
      }
    }
  }
  # Also check if first element is a <p> containing only an image
  elsif ($first_elem->tag eq 'p') {
    my $p_children = $first_elem->children;
    if ($p_children->size == 1) {
      my $child = $p_children->first;
      if ($child && $child->tag) {
        if ($child->tag eq 'picture' || $child->tag eq 'img') {
          # Check that p has no significant text content
          my $text_content = $first_elem->all_text // '';
          $text_content =~ s/^\s+|\s+$//g;
          my $alt_text = '';
          if (my $img = ($child->tag eq 'picture' ? $child->at('img') : $child)) {
            $alt_text = $img->attr('alt') // '';
          }
          if ($text_content eq '' || $text_content eq $alt_text) {
            $image_elem = $child;
            $store_elem = $child;  # Store just the image, not the p wrapper
          }
        }
        # Check for p > a > img (linked image in paragraph)
        elsif ($child->tag eq 'a') {
          my $a_children = $child->children;
          if ($a_children->size == 1) {
            my $grandchild = $a_children->first;
            if ($grandchild && $grandchild->tag && ($grandchild->tag eq 'picture' || $grandchild->tag eq 'img')) {
              my $text_content = $first_elem->all_text // '';
              $text_content =~ s/^\s+|\s+$//g;
              my $alt_text = '';
              if (my $img = ($grandchild->tag eq 'picture' ? $grandchild->at('img') : $grandchild)) {
                $alt_text = $img->attr('alt') // '';
              }
              if ($text_content eq '' || $text_content eq $alt_text) {
                $image_elem = $grandchild;
                $store_elem = $child;  # Store the full link with image
              }
            }
          }
        }
      }
    }
  }

  return unless $image_elem;

  # Add card-img-top class to the img element
  if ($image_elem->tag eq 'picture') {
    my $img = $image_elem->at('img');
    if ($img) {
      my $existing_class = $img->attr('class') // '';
      unless ($existing_class =~ /card-img-top/) {
        $img->attr('class', $existing_class ? "$existing_class card-img-top" : 'card-img-top');
      }
    }
  } else {
    my $existing_class = $image_elem->attr('class') // '';
    unless ($existing_class =~ /card-img-top/) {
      $image_elem->attr('class', $existing_class ? "$existing_class card-img-top" : 'card-img-top');
    }
  }

  # Store the image for card header (may include link wrapper)
  $subdoc->{card_image} = $store_elem->to_string;

  # Remove the first element (which contains or is the image)
  $first_elem->remove;

  # Update main content
  my $html = $dom->to_string;
  $html =~ s/^[\s\r\n]+//;
  $html =~ s/[\s\r\n]+$//;
  $subdoc->{main} = $html;
}

# Render TipTap toolbar chunk
sub editor_toolbar ($self) {
  $self->stash(status => 200);
  $self->render(template => 'web/editor/toolbar/index', format => 'html', layout => undef);
}

# Render new content modal (for new docs or fallback/translation options)
# Dynamic data (target language, content path) comes from sessionStorage set by JS
sub addcontent ($self) {
  return unless $self->access({ admin => 1 });

  my $default_language = $self->config->{locale}->{default_language} // 'en';
  my $has_anthropic = exists($self->config->{anthropic}) && $self->config->{anthropic}->{api_key} ? 1 : 0;

  $self->stash(
    default_language => $default_language,
    has_anthropic => $has_anthropic
  );

  my $web = { css => '', script => '' };
  $web->{script} = $self->render_to_string(template => 'web/new/index', format => 'js');
  $self->render(template => 'web/new/index', format => 'html', layout => 'modal', web => $web);
}


# Src browser page (HTML) and API operations
sub src ($self) {
  return unless $self->access({ admin => 1 });

  # Get path from stash (URL) or query param (API)
  my $srcpath = $self->stash('srcpath') // $self->param('path') // '';
  $srcpath = '' if $srcpath eq '_';  # _ is placeholder for root
  $srcpath =~ s|^/||;
  $srcpath =~ s|/$||;

  # HTML page request
  unless ($self->req->headers->accept =~ m{application/json}) {
    my $docpath = $self->url_for('web_src_root')->to_string;
    $docpath =~ s|^/||;  # Remove leading slash
    $docpath .= '/index.html';  # All src paths use same cached template
    $self->stash(docpath => $docpath);
    my $web = { css => '', script => '' };
    $web->{script} = $self->render_to_string(template => 'web/src/index', format => 'js');
    return $self->render(template => 'web/src/index', format => 'html', web => $web, srcpath => $srcpath);
  }

  # API: Create new item
  if ($self->req->method eq 'POST') {
    my $data = $self->req->json;
    my $path = $data->{path} // '';
    my $type = $data->{type} // 'directory';
    my $language = $data->{language};
    my $target = $data->{target} // 'file';  # 'file' or 'database'

    my $result = $self->app->web->filetree_create($path, $type, $language, $target);
    return $self->render(json => $result);
  }

  # GET - list directory
  my $result = $self->app->web->filetree_list($srcpath);
  $self->render(json => $result);
}


sub src_rename ($self) {
  return unless $self->access({ admin => 1 });

  # Get old path from URL
  my $old_path = $self->stash('srcpath') // '';
  $old_path = '' if $old_path eq '_';  # _ is placeholder for root
  $old_path =~ s|^/||;
  $old_path =~ s|/$||;

  my $data = $self->req->json // {};
  my $new_path = $data->{newPath} // '';

  my $result = $self->app->web->filetree_rename($old_path, $new_path);
  $self->render(json => $result);
}


sub src_delete ($self) {
  return unless $self->access({ admin => 1 });

  # Get path from URL
  my $path = $self->stash('srcpath') // '';
  $path = '' if $path eq '_';  # _ is placeholder for root
  $path =~ s|^/||;
  $path =~ s|/$||;

  my $result = $self->app->web->filetree_delete($path);
  $self->render(json => $result);
}


# Get raw source content for editing (returns JSON with markdown/source)
sub source ($self) {
  return unless $self->access({ admin => 1 });

  my $docpath = $self->stash('docpath') // '/';
  $docpath =~ s|^/||;
  $docpath =~ s|/$||;
  $docpath = $docpath ? "/$docpath/" : "/";

  my $language = $self->_get_content_language();

  # Get source content from model
  my $source_data = $self->app->web->get_source_content($docpath, $language);

  unless ($source_data) {
    return $self->render(json => { success => 0, error => 'Content not found' }, status => 404);
  }

  $self->render(json => {
    success => 1,
    docpath => $docpath,
    language => $language,
    content => $source_data
  });
}

# Translate markdown content using Anthropic API
sub translate ($self) {
  return unless $self->access({ admin => 1 });

  my $json = $self->req->json;
  my $markdown = $json->{markdown} // '';
  my $target_language = $json->{target_language} // 'en';
  my $frontmatter = $json->{frontmatter} // '';

  unless ($markdown) {
    return $self->render(json => { success => 0, error => 'No content to translate' }, status => 400);
  }

  # Get Anthropic config
  my $config = $self->config->{anthropic} // {};
  my $api_key = $config->{api_key} // $ENV{ANTHROPIC_API_KEY};
  my $model = $config->{model} // 'claude-sonnet-4-20250514';

  unless ($api_key) {
    return $self->render(json => { success => 0, error => 'Translation service not configured' }, status => 503);
  }

  # Build translation prompt
  my $prompt = "Translate the following markdown content to $target_language. " .
               "Preserve all markdown formatting, links, and structure. " .
               "Only translate the text content, not code blocks or URLs. " .
               "Return ONLY the translated markdown, no explanations.\n\n" .
               "Content to translate:\n$markdown";

  # Call Anthropic API
  my $ua = Mojo::UserAgent->new;
  $ua->transactor->name('Samizdat (see fakemedium.com)');

  my $tx = $ua->post('https://api.anthropic.com/v1/messages' => {
    'Content-Type' => 'application/json',
    'x-api-key' => $api_key,
    'anthropic-version' => '2023-06-01'
  } => json => {
    model => $model,
    max_tokens => 4096,
    messages => [
      { role => 'user', content => $prompt }
    ]
  });

  if ($tx->result->is_success) {
    my $response = $tx->result->json;
    if ($response->{content} && @{$response->{content}}) {
      my $translated = $response->{content}[0]{text};

      # Also translate frontmatter if provided
      my $translated_frontmatter = '';
      if ($frontmatter) {
        # Strip --- delimiters before sending to API
        my $fm_content = $frontmatter;
        $fm_content =~ s/^---\s*\n//;
        $fm_content =~ s/\n---\s*\n?$//;

        my $fm_prompt = "Translate the following YAML frontmatter metadata to $target_language. " .
                        "Only translate the values, not the keys. Preserve YAML structure. " .
                        "Return ONLY the translated YAML content without --- delimiters, no explanations.\n\n$fm_content";

        my $fm_tx = $ua->post('https://api.anthropic.com/v1/messages' => {
          'Content-Type' => 'application/json',
          'x-api-key' => $api_key,
          'anthropic-version' => '2023-06-01'
        } => json => {
          model => $model,
          max_tokens => 1024,
          messages => [
            { role => 'user', content => $fm_prompt }
          ]
        });

        if ($fm_tx->result->is_success) {
          my $fm_response = $fm_tx->result->json;
          if ($fm_response->{content} && @{$fm_response->{content}}) {
            $translated_frontmatter = $fm_response->{content}[0]{text};
            # Strip ALL --- delimiters from response (handles duplicates)
            $translated_frontmatter =~ s/^[\s\n]*---[\s\n]*//;  # Leading ---
            $translated_frontmatter =~ s/[\s\n]*---[\s\n]*$//;  # Trailing ---
            $translated_frontmatter =~ s/\n---\n/\n/g;          # Any middle ---
            $translated_frontmatter =~ s/^\s+//;
            $translated_frontmatter =~ s/\s+$//;
          }
        }
      }
      return $self->render(json => {
        success => 1,
        translated => $translated,
        frontmatter => $translated_frontmatter  # YAML without --- delimiters
      });
    }
  }

  my $error = $tx->result->json->{error}{message} // 'Translation failed';
  $self->render(json => { success => 0, error => $error }, status => 500);
}

# Save editable content to file or database
sub src_save ($self) {
  # Check authentication first - require admin access for content editing
  return unless $self->access({ admin => 1 });

  # Get the authenticated user
  my $authcookie = $self->cookie($self->config->{manager}->{account}->{authcookiename});
  my $user = $self->app->account->session($authcookie) if $authcookie;

  # Get path from URL (srcpath stash)
  my $srcpath = $self->stash('srcpath') // '';
  $srcpath = '' if $srcpath eq '_';  # _ is placeholder for root
  $srcpath =~ s|^/||;
  $srcpath =~ s|/$||;

  my $request_data = $self->req->json // {};

  # Build docpath from srcpath
  my $docpath = $srcpath ? "/$srcpath/" : "/";
  my $editors = $request_data->{editors};
  my $frontmatter = delete $editors->{frontmatter} if $editors;  # Extract frontmatter separately
  my $target = $request_data->{target} // 'file';  # 'file' or 'database'

  # Validate input
  unless ($editors && ref($editors) eq 'HASH') {
    return $self->render(json => {
      success => 0,
      error => 'Missing required parameter: editors'
    }, status => 400);
  }

  my $content_language = $self->_get_content_language();

  eval {
    # Save all editors for this page
    # Sort to ensure main content is saved FIRST (headline, thecontent, element-0)
    # This is critical because sidecards need the main resource to exist for connections
    my @resource_ids;
    my @main_ids = qw(headline thecontent element-0);
    my @sorted_ids = (
      (grep { my $id = $_; grep { $id eq $_ } @main_ids } keys %$editors),
      (grep { my $id = $_; !grep { $id eq $_ } @main_ids } keys %$editors)
    );

    for my $element_id (@sorted_ids) {
      my $content = $editors->{$element_id};
      next unless defined $content && $content ne '';

      # Pass frontmatter only for main content
      my $is_main = grep { $element_id eq $_ } @main_ids;

      my $save_params = {
        docpath => $docpath,
        element_id => $element_id,
        content => $content,
        frontmatter => $is_main ? $frontmatter : undef,
        language => $content_language,
        user_id => $user->{userid}
      };

      my $resource_id;
      if ($target eq 'file') {
        $resource_id = $self->app->web->save_content_to_file($save_params);
      } else {
        $resource_id = $self->app->web->save_content($save_params);
      }
      push @resource_ids, $resource_id if $resource_id;
    }

    # Invalidate cache for this docpath and language
    $self->app->web->invalidate_cache($docpath, $content_language);

    $self->render(json => {
      success => 1,
      message => "Content saved to $target successfully",
      resource_ids => \@resource_ids,
      editors_saved => scalar(@resource_ids),
      target => $target
    });
  };
  if ($@) {
    $self->app->log->error("Failed to save content to $target: $@");
    $self->render(json => {
      success => 0,
      error => "Failed to save content to $target"
    }, status => 500);
  }
}

# Get content language from editlanguage cookie or fall back to app language
# The editlanguage cookie takes priority for content operations (editing Hindi in English UI)
sub _get_content_language ($self) {
  # Check query param first (for API calls)
  my $query_lang = $self->param('language') // '';
  if ($query_lang && exists($self->config->{locale}->{languages}->{$query_lang})) {
    return $query_lang;
  }
  # Then check cookie (for editor sessions)
  my $edit_lang = $self->cookie('editlanguage') // '';
  if ($edit_lang && exists($self->config->{locale}->{languages}->{$edit_lang})) {
    return $edit_lang;
  }
  return $self->app->language;
}

1;
