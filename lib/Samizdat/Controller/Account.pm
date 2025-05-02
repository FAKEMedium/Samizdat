package Samizdat::Controller::Account;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use MIME::Lite;
use Mojo::JSON qw(decode_json encode_json j);
use Mojo::Util qw(decode encode b64_encode trim);
use DateTime;
use DateTime::TimeZone;
use Date::Calc qw(Today Add_Delta_Days Date_to_Text Parse_Date Date_to_Days Delta_Days);
use Data::Dumper;

my $levels = {
  'unauthenticated' => 0,
  'user'           => 99,
  'admin'          => 999,
  'superadmin'     => 9999,
};

sub index ($self) {
  if ($self->authenticated_user()) {
    return $self->redirect_to($self->url_for('account_panel'));
  } else {
    return $self->redirect_to($self->url_for('account_register'));
  }
}


sub login ($self) {
  if (lc $self->req->method eq 'get') {
    my $title = $self->app->__('Log in');
    my $web = { title => $title, docpath => => '/account/login/index.html' };
    $web->{script} .= $self->app->indent($self->render_to_string(template => 'account/login', format => 'js'), 4);
    return $self->render(template => 'account/login', layout => 'modal', web => $web, title => $title);
  }

  my $v = $self->validation;
  $v->required('not_empty', 'not_empty');
  $v->required('username', 'not_empty');
  $v->required('password', 'not_empty');
  if ($v->has_error) {
    return $self->render(json => { error => { reason => 'incomplete' } }, status => 200);
  }

  # Check if blocklimit failed attempts been made last blocktime minutes from remote host
  my $ip = $self->_getip();
  my $loginfailures = $self->app->account->getLoginFailures($ip);
  my $count = scalar @{ $loginfailures };
  if ($count >= $self->config->{account}->{blocklimit}) {
    return $self->render(json => { error => { reason => 'blocked' },
      ip         => $ip,
      blocklimit => $self->config->{account}->{blocklimit},
      blocktime  => $self->config->{account}->{blocktime}
    }, status => 200);
  }

  my $userid = undef;
  my $user = {
    superadmin => 0
  };
  my $username = $v->param('username');
  my $password = $v->param('password');
  my $rememberme = $self->param('rememberme');

  if (exists($self->config->{account}->{superadmins}->{$username}) && ($self->config->{account}->{superadmins}->{$username} eq $password)) {
    $userid = 0;
    $user = {
      userid      => 0,
      username    => $username,
      superadmin  => 1,
      displayname => 'Super admin',
    };
  } else {
    $userid = eval {return $self->app->account->validatePassword($username, $password)};
    if ($userid) {
      $user = ${$self->app->account->getUsers({ id => $userid })}[0];
    }
  }

  if (defined $userid) {
    my $userdata = {
      'd'  => $user->{displayname},
      'n'  => $user->{username},
      'i'  => $userid,
      'e'  => '1',
      't'  => '',
      'm'  => '0',
      'l'  => 'en',
      's'  => exists($self->config->{account}->{superadmins}->{$user->{'username'}}) ? 1 : 0,
      'ip' => $ip,
    };
    my $value = b64_encode(j $userdata);
    chomp $value;
    $value =~ s/[\r\n]+//g;
    my $authcookie = $self->app->uuid->create_str();

    $self->app->account->login($authcookie, {
      userid     => $userid,
      username   => $user->{username},
      superadmin => $user->{superadmin},
      value      => $value,
      ip         => $ip,
    });

    $self->signed_cookie($self->config->{account}->{authcookiename} => $authcookie, {
      secure => 0,
      httponly => 0,
      path => '/',
      expires => time + $self->config->{account}->{sessiontimeout},
      domain => $self->config->{account}->{cookiedomain},
      hostonly => 1,
    });
    $self->cookie($self->config->{account}->{datacookiename} => $value, {
      secure => 0,
      httponly => 0,
      path => '/',
      expires => time + $self->config->{account}->{sessiontimeout},
      domain => $self->config->{account}->{cookiedomain},
      hostonly => 1,
    });
    $self->app->account->insertLogin($ip, $userid, $value);
    $self->render(json => { userdata => $userdata }, status => 200);

  } else {
    $self->app->account->insertLoginFailure($ip, $username);
    return $self->render(json => { error => { reason => 'password', count => $count },
      ip         => $ip,
      blocklimit => $self->config->{account}->{blocklimit},
      blocktime  => $self->config->{account}->{blocktime}
    }, status => 403);
  }
}

sub logout ($self) {
  my $authcookie = $self->signed_cookie($self->config->{account}->{authcookiename});
  my $session = $self->app->account->logout($authcookie);
  my $username = $session->{username};
  $self->cookie($self->config->{account}->{authcookiename} => '', {
    secure => 0,
    httponly => 0,
    path => '/',
    expires => 1,
    domain => $self->config->{account}->{cookiedomain},
    hostonly => 1,
  });
  $self->cookie($self->config->{account}->{datacookiename} => '', {
    secure => 0,
    httponly => 0,
    path => '/',
    expires => 1,
    domain => $self->config->{account}->{cookiedomain},
    hostonly => 1,
  });
  return $self->redirect_to('/');
}


sub register ($self) {
  my $formdata = { ip => $self->tx->remote_address };
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept =~ /json/) {
    my $valid = {};
    my $errors = {};
    my $v = $self->validation;

    for my $field (qw(newusername newpassword email terms captcha)) {
      $formdata->{$field} = trim $self->param($field);
      if (!$v->required($field, 'trim', 'not_empty')->is_valid) {
        $valid->{$field} = "is-invalid";
        $errors->{$field} = $self->app->__('This field is required');
      } else {
        $valid->{$field} = "is-valid";
        $errors->{$field} = '';
      }
    }

    if (!$self->validate_captcha($formdata->{captcha})) {
      $v->error(captcha => [ 'Captcha was wrong' ]);
      $errors->{captcha} = $self->app->__('Captcha was wrong');
      $valid->{captcha} = "is-invalid";
    } else {
      $valid->{captcha} = "is-valid";
      $errors->{captcha} = '';
    }

    $formdata->{errors} = $errors;
    $formdata->{valid} = $valid;
    if ($v->has_error) {
      $formdata->{success} = 0;
      return $self->render(json => $formdata);

    } else {
      my $maildata = $self->render_mail(template => 'account/confirm', formdata => $formdata);
      my $subject = Encode::encode("MIME-Q", $self->app->__('Account confirmation'));
      $formdata->{$maildata } = $maildata;
      my $from = Encode::encode("MIME-Q", sprintf('"%s" <%s>', $self->config->{organization}, $self->config->{mail}->{from}));
      my $mail = MIME::Lite->new(
        From         => $from,
        To           => $formdata->{email},
        Subject      => $subject,
        'X-Mailer'   => "Samizdat",
        Data         => $maildata,
      );
      $mail->send($self->config->{mail}->{how}, @{$self->config->{mail}->{howargs}});
      $formdata->{success} = 1;
      $formdata->{submitted} = Encode::decode 'UTF-8', Encode::encode 'UTF-8',
        $self->render_to_string(template => 'account/submitted', layout => undef, formdata => $formdata);
      $self->tx->res->headers->content_type('application/json; charset=UTF-8');
      return $self->render(json => $formdata, status => 200);
    }
  }

  my $title = $self->app->__('Register account');
  my $web = { title => $title, docpath => '/account/register/index.html' };
  $web->{script} .= $self->app->indent($self->render_to_string(template => 'account/register',
    formdata => { ip => 'REPLACEIP' }, format => 'js'), 4);
  return $self->render(web => $web, title => $title, template => 'account/register',
    formdata => { ip => 'REPLACEIP' }, status => 200);
}


sub password ($self) {
  if (lc $self->req->method eq 'get') {
    my $title = $self->app->__('Change password');
    my $web = { title => $title };
    $web->{script} .= $self->app->indent($self->render_to_string(template => 'account/password', format => 'js'), 4);
    return $self->render(template => 'account/password', web => $web, title => $title);
  }

  my $v = $self->validation;
  $v->required('not_empty', 'not_empty');
  $v->required('username', 'not_empty');
  $v->required('password', 'not_empty');
  $v->required('email', 'not_empty');
  if ($v->has_error) {
    return $self->render(json => { error => { reason => 'incomplete' } }, status => 200);
  }
  my $ip = $self->_getip();
}


sub authenticated_user ($self) {
  my $authcookie = $self->signed_cookie($self->config->{account}->{authcookiename});
  if ($authcookie) {
    return $self->app->account->session($authcookie);
  }
  return undef;
}


sub authorize ($self, $level = 0) {
  my $authcookie = $self->signed_cookie($self->config->{account}->{authcookiename});
  return 1;
  if ($authcookie) {
    my $session = $self->app->account->session($authcookie);
    if ($session->{superadmin}) {
      return 1;
    } else {
      $self->render(template => 'forbidden', status => 403);
      return undef;
    }
  }
  my $title = $self->app->__('Unauthenticated');
  my $web = {
    script => $self->app->indent($self->render_to_string(template => 'unauthenticated', format => 'js'), 0),
    title  => $title,
  };
  $self->render(template => 'unauthenticated', status => 401, web => $web, title => $title);
  return undef;
}


sub _getip ($self) {
  my $ip = ${ $self->req->headers->{'headers'}->{'remote_host'} }[0]
    // ${ $self->req->headers->{'headers'}->{'x-forwarded-for'} }[0]
    // '0.0.0.0';
}


sub panel ($self) {
  my $title = $self->app->__('Panel');
  my $web = { title => $title };
  $self->stash(user => $self->authenticated_user());
  $web->{script} .= $self->app->indent($self->render_to_string(template => 'account/panel', format => 'js'), 4);
  return $self->render(template => 'account/panel', web => $web, title => $title, docpath => 'account/panel.html');
}


sub user ($self) {
  return 1;
}


sub users ($self) {
  return 1;
}

sub settings ($self) {
  $self->stash(user => $self->authenticated_user());

  return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

alipang E<lt>hans@fakemedia.seE<gt>

=head1 COPYRIGHT

Copyright 2025 Hans Svensson

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut