package Samizdat::Controller::Poll;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::Home;
use Mojo::Template;
use Data::Dumper;

sub svg($self) {
  my $number = 12222;
  my $pollid = $self->param('pollid') // 1;
  my $poll = undef;
  if ($pollid) {
    $poll = $self->app->poll->getpoll($pollid);
  }
  if ($poll) {
    my $signer = $self->poll->signers($pollid)->[0];
    $signer->{number} = $number;
    #  say Dumper $self->app->{countries}->{translations};
    $signer->{country} = $self->app->{countries}->{translations}->{ lc $self->app->language }->{uc $signer->{cc}};
    #  say Dumper $signer;
    my $signature = $self->app->__x('#{number}: {firstname} {lastname}, {city}, {country}',
      number => $signer->{number}, firstname => $signer->{firstname}, lastname => $signer->{lastname},
      city   => $signer->{city}, country => $signer->{country});
    my $numbers = $self->app->__x('{number} signatures since {date}', number => $number, date => '2024-05-08');
    $self->render(
      template  => 'poll/signatures',
      format    => 'svg',
      layout    => undef,
      signature => $signature,
      numbers   => $numbers
    );
  } else {
    return undef;
  }
}

sub index($self) {
  my $pollid = $self->param('pollid') // 1;
  my $poll = undef;
  if ($pollid) {
    $poll = $self->app->poll->getpoll($pollid);
  }
  if ($poll) {
    my $valid = {};
    my $method = lc $self->req->method;
    my $form = {
      ip       => $self->tx->remote_address,
      method   => $method,
      language => $self->app->language,
      cc       => '',
      uuid     => $self->uuid->create_str(),
      pollid   => $pollid,
    };
    $self->stash(template => 'poll/index');
    my $web = { docpath => 'poll/index.html' };
    my $title = $self->app->__('Sign poll!');

    if ('post' eq $method) {
      my $v = $self->validation;
      for my $field (qw(firstname lastname email pc city cc captcha)) {
        $form->{$field} = $self->param($field);
        $valid->{$field} = $v->required($field, 'trim', 'not_empty')->is_valid ? " is-valid" : " is-invalid";
      }
      $valid->{captcha} = " is-valid";
      if (!$self->validate_captcha($form->{captcha})) {
        $v->error(captcha => [ 'Captcha was wrong' ]);
        $valid->{captcha} = " is-invalid";
      }
      if (!$v->has_error) {
        my $signer = $form;
        delete $signer->{captcha};
        delete $signer->{method};
        $self->poll->addsigner($signer);
        my $confirmationlink = sprintf('%spoll/confirm/%s',
          $self->config->{siteurl},
          lc $form->{uuid},
        );
        $confirmationlink = sprintf('<a href="%s">%s</a>', $confirmationlink, $confirmationlink);
        $self->stash(confirmationlink => $confirmationlink);
        $self->mail(
          to       => $form->{email},
          subject  => $self->app->__('Confirm poll signature'),
          template => 'poll/submit',
          format   => 'mail',
          Type     => 'text/html',
          form     => $form,
          layout   => 'default',
          Encoding => '8bit',
        );
        $title = $self->app->__('Confirmation request sent');
        $self->stash(template => 'poll/submit');
      }
      delete $web->{docpath};
    }
    $self->stash(form => $form);
    $self->stash(valid => $valid);
    $self->stash('status', 200);
    $self->stash(title => $title);
    $self->render(web => $web);
  }
}

sub confirm($self) {
  my $web = {};
  my $uuid = $self->stash('uuid');
  say $uuid;
  $self->stash(template => 'poll/confirm');
  $self->render(web => $web);
}

sub signatures($self) {
  $self->on(message => sub($self, $msg) {
    $self->send("echo: $msg");
  });
  $self->on(open => sub($self) {
    $self->send("Connect");
  });
  $self->on(finish => sub($self, $code, $reason) {
    say "WebSocket closed with status $code."
  });
}

1;