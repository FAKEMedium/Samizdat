package Samizdat::Controller::Markdown;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::DOM;
sub geturi ($self) {
  my $docpath = $self->stash('docpath');

#  $docpath =~  s/\///;

  my $html = $self->app->__x("The page {docpath} wasn't found.", docpath => $docpath);
  my $title = $self->app->__('404: Missing document');
  my $index =  sprintf('%sREADME.md', $docpath);
  my $md = $self->app->markdown->readmd($index);

  if ('' ne $md) {
    $html = $self->app->markdown->md2html($md);
    my $dom = Mojo::DOM->new($html);
    $title = $dom->at('h1')->text;
    $dom->at('h1')->remove;
    $html = $dom->content;
  }
  my $web = {
    sidepanels => [],
    main => $html,
    title => $title,
  };
  $self->stash(web => $web);
  $self->stash(title => $title);
  $self->render();
}

1;
