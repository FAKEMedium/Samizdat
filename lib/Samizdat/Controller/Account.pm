package Samizdat::Controller::Account;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::JSON qw(j);
use Mojo::Util qw(b64_encode);
use DateTime;
use DateTime::TimeZone;
use Date::Calc qw(Today Add_Delta_Days Date_to_Text Parse_Date Date_to_Days Delta_Days);
use Data::Dumper;


sub login ($self) {
  if (lc $self->req->method eq 'get') {
    my $title = $self->app->__('Log in');
    my $web = { title => $title };
    $self->stash(scriptname => '/login');
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
  my $loginfailures = $self->account->getLoginFailures($ip);
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
    $userid = eval {return $self->account->validatePassword($username, $password)};
    if ($userid) {
      $user = ${$self->account->getUsers({ id => $userid })}[0];
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
    my $db = $self->redis->db;
    my $authcookie = $self->app->uuid->create_str();

    $db->hmset("samizdat:$authcookie",
      userid     => $userid,
      username   => $user->{username},
      superadmin => $user->{superadmin},
      value      => $value,
      ip         => $ip,
    );
    $db->expire("samizdat:$authcookie", 3600);

    $self->signed_cookie($self->config->{authcookiename} => $authcookie, {
      secure => 0,
      httponly => 0,
      path => '/',
      expires => time + 3600,
      domain => $self->config->{cookiedomain},
      hostonly => 1,
    });
    $self->cookie($self->config->{datacookiename} => $value, {
      secure => 0,
      httponly => 0,
      path => '/',
      expires => time + 3600,
      domain => $self->config->{cookiedomain},
      hostonly => 1,
    });
    $self->account->insertLogin($ip, $userid, $value);
    $self->render(json => { userdata => $userdata }, status => 200);

  } else {
    $self->account->insertLoginFailure($ip, $username);
    return $self->render(json => { error => { reason => 'password', count => $count },
      ip         => $ip,
      blocklimit => $self->config->{account}->{blocklimit},
      blocktime  => $self->config->{account}->{blocktime}
    }, status => 403);
  }
}

sub logout ($self) {
  my $authcookie = $self->signed_cookie($self->config->{authcookiename});
  my $db = $self->redis->db;
  my $session = $db->hgetall("samizdat:$authcookie");

  my $username = $session->{username};
  $self->cookie($self->config->{authcookiename} => '', {
    secure => 0,
    httponly => 0,
    path => '/',
    expires => 1,
    domain => $self->config->{cookiedomain},
    hostonly => 1,
  });
  $self->cookie($self->config->{datacookiename} => '', {
    secure => 0,
    httponly => 0,
    path => '/',
    expires => 1,
    domain => $self->config->{cookiedomain},
    hostonly => 1,
  });
  return $self->redirect_to('/');
}

sub register ($self) {
  if (lc $self->req->method eq 'get') {
    my $title = $self->app->__('Register account');
    my $web = { title => $title };
    $self->stash(scriptname => '/register');
    $web->{script} .= $self->app->indent($self->render_to_string(template => 'account/register', format => 'js'), 4);
    return $self->render(template => 'account/register', web => $web, title => $title);
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


sub password ($self) {
  if (lc $self->req->method eq 'get') {
    my $title = $self->app->__('Change password');
    my $web = { title => $title };
    $self->stash(scriptname => '/register/password');
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


sub authorize ($self) {
  my $authcookie = $self->signed_cookie($self->config->{authcookiename});
  if ($authcookie) {
    my $db = $self->redis->db;
    my $session = $db->hgetall("samizdat:$authcookie");
    say Dumper $session;
    if ($session->{superadmin}) {
      return 1;
    } else {
      $self->render(template => 'forbidden', status => 403);
      return undef;
    }
  }
  my $web = {
    script => $self->app->indent($self->render_to_string(template => 'unauthenticated', format => 'js'), 0)
  };
  $self->render(template => 'unauthenticated', status => 401, web => $web);
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
  $self->stash(scriptname => '/panel');
  $web->{script} .= $self->app->indent($self->render_to_string(template => 'account/panel', format => 'js'), 4);
  return $self->render(template => 'account/panel', web => $web, title => $title, docpath => 'panel/index.html');
}

sub user ($self) {

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

Copyright 2024 Hans Svensson

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut