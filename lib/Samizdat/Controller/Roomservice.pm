package Samizdat::Controller::Roomservice;

use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($self) {
  my $title = $self->app->__('Roomservice');
  my $web = { title => $title };

  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    for my $service (
      sort {
        $self->app->config->{roomservice}->{$a}->{cardnumber}
          <=>
        $self->app->config->{roomservice}->{$b}->{cardnumber}
      }
      keys %{$self->app->config->{roomservice}}
    ) {
      $web->{script} .= $self->render_to_string(template => sprintf('%s/chunks/roomservice', $service), format => 'js', service => $service);
      my $cardcontent =  $self->render_to_string(template => sprintf('%s/chunks/roomservice', $service), format => 'html', service => $service);
      my $card = $self->render_to_string(template => 'roomservice/chunks/card', cardcontent => $cardcontent, service => $service, format => 'html');
      $web->{main} .= $card;
    }
    $web->{script} .= $self->render_to_string(format => 'js', template => 'roomservice/index');
    $self->render(web => $web, title => $title, template => 'roomservice/index');
  }
}

1;

