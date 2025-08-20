package Samizdat::Controller::Account;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use MIME::Lite;
use Mojo::JSON qw(decode_json encode_json j);
use Mojo::Util qw(decode encode b64_encode trim);
use Mojo::Home;
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
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'account/login/index', format => 'js');
    return $self->render(template => 'account/login/index', layout => 'modal', web => $web, title => $title);
  } else {
    $self->stash(docpath => undef);
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
  my $accept = $self->req->headers->{headers}->{accept}->[0] // '';
  
  if ($accept =~ /json/) {
    if (uc($self->req->method) eq 'POST') {
      my $valid = {};
      my $errors = {};
      my $v = $self->validation;

      for my $field (qw(newusername newpassword email terms captcha)) {
        $formdata->{$field} = trim $self->param($field);
        if (!$v->required($field, 'trim', 'not_empty')->is_valid) {
          $valid->{$field} = "is-invalid";
          $errors->{$field} = $self->app->__('This field is required');
          $v->error($field => ['empty_field']);
        } else {
          # Additional validation for username
          if ($field eq 'newusername') {
            my $username_errors = $self->validate_username($formdata->{$field});
            if ($username_errors) {
              $valid->{$field} = "is-invalid";
              $errors->{$field} = join('. ', @$username_errors);
              $v->error($field => ['invalid_username']);
            } else {
              $valid->{$field} = "is-valid";
              $errors->{$field} = '';
            }
          } elsif ($field eq 'newpassword') {
            my $password_errors = $self->validate_password($formdata->{$field});
            if ($password_errors) {
              $valid->{$field} = "is-invalid";
              $errors->{$field} = join('. ', @$password_errors);
              $v->error($field => ['invalid_password']);
            } else {
              $valid->{$field} = "is-valid";
              $errors->{$field} = '';
            }
          } elsif ($field eq 'email') {
            if ($formdata->{$field} !~ /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/) {
              $valid->{$field} = "is-invalid";
              $errors->{$field} = $self->app->__('Please enter a valid email address');
              $v->error($field => ['invalid_email']);
            } else {
              $valid->{$field} = "is-valid";
              $errors->{$field} = '';
            }
          } else {
            $valid->{$field} = "is-valid";
            $errors->{$field} = '';
          }
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

      if ($v->has_error) {
        $formdata->{success} = 0;
      } else {
        my $userid = $self->app->account->addUser($formdata->{newusername}, {
          username    => $formdata->{newusername},
          password    => $formdata->{newpassword},
        });
        if (defined $userid && $userid > 0) {
          my $users = $self->app->account->getUsers({ 'users.userid' => $userid });
          if ($users) {
            my $contactid = ${$users}[0]->{contactid};
            my $confirmationuuid = $self->app->account->addEmailConfirmationRequest($userid, $contactid, $formdata->{email}, $formdata->{ip});
            if (defined $confirmationuuid) {
              $formdata->{confirmationuuid} = $confirmationuuid;
            } else {
              # Log the error but continue - user is created, just email confirmation failed
              # Could optionally handle this differently
            }
          }
          $formdata->{success} = 1;
          $formdata->{whois} = qx!whois $formdata->{ip}!;
          my $maildatahtml = $self->render_mail(template => 'account/confirm/texthtml', layout => 'default', formdata => $formdata);
          my $maildatatxt = $self->render_mail(template => 'account/confirm/textplain', formdata => $formdata);

          my $subject = Encode::encode("MIME-Q", $self->app->__('Email confirmation'));
          my $from = Encode::encode("MIME-Q", sprintf('"%s" <%s>', $self->config->{organization}, $self->config->{mail}->{from}));
          my $mail = MIME::Lite->new(
            From         => $from,
            To           => $formdata->{email},
            BCC          => $self->config->{mail}->{to},
            Subject      => $subject,
            Organization => Encode::encode("MIME-Q", Encode::decode("UTF-8", $self->config->{organization})),
            'X-Mailer'   => "Samizdat",
            Type         => 'multipart/alternative',
          );
          $mail->attach(
            Type => 'text/plain',
            Data => $maildatatxt,
          );
          $mail->attach(
            Type => 'text/html',
            Data => $maildatahtml,
          );
          $mail->send($self->config->{mail}->{how}, @{$self->config->{mail}->{howargs}});
        } else {
          $formdata->{success} = 0;
          $formdata->{error} = { reason => 'username' };
          my $error_msg = $self->app->account->last_error // '';
          if ($error_msg =~ /username_uq/i) {
            $errors->{newusername} = $self->app->__('Username already exists');
          } else {
            $errors->{newusername} = $self->app->__('Username could not be created');
          }
          $valid->{newusername} = "is-invalid";
        }
      }
      $formdata->{errors} = $errors;
      $formdata->{valid} = $valid;
      $self->tx->res->headers->content_type('application/json; charset=UTF-8');
      return $self->render(json => $formdata, status => 200);
    }
    
    # Handle GET request (dynamic loading - just return data)
    elsif ($self->req->method eq 'GET') {
      say Dumper $formdata;
      $self->tx->res->headers->content_type('application/json; charset=UTF-8');
      return $self->render(json => $formdata, status => 200);
    }
  }

  # Handle regular GET request (return HTML page)
  my $title = $self->app->__('Register account');
  my $web = { title => $title };
  $web->{sidebar} = $self->render_to_string(template => 'account/register/sidebar');
  $web->{script} .= $self->render_to_string(template => 'account/register/index', formdata => { ip => 'REPLACEIP' }, format => 'js');
  return $self->render(web => $web, title => $title, template => 'account/register/index',
    formdata => { ip => 'REPLACEIP' }, status => 200);
}


sub confirm ($self) {
  my $confirmationuuid = $self->stash('confirmationuuid') || $self->param('confirmationuuid');
  my $formdata = { confirmationuuid => $confirmationuuid };
  my $accept = $self->req->headers->{headers}->{accept}->[0] // '';
  
  # Handle JSON requests
  if ($accept =~ /json/) {
    # Validate UUID exists
    if (!$confirmationuuid) {
      $formdata->{success} = 0;
      $formdata->{error} = { reason => 'missing_uuid' };
      $formdata->{message} = $self->app->__('Invalid confirmation link');
    } else {
      my $emailconfirmationrequest = $self->app->account->getEmailConfirmationRequest($confirmationuuid);
      
      if ($emailconfirmationrequest) {
        my $userid = $emailconfirmationrequest->{userid};
        my $contactid = $emailconfirmationrequest->{contactid};
        my $email = $emailconfirmationrequest->{newemail};
        
        # Perform the confirmation
        if ($self->app->account->updateContact($contactid, { email => $email })) {
          $self->app->account->deleteEmailConfirmationRequest($confirmationuuid);
          $self->app->account->updateUser($userid, { activated => 1, modified => 'NOW()' });
          
          $formdata->{success} = 1;
          $formdata->{message} = sprintf($self->app->__('Email %s has been verified'), $email);
          $formdata->{email} = $email;
        } else {
          $formdata->{success} = 0;
          $formdata->{error} = { reason => 'database_error' };
          $formdata->{message} = $self->app->__('Database error occurred');
        }
      } else {
        $formdata->{success} = 0;
        $formdata->{error} = { reason => 'invalid_or_expired' };
        $formdata->{message} = $self->app->__('This confirmation link is invalid or has expired');
      }
    }
    
    return $self->render(json => $formdata, status => 200);
  }
  
  # Handle HTML requests - return generic page that JavaScript will populate
  # No UUID-specific logic here since this gets cached for OpenResty
  my $title = $self->app->__('Email confirmation');
  my $web = { title => $title };
  $web->{script} .= $self->render_to_string(template => 'account/confirm/index', format => 'js');
  $web->{sidebar} = $self->render_to_string(template => 'account/confirm/sidebar');
  return $self->render(web => $web, title => $title, template => 'account/confirm/index', status => 200);
}


sub password ($self) {
  if (lc $self->req->method eq 'get') {
    my $title = $self->app->__('Change password');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'account/password/index', format => 'js');
    return $self->render(template => 'account/password/index', web => $web, title => $title);
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
  my $authcookie = $self->signed_cookie($self->config->{account}->{authcookiename}) // '';
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
    script => $self->render_to_string(template => 'unauthenticated', format => 'js'),
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
  $web->{script} .= $self->render_to_string(template => 'account/panel/index', format => 'js');
  return $self->render(template => 'account/panel/index', web => $web, title => $title);
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


sub validate_username ($self, $username) {
  my $config = $self->config->{account}->{username};
  my $errors = [];

  # Check minimum length
  if (length($username) < $config->{minlength}) {
    push @$errors, $self->app->__x('Username must be at least {min} characters', min => $config->{minlength});
  }

  # Check allowed characters
  my $allowed_chars = $config->{chars};
  if ($username !~ /^[$allowed_chars]+$/) {
    push @$errors, $self->app->__x('Username can only contain {chars}', chars => $allowed_chars);
  }

  return @$errors ? $errors : undef;
}

sub validate_password ($self, $password) {
  my $config = $self->config->{account}->{password};
  my $errors = [];

  # Check minimum length
  if (length($password) < $config->{minlength}) {
    push @$errors, $self->app->__x('Password must be at least {min} characters', min => $config->{minlength});
  }

  # Check minimum uppercase
  my $uppercase_count = () = $password =~ /[A-Z]/g;
  if ($uppercase_count < $config->{minuppercase}) {
    push @$errors, $self->app->__x('Password must contain at least {min} uppercase letter(s)', min => $config->{minuppercase});
  }

  # Check minimum lowercase
  my $lowercase_count = () = $password =~ /[a-z]/g;
  if ($lowercase_count < $config->{minlowercase}) {
    push @$errors, $self->app->__x('Password must contain at least {min} lowercase letter(s)', min => $config->{minlowercase});
  }

  # Check minimum numbers
  my $number_count = () = $password =~ /[0-9]/g;
  if ($number_count < $config->{minnumbers}) {
    push @$errors, $self->app->__x('Password must contain at least {min} number(s)', min => $config->{minnumbers});
  }

  # Check minimum special characters
  my $special_chars = $config->{chars};
  $special_chars =~ s/[a-zA-Z0-9]//g;  # Remove alphanumeric to get special chars
  my $special_count = () = $password =~ /[\Q$special_chars\E]/g;
  if ($special_count < $config->{minspecial}) {
    push @$errors, $self->app->__x('Password must contain at least {min} special character(s)', min => $config->{minspecial});
  }

  return @$errors ? $errors : undef;
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