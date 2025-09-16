package Samizdat::Controller::Manager;

use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($self) {
  my $title = $self->app->__('Manager');
  my $web = { title => $title };

  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    for my $service (
      sort {
        $self->app->config->{manager}->{$a}->{cardnumber}
          <=>
        $self->app->config->{manager}->{$b}->{cardnumber}
      }
      grep { 
        ref($self->app->config->{manager}->{$_}) eq 'HASH' && 
        exists $self->app->config->{manager}->{$_}->{cardnumber} 
      }
      keys %{$self->app->config->{manager}}
    ) {
      $web->{script} .= $self->render_to_string(template => sprintf('%s/chunks/manager', $service), format => 'js', service => $service);
      my $cardcontent =  $self->render_to_string(template => sprintf('%s/chunks/manager', $service), format => 'html', service => $service);
      my $card = $self->render_to_string(template => 'manager/chunks/card', cardcontent => $cardcontent, service => $service, format => 'html');
      $web->{main} .= $card;
    }
    $web->{script} .= $self->render_to_string(format => 'js', template => 'manager/index');
    $self->render(web => $web, title => $title, template => 'manager/index');
  }
}

1;

