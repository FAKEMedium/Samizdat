package Samizdat::Controller::Manager;

use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($self) {
  my $title = $self->app->__('Manager');
  my $web = { title => $title };

  my $accept = $self->req->headers->{headers}->{accept}->[0] // '';

  my @services = sort {
    $self->app->config->{manager}->{$a}->{cardnumber}
      <=>
    $self->app->config->{manager}->{$b}->{cardnumber}
  }
  grep {
    ref($self->app->config->{manager}->{$_}) eq 'HASH' &&
    exists $self->app->config->{manager}->{$_}->{cardnumber}
  }
  keys %{$self->app->config->{manager}};

  if ($accept =~ /json/) {
    return unless $self->access({ 'valid-user' => 1 });
    return $self->render(json => { services => \@services }, status => 200);
  } else {
    for my $service (@services) {
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

