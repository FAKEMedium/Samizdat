package Samizdat::Controller::Login;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::JSON qw(j);
use Mojo::Util qw(b64_encode);
use DateTime;
use DateTime::TimeZone;
use Date::Calc qw(Today Add_Delta_Days Date_to_Text Parse_Date Date_to_Days Delta_Days);
use Data::Dumper;

sub index {
  my $self = shift;
  my $loginfailures = $self->account->getLoginFailures($self->config->{account}->{blocklimit}, {
    ip => ${ $self->req->headers->{'headers'}->{'remote_host'} }[0]
      // ${ $self->req->headers->{'headers'}->{'x-forwarded-for'} }[0]
      // '0.0.0.0',
    blocktime => $self->config->{account}->{blocktime}
  });
  my $count = int @{ $loginfailures };
  if ($self->config->{account}->{blocklimit} <= $count) {
    my $out = ${ $loginfailures }[0];
    $out->{count} = $count;
    $out->{failuretime} = substr($out->{failuretime}, 11, 5);
    $out->{template} = 'login/loginblocked';
    return $self->render(%{ $out });
  } else {
    return $self->render(template => 'login/index');
  }
}


sub logout {
  my $self = shift;
  my $username = $self->session('username');
  $self->session(expires => 1);
  $self->cookie(aaadata => '', {
    secure => 1,
    httponly => 0,
    path => '/',
    expires => 1,
    domain => $self->config->{cookiedomain},
    hostonly => 1,
  });
  return $self->render(json => {
    success => 1,
    username => $username,
    javascript => sprintf('location.assign("%s")', '/')
  });
}


sub login {
  my $self = shift;
  my ($username, $password);
  if ( ($self->tx->req->method eq 'POST') && CORE::index($self->req->body, '{') >= 0 ) {
    my $text = Mojo::JSON::decode_json($self->req->body);
    ($username, $password) = ($text->{username}, $text->{'password'});
  } else {
    ($username, $password) = ($self->param('username'), $self->param('password'));
  }
  my $v = $self->_loginValidation;
  if ($v->has_error) {
    return $self->render(json => {
      success => 0,
      error   => $self->app->__x('Enter username and password'),
      step    => 1,
      test    => 'missing_credentials'
    }, status => 200);
  }
  my $ip = ${ $self->req->headers->{'headers'}->{'remote_host'} }[0]
    // ${ $self->req->headers->{'headers'}->{'x-forwarded-for'} }[0]
    // '0.0.0.0';

  my $loginfailures = $self->account->getLoginFailures($self->config->{account}->{blocklimit}, {
    ip => $ip,
    blocktime => $self->config->{account}->{blocktime}
  });
  my $count = int @{ $loginfailures };
  if (5 < $count) {
    return $self->render(json => {
      success => 0,
      'ip'          => ${ $loginfailures }[0]->{ip},
      'username'    => ${ $loginfailures }[0]->{username},
      'failuretime' => substr(${ $loginfailures }[0]->{failuretime}, 11, 5),
      'count'       => $count,
    });
  }
  my $userid;
  if (
    exists($self->config->{account}->{superadmins}->{$username})
      && ($self->config->{account}->{superadmins}->{$username} eq $password)
  ) {
    $userid = 1;
  } else {
    $userid = eval {return $self->account->validatePassword($username, $password, $self->config->{account})};
  }
  unless ($userid) {
    say Dumper my $failure = {
      ip => $ip,
      'username' => $username,
      'failuretime' => 'now()',
    };
    my $error = $self->app->__x('Failed login from {ip}', $ip);
    $error = sprintf('%s <span class="badge badge-primary">%d/5</span><span class="sr-only"> %s</span>',
      $error,
      $count,
      $self->app->__('login attempts'),
    );
    $self->account->insertLoginFailure($failure);
    if (5 > scalar @{ $loginfailures }) {
      return $self->render(json => {success => 0, error => $error, step => 3}, status => 200);
    } else {
      return $self->render('login/loginblocked',
        'ip' => ${$loginfailures}[0]->{ip},
        'username' => ${ $loginfailures }[0]->{username},
        'failuretime' => substr(${ $loginfailures }[0]->{failuretime}, 11, 5),
        'count' => scalar @{ $loginfailures },
        'format' => 'json'
      );
      #      return $self->render(json => {success => 0, html => $html, step => 2}, status => 200);
    }

  } else {
    my $user = ${ $self->account->getUsers({ id => $userid }) }[0];

    $self->session(authenticated => $userid);
    $self->session(username => $user->{'username'});
    $self->session(expiration => 36000);
    $self->session(superadmin => $self->config->{account}->{superadmins}->{$user->{'username'}} // 0);
    my $value = j {
      'd' => $user->{'displayname'},
      'n' => $user->{'username'},
      'i' => $userid,
      'e' => '1',
      't' => '',
      'm' => '0',
      'l' => 'en',
      's' => $self->config->{account}->{superadmins}->{$user->{'username'}} // 0,
    };
    $value = b64_encode($value);
    chomp $value;
    $value =~ s/[\r\n\=]+//g;

    $self->cookie(userdata => $value, {
      secure => 1,
      httponly => 0,
      path => '/',
      expires => time + 36000,
      domain => $self->config->{cookiedomain},
      hostonly => 1,
    });

    $self->account->insertLogin($userid, $ip);
    $self->app->__x('You were logged in as {username}.', 'username' => $username),
    $self->app->__x('In your personal menu you find your {panel} among other things.',
      panel => sprintf('<a href="/panel">%s</a>', $self->app->__('control panel'))
    );
    $self->render(json => {success => 1, step => 0, 'username' => $username});
  }
}

sub _loginValidation {
  my $self = shift;

  my $v = $self->validation;
  $v->required('username');
  $v->required('password');

  return $v;
}

1;

__DATA__

@@ loginfailure

<%= $error %> <span class="badge badge-primary"><%= $count %>/5</span>
<span class="sr-only"> <%= __('login attempts') %></span>