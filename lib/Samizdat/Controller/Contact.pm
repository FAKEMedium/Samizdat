package Samizdat::Controller::Contact;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use MIME::Lite;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::Util qw(decode encode b64_encode trim);

sub index ($self) {
  my $formdata = { ip => $self->tx->remote_address };
  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept =~ /json/) {
    my $valid = {};
    my $errors = {};
    my $v = $self->validation;

    for my $field (qw(name email subject message captcha)) {
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

    # Fill in some fields if user is logged in
    if ('GET' eq uc $self->req->method) {
      # Pre-fill form with user data if logged in
      if (eval { $self->app->account }) {
        # First try to get the session user
        my $session = $self->session('user');
        my $user;

        if ($session && $session->{username}) {
          # Get full user details from database
          my $users = $self->app->account->getUsers({ 'users.username' => $session->{username} });
          $user = $users->[0] if $users && @$users;
        }

        # Fallback to authenticated_user if available
        $user ||= eval { $self->app->account->authenticated_user() };

        if ($user) {
          # Debug: Log what we got
          $self->app->log->debug("Contact form user data: " . ($self->app->dumper($user) || 'none'));

          # Pre-fill email if empty
          $formdata->{email} //= $user->{email} if $user->{email};

          # Pre-fill name if empty
          if (!$formdata->{name} || $formdata->{name} eq '') {
            if ($user->{givenname} || $user->{commonname}) {
              $formdata->{name} = join(' ', grep { $_ } ($user->{givenname}, $user->{commonname}));
            } elsif ($user->{username}) {
              $formdata->{name} = $user->{username};
            }
          }
        }
      }
    }

    $formdata->{errors} = $errors;
    $formdata->{valid} = $valid;
    if ($v->has_error) {
      $formdata->{success} = 0;
    } else {
      $formdata->{success} = 1;
      $formdata->{whois} = qx!whois $formdata->{ip}!;
      my $maildata = $self->render_mail(template => 'contact/message', formdata => $formdata);
      my $subject = Encode::encode("MIME-Q", $formdata->{subject});
      $formdata->{$maildata } = $maildata;
      my $from = Encode::encode("MIME-Q", sprintf('"%s" <%s>', $formdata->{name}, $formdata->{email}));
      my $mail = MIME::Lite->new(
        From         => $from,
        To           => $self->config->{mail}->{to},
        Subject      => $subject,
        'X-Mailer'   => "Samizdat",
        Data         => $maildata,
      );
      $mail->send($self->config->{mail}->{how}, @{$self->config->{mail}->{howargs}});
      $formdata->{sent} = Encode::decode 'UTF-8', Encode::encode 'UTF-8',
          $self->render_to_string(template => 'contact/sent', layout => undef, formdata => $formdata);
    }
    $self->tx->res->headers->content_type('application/json; charset=UTF-8');
    return $self->render(json => $formdata, status => 200);
  }

  my $title = $self->app->__('Contact');
  my $web = { title => $title };
  $web->{script} .= $self->render_to_string(template => 'contact/index', formdata => { ip => 'REPLACEIP' }, format => 'js');
  $web->{sidebar} = $self->render_to_string(template => 'contact/sidebar', format => 'html');
  return $self->render(web => $web, title => $title, template => 'contact/index', formdata => { ip => 'REPLACEIP' }, status => 200);
}


1;