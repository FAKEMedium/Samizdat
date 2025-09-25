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

sub pass ($self) {
  return 1;
}


sub index ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0] // '';

  # Handle JSON requests
  if ($accept =~ /json/) {
    return unless $self->access({ 'valid-user' => 1 });
    my $user = $self->authenticated_user();
    return $self->render(json => { success => 1, user => $user }, status => 200);
  } else {
    # Render HTML page
    my $title = $self->app->__('Panel');
    my $web = { title => $title };
    $self->stash(user => $self->authenticated_user());
    $web->{script} .= $self->render_to_string(template => 'account/index', format => 'js');
    return $self->render(template => 'account/index', web => $web, title => $title);
  }
}


sub login ($self) {
  if ($self->req->method =~ /^(GET)$/i) {
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
  my $ip = $self->getip;
  my $loginfailures = $self->app->account->getLoginFailures($ip);
  my $count = scalar @{ $loginfailures };
  if ($count >= $self->config->{manager}->{account}->{blocklimit}) {
    return $self->render(json => { error => { reason => 'blocked' },
      ip         => $ip,
      blocklimit => $self->config->{manager}->{account}->{blocklimit},
      blocktime  => $self->config->{manager}->{account}->{blocktime}
    }, status => 200);
  }

  my $userid = undef;
  my $user = {
    superadmin => 0
  };
  my $username = $v->param('username');
  my $password = $v->param('password');

  if (exists($self->config->{manager}->{account}->{superadmins}->{$username}) && ($self->config->{manager}->{account}->{superadmins}->{$username} eq $password)) {
    $userid = 0;
    $user = {
      userid      => 0,
      username    => $username,
      superadmin  => 1,
      displayname => 'Super admin',
    };
  } else {
    $userid = eval { return $self->app->account->validatePassword($username, $password)};
    if ($userid) {
      $user = ${$self->app->account->getUsers({ 'users.userid' => $userid })}[0];
    }
  }

  if (defined $userid) {
    # Preparing a cookie with user data to be used in the browser
    my $userdata = {
      'd' => $user->{displayname},                                                              # Long display name
      'n' => $user->{username},                                                                 # Username, short display name
      'i' => $userid,                                                                           # User ID
      'e' => $user->{email} // '',                                                              # Email address
      't' => '',
      'm' => '0',
      'l' => 'en',                                                                              # Language, default is English
      's' => exists($self->config->{manager}->{account}->{superadmins}->{$user->{'username'}}) ? 1 : 0,    # Super admin flag
      'a' => exists($self->config->{manager}->{account}->{admins}->{$user->{'username'}}) ? 1 : 0,         # Admin flag
      'i' => $ip,                                                                               # IP address
    };
    my $value = b64_encode(j $userdata);
    chomp $value;
    $value =~ s/[\r\n]+//g;
    my $expires = $self->config->{manager}->{account}->{sessiontimeout};
    my $cookie_opts = {
      secure => 1,
      httponly => 0,
      path => '/',
      domain => $self->config->{manager}->{account}->{cookiedomain},
      hostonly => 1,
      same_site => 'Lax',
      expires => time + $expires,
    };
    my $authcookie = $self->app->uuid->create_str();
    $self->app->account->addSession($authcookie, {
      userid     => $userid,
      username   => $user->{username},
      superadmin => $user->{superadmin},
      value      => $value,
      ip         => $ip,
      groups     => join(':', map { $_->{groupid} } @{$self->app->account->getUserGroups($userid)}),
    }, $expires);
    $self->cookie($self->config->{manager}->{account}->{authcookiename} => $authcookie, $cookie_opts);
    $self->cookie($self->config->{manager}->{account}->{datacookiename} => $value, $cookie_opts);

    $self->app->account->insertLogin($ip, $userid, $authcookie);
    $self->render(json => { userdata => $userdata }, status => 200);

  } else {
    $self->app->account->insertLoginFailure($ip, $username);
    return $self->render(json => { error => { reason => 'password', count => $count },
      ip         => $ip,
      blocklimit => $self->config->{manager}->{account}->{blocklimit},
      blocktime  => $self->config->{manager}->{account}->{blocktime}
    }, status => 403);
  }
}


sub logout ($self) {
  my $cookie_opts = {
    secure => 1,
    httponly => 0,
    path => '/',
    expires => time - 10000,
    domain => $self->config->{manager}->{account}->{cookiedomain},
    hostonly => 1,
  };
  $self->cookie($self->config->{manager}->{account}->{authcookiename} => '', $cookie_opts);
  $self->cookie($self->config->{manager}->{account}->{datacookiename} => '', $cookie_opts);
  $self->app->account->deleteSession($self->config->{manager}->{account}->{authcookiename});
  return $self->redirect_to('/');
}


sub register ($self) {
  my $formdata = {};
  my $accept = $self->req->headers->{headers}->{accept}->[0] // '';
  
  if ($accept =~ /json/) {
    $formdata->{ip} = $self->getip;
    if ($self->req->method =~ /^(POST)$/i) {
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
          my $from = Encode::encode("MIME-Q", sprintf('%s <%s>', $self->config->{organization}, $self->config->{mail}->{from}));
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
    }
    
    # Return JSON response for both POST and GET
    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $formdata, status => 200);
  }

  # Handle regular GET request (return HTML page)
  my $title = $self->app->__('Register account');
  my $web = { title => $title };
  $web->{sidebar} = $self->render_to_string(template => 'account/register/sidebar');
  $web->{script} .= $self->render_to_string(template => 'account/register/index', formdata => { ip => 'REPLACEIP' }, format => 'js');
  return $self->render(web => $web, title => $title, template => 'account/register/index', formdata => { ip => 'REPLACEIP' }, status => 200);
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
}


sub authenticated_user ($self) {
  my $authcookie = $self->cookie($self->config->{manager}->{account}->{authcookiename});
  if ($authcookie) {
    my $session = $self->app->account->session($authcookie);
    if ($session && %$session) {
      # Refresh browser cookie to match Redis expiration
      my $cookie_opts = {
        secure    => 1,
        httponly  => 0,
        path      => '/',
        domain    => $self->config->{manager}->{account}->{cookiedomain},
        hostonly  => 1,
        same_site => 'Lax',
        expires   => time + $self->config->{manager}->{account}->{sessiontimeout},
      };
      $self->cookie($self->config->{manager}->{account}->{authcookiename} => $authcookie, $cookie_opts);
      say Dumper $session;
      return $session;
    }
  }
  return undef;
}


sub authorize ($self, $level = 0) {
  my $authcookie = $self->cookie($self->config->{manager}->{account}->{authcookiename}) // '';
  if ($authcookie) {
    my $session = $self->app->account->session($authcookie);
    if ($session->{username}) {
      # Refresh browser cookie to match Redis expiration  
      $self->cookie($self->config->{manager}->{account}->{authcookiename} => $authcookie, {
        expires => time + $self->config->{manager}->{account}->{sessiontimeout},
        secure => 1,
        httponly => 0,
        path => '/',
        domain => $self->config->{manager}->{account}->{cookiedomain},
        hostonly => 1,
        same_site => 'Lax',
      });
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
  my $title = $self->app->__('Account settings');
  if ($self->req->headers->accept =~ m{application/json}) {
    return unless $self->access({ 'valid-user' => 1 });
    my $user = $self->authenticated_user();

    # Check if user is authenticated
    unless ($user && $user->{userid}) {
      return $self->render(json => {
        success => 0,
        error => 'Not authenticated'
      }, status => 401);
    }

    if ($self->req->method eq 'POST') {
      # Handle profile data update via AJAX
      return $self->update_profile();
    } else {
      # Return current profile data as JSON
      my $profile;
      eval {
        $profile = $self->app->account->get_profile($user->{userid});
      };
      if ($@) {
        return $self->render(json => {
          success => 0,
          error => "Failed to get profile: $@"
        }, status => 500);
      }

      return $self->render(json => {
        success => 1,
        profile => $profile // {}
      });
    }
  } else {
    # Render HTML settings page
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'account/settings/index', format => 'js');
    return $self->render(template => 'account/settings/index', web => $web, title => $title);
    return 1;
  }
}

# Update user profile data
sub update_profile ($self) {
  return unless $self->access({ 'valid-user' => 1 });
  my $user = $self->authenticated_user();

  my $profile_data = $self->req->json;
  unless ($profile_data) {
    return $self->render(json => {
      success => 0,
      error => 'Invalid JSON data'
    }, status => 400);
  }

  eval {
    $self->app->account->update_profile($user->{userid}, $profile_data);
    $self->render(json => {
      success => 1,
      message => 'Profile updated successfully'
    });
  };
  if ($@) {
    $self->app->log->error("Failed to update profile: $@");
    $self->render(json => {
      success => 0,
      error => 'Failed to update profile'
    }, status => 500);
  }
}

# Handle profile image upload
sub upload_image ($self) {
  return unless $self->access({ 'valid-user' => 1 });
  my $user = $self->authenticated_user();

  my $upload = $self->req->upload('image');
  unless ($upload) {
    return $self->render(json => {
      success => 0,
      error => 'No image file provided'
    }, status => 400);
  }

  # Validate file type and size
  my $content_type = $upload->headers->content_type;
  unless ($content_type =~ /^image\/(jpeg|jpg|png|webp)$/i) {
    return $self->render(json => {
      success => 0,
      error => 'Invalid image format. Use JPG, PNG, or WebP'
    }, status => 400);
  }

  if ($upload->size > 2 * 1024 * 1024) { # 2MB limit
    return $self->render(json => {
      success => 0,
      error => 'Image too large. Maximum size is 2MB'
    }, status => 400);
  }

  eval {
    # Generate filename using user UUID and original extension
    my $user_uuid = $user->{uuid} || $user->{userid};
    my $ext = $1 if $content_type =~ /image\/(\w+)/;
    $ext = 'jpg' if $ext eq 'jpeg';
    
    my $filename = "${user_uuid}.${ext}";
    my $user_dir = Mojo::Home->new('src/public/user');
    $user_dir->make_path unless -d $user_dir;
    
    my $file_path = $user_dir->child($filename);
    $upload->move_to($file_path);
    
    # Store image reference in profile
    my $image_url = "/user/${filename}";
    $self->app->account->update_profile($user->{userid}, {
      images => { avatar => $image_url }
    });
    
    $self->render(json => {
      success => 1,
      message => 'Image uploaded successfully',
      imagePath => $image_url
    });
  };
  if ($@) {
    $self->app->log->error("Image upload failed: $@");
    $self->render(json => {
      success => 0,
      error => 'Failed to upload image'
    }, status => 500);
  }
}


sub validate_username ($self, $username) {
  my $config = $self->config->{manager}->{account}->{username};
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
  my $config = $self->config->{manager}->{account}->{password};
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