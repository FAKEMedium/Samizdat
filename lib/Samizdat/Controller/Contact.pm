package Samizdat::Controller::Contact;

use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($self) {
  my $method = lc $self->req->method;
  my $valid = {};
  my $title = $self->app->__('Contact');
  my $web = { title => $title };
  my $formdata = { ip => $self->tx->remote_address, method => lc $self->req->method };
  if ('post' eq $method) {
    my $v = $self->validation;
    for my $field (qw(name email subject message captcha)) {
      $formdata->{$field} = $self->param($field);
      $valid->{$field} = $v->required($field, 'trim', 'not_empty')->is_valid ? " is-valid" : " is-invalid";
    }
    $valid->{captcha} = " is-valid";
    if (!$self->validate_captcha($formdata->{captcha})) {
      $v->error(captcha => [ 'Captcha was wrong' ]);
      $valid->{captcha} = " is-invalid";
    }
    if (!$v->has_error) {
      $self->mail(
        to       => $self->config->{mail}->{to},
        reply_to => $formdata->{email},
        subject  => $formdata->{subject},
        template => 'contact/message',
        format   => 'mail',
        type     => 'text/plain',
        formdata => $formdata,
      );
      $title = $self->app->__('Message sent');
      $web = { title => $title };
      return $self->render(template => 'contact/sent', formdata => $formdata, web => $web, title => $title);
    }
  }
  return $self->render(web => $web, title => $title, template => 'contact/index', formdata => $formdata, valid => $valid);
}


1;