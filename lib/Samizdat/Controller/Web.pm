package Samizdat::Controller::Web;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::JSON qw(encode_json);

sub geturi ($self) {
  my $docpath = $self->stash('docpath');
  my $html = $self->app->__x("The page {docpath} wasn't found.", docpath => '/' . $docpath);
  my $title = $self->app->__('404: Missing document');

  my $docs = $self->app->markdown->list($docpath, {
    language => $self->app->language,
    languages => $self->config->{locale}->{languages},
  });
  my $path = sprintf("%s%s", $docpath, 'index.html');
  $self->stash(template => 'index');

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
      meta        => {
                       name => {
                         description => $self->app->__('Missing file, our bad?'),
                         keywords    => ["error","404"]
                       }
                     },
      language => $self->app->language
    };
  } else {
    $docs->{$path}->{canonical} = sprintf('%s%s', $self->config->{siteurl}, $docpath);
    $docs->{$path}->{meta}->{property}->{'og:title'} = $docs->{$path}->{title};
    $docs->{$path}->{meta}->{property}->{'og:url'} = $docs->{$path}->{canonical};
    $docs->{$path}->{meta}->{property}->{'og:canonical'} = $docs->{$path}->{canonical};
    $docs->{$path}->{meta}->{name}->{'twitter:url'} = $docs->{$path}->{canonical};
    $docs->{$path}->{meta}->{name}->{'twitter:title'} = $docs->{$path}->{title};
    $docs->{$path}->{meta}->{itemprop}->{'name'} = $docs->{$path}->{title};
    if (exists $docs->{$path}->{meta}->{name}->{description}) {
      $docs->{$path}->{meta}->{property}->{'og:description'} = $docs->{$path}->{meta}->{name}->{description};
      $docs->{$path}->{meta}->{name}->{'twitter:description'} = $docs->{$path}->{meta}->{name}->{description};
      $docs->{$path}->{meta}->{itemprop}->{'description'} = $docs->{$path}->{meta}->{name}->{description};
    }
    if ($#{$docs->{$path}->{subdocs}} > -1) {
      my $sidebar = '';
      for my $subdoc (sort {$a->{docpath} cmp $b->{docpath}} @{ $docs->{$path}->{subdocs} }) {
        $sidebar .= $self->render_to_string(template => 'chunks/sidecard', card => $subdoc);
      }
      $docs->{$path}->{sidebar} = $sidebar;
      $self->stash(template => 'twocolumn');
    }
  }
  $self->stash(web => $docs->{$path});
  $self->stash(title => $docs->{$path}->{title} // $title);
  $self->render();
}

sub manifest ($self) {
  my $icons = [{
    src   => '/favicon.ico',
    sizes => '16x16 32x32 48x48 64x64'
  }];
  for my $size (@{ $self->app->config->{icons}->{sizes} }) {
    my $src = sprintf('/media/images/icon.%04d.png', $size);
    push @{ $icons }, {
      src     => $src,
      sizes   => sprintf('%dx%d', $size, $size),
      type    => 'image/png',
      purpose => 'maskable'
    };
  }
  push @{ $icons }, {
    src     => '/' . $self->app->config->{logotype},
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
  $self->render(text => $self->config->{robots}, web => {docpath => 'robots.txt'}, format => 'txt');
}

sub humans ($self) {
  $self->render(text => $self->config->{humans}, web => {docpath => 'humans.txt'}, format => 'txt');
}

sub ads ($self) {
  $self->render(text => $self->config->{ads}, web => {docpath => 'ads.txt'}, format => 'txt');
}

sub security ($self) {
  $self->render(text => $self->config->{security}, web => {docpath => '.well-known/security.txt'}, format => 'txt');
}

# Gather exploiting bots
sub banbot ($docpath, $ip){
  if ($docpath =~ /(
    xmlrpc.php |
    wp-login.php |
    wp-admin
  )/ixx) {
    say sprintf("%s\t%s\t%s", time, $ip, $docpath);
  }
}


1;
