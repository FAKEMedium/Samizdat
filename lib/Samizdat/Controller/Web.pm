package Samizdat::Controller::Web;

use Mojo::Base 'Mojolicious::Controller', -signatures;
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
        language   => $self->app->language,
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
  my $docs = $self->app->web->getlist($docpath, {
    language => $self->app->language,
    languages => $self->config->{locale}->{languages},
  });
  if (!exists($docs->{$docpath})) {
    $self->stash('status', 404);
    return $self->reply->not_found;
  }
  my $title = $self->app->__x("Edit page {docpath}", docpath => '/' . $docpath);
  my $web = $docs->{$docpath};
  $web->{script} .= $self->render_to_string(template => 'web/edit', format => 'js');
  $web->{css} .= $self->render_to_string(template => 'web/edit', format => 'css');
  $self->stash(web => $web, docpath => $web->{docpath}, title => $title);
  $self->render(template => 'web/edit', headline => 'web/chunks/headline');
}


sub languages ($self) {
  my $languages = $self->app->web->getlanguages();
  $self->render(json => { languages => $languages });
}


sub menus ($self) {
  my $menus = $self->app->web->getmenus();
  $self->render(json => { menus => $menus });
}


# This is the main entry point for all web pages that sit in the src/public directory.
# It will also try to lookup the uri in the database.
sub getdoc ($self) {
  my $docpath = $self->stash('docpath');
  my $html = $self->app->__x("The page {docpath} wasn't found.", docpath => '/' . $docpath);
  my $title = $self->app->__('404: Missing document');
  my $docs = $self->app->web->getlist($docpath, {
    language => $self->app->language,
    languages => $self->config->{locale}->{languages},
  });
  my $path = sprintf("%s%s", $docpath, 'index.html');
  if (!exists($docs->{$path})) {
    banbot($docpath, $self->tx->remote_address);
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
    $docs->{$path}->{canonical} = sprintf('%s%s%s', $self->config->{siteurl}, $self->config->{baseurl}, $docpath);
    $docs->{$path}->{head}->{meta}->{property}->{'og:title'} = $docs->{$path}->{title};
    $docs->{$path}->{head}->{meta}->{property}->{'og:url'} = $docs->{$path}->{canonical};
    $docs->{$path}->{head}->{meta}->{property}->{'og:canonical'} = $docs->{$path}->{canonical};
    $docs->{$path}->{head}->{meta}->{name}->{'twitter:url'} = $docs->{$path}->{canonical};
    $docs->{$path}->{head}->{meta}->{name}->{'twitter:title'} = $docs->{$path}->{title};
    $docs->{$path}->{head}->{meta}->{itemprop}->{'name'} = $docs->{$path}->{title};
    if (exists $docs->{$path}->{head}->{meta}->{name}->{description}) {
      $docs->{$path}->{head}->{meta}->{property}->{'og:description'} = $docs->{$path}->{head}->{meta}->{name}->{description};
      $docs->{$path}->{head}->{meta}->{name}->{'twitter:description'} = $docs->{$path}->{head}->{meta}->{name}->{description};
      $docs->{$path}->{head}->{meta}->{itemprop}->{'description'} = $docs->{$path}->{head}->{meta}->{name}->{description};
    }
    if ($#{$docs->{$path}->{subdocs}} > -1) {
      my $sidebar = '';
      for my $subdoc (sort {$a->{docpath} cmp $b->{docpath}} @{ $docs->{$path}->{subdocs} }) {
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

  $self->render(text => $manifest, web => { docpath => 'manifest.json' }, format => 'json');
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

sub security ($self) {
  $self->render(text => $self->config->{security}, docpath => '.well-known/security.txt', format => 'txt');
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

# Render TipTap toolbar chunk
sub editor_toolbar ($self) {
  $self->stash(status => 200);
  $self->render(template => 'web/editor/toolbar/index', format => 'html', layout => undef);
}

# Save editable content to database
sub save ($self) {
  # Check authentication first - require admin access for content editing
  return unless $self->access({ admin => 1 });

  # Get the authenticated user
  my $authcookie = $self->cookie($self->config->{manager}->{account}->{authcookiename});
  my $user = $self->app->account->session($authcookie) if $authcookie;

  # Handle both single editor and batch editor formats
  my $request_data;
  if ($self->req->headers->content_type && $self->req->headers->content_type =~ /application\/json/) {
    # New batch format
    $request_data = $self->req->json;
  } else {
    # Legacy single editor format
    $request_data = {
      docpath => $self->param('docpath'),
      editors => {
        ($self->param('element_id') || 'thecontent') => $self->param('content')
      }
    };
  }
  
  my $docpath = $request_data->{docpath};
  my $editors = $request_data->{editors};
  
  # Normalize docpath - remove double slashes and ensure single trailing slash for directories
  $docpath =~ s|//+|/|g;  # Replace multiple slashes with single slash
  $docpath =~ s|/$||;     # Remove trailing slash
  $docpath .= '/' if $docpath ne ''; # Add back single trailing slash for non-root
  $docpath = '/' if $docpath eq '';  # Root case
  
  # Validate input
  unless ($docpath && $editors && ref($editors) eq 'HASH') {
    return $self->render(json => {
      success => 0,
      error => 'Missing required parameters: docpath, editors'
    }, status => 400);
  }
  
  eval {
    # Save all editors for this page
    my @resource_ids;
    for my $element_id (keys %$editors) {
      my $content = $editors->{$element_id};
      next unless defined $content && $content ne '';
      
      my $resource_id = $self->app->web->save_content({
        docpath => $docpath,
        element_id => $element_id,
        content => $content,
        language => $self->app->language,
        user_id => $user->{userid}
      });
      push @resource_ids, $resource_id;
    }
    
    # Invalidate cache for this docpath and language
    $self->app->web->invalidate_cache($docpath, $self->app->language);
    
    $self->render(json => {
      success => 1,
      message => 'Content saved successfully',
      resource_ids => \@resource_ids,
      editors_saved => scalar(@resource_ids)
    });
  };
  if ($@) {
    $self->app->log->error("Failed to save content: $@");
    $self->render(json => {
      success => 0,
      error => 'Failed to save content'
    }, status => 500);
  }
}

1;
