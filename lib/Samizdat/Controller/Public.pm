package Samizdat::Controller::Public;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::JSON qw(j);
use Mojo::Home;

sub countries ($self) {
  my $docpath = $self->stash('docpath');
  my $web = { docpath => 'country/index.html' };
  $self->stash('status', 200);
  my $title = $self->app->__x('{sitename} by country',
    sitename => $self->app->{config}->{sitename}
  );
  $self->stash(title => $title);
  $self->render(web => $web, template => 'country/index');
}


sub country ($self) {
  my $country = $self->stash('country');
  my $docpath = 'country/' . $country;
  my $html = $self->app->__x("The page {docpath} wasn't found.", docpath =>  $docpath);
  my $title = $self->app->__('404: Missing document');
  my $web = { docpath => sprintf('%s/index.html', $docpath) };
  my $search = lc $country;
  $search =~ s/[^a-z]+//g;
  my $cc = '';
  if (exists($self->app->{countries}->{reverse}->{$self->app->language}->{$search})) {
    $cc = $self->app->{countries}->{reverse}->{$self->app->language}->{$search};
    if ($country eq $self->app->{countries}->{translations}->{$self->app->language}->{$cc}) {
      $self->stash('status', 200);
      $self->stash(template => 'country/country');
      $self->stash(cc => $cc);
      $web->{title} = $title = $self->app->__x('{sitename} in {country}',
        sitename => $self->app->{config}->{sitename},
        country  => $country
      );
    } else {
      $self->stash('status', 302);
      $self->res->code(302);
      $self->redirect_to(sprintf('/country/%s', $self->app->{countries}->{translations}->{en}->{$cc}));
    }
  } else {
    $self->stash('status', 404);
    $web = {
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
      language => $self->app->language,
    };
    $self->stash(template => 'index');
  }
  $self->stash(title => $title);
  $self->render(web => $web);
}

1;