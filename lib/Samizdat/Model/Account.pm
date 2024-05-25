package Samizdat::Model::Account;

use Mojo::Base -base, -signatures;
#use warnings;
#use diagnostics;
use Bytes::Random::Secure::Tiny;
use Crypt::Argon2 qw/argon2id_pass argon2id_verify/;
use Crypt::PBKDF2;
use Digest::SHA1 qw/sha1 sha1_hex/;
use App::bmkpasswd -all;
use Data::Dumper;

has 'app';

my $pbkdf2 = Crypt::PBKDF2->new();


sub addUser ($self, $username, $attribs = undef) {
  my $db = $self->app->mysql->db;

  $attribs->{username} = $username;
  my $password = delete $attribs->{password};
=pod
  my $userid = $db->insert('account.user',
    $attribs,
    { returning => 'id' }
  )->hash->{id};
  $db->insert('account.password', {
    userid => $userid,
  });
=cut

  my $userid = $db->insert('snapusers',
    $attribs,
    { returning => 'id' }
  )->hash->{id};
  $db->insert('passwords', {
    userid => $userid,
  });
  return $userid;
}


sub getUsers ($self, $where){
  my $db = $self->app->mysql->db;
=pod
  my $result = $db->select('account.user',
    undef,
    $where
  )->hashes->to_array;
=cut

  my $result = $db->select('snapusers',
    undef,
    $where
  )->hashes->to_array;
}


sub saveUser ($self, $userid, $attribs = undef) {
  my $db = $self->app->mysql->db;
=pod
  $db->update('account.user',
    $attribs,
    {userid => $userid},
    { returning => 'id' }
  )->hash->{id};
=cut
  $db->update('snapusers',
    $attribs,
    {userid => $userid},
    { returning => 'id' }
  )->hash->{id};
}


sub deleteUser ($self, $userid) {
  my $db = $self->app->mysql->db;

#  $db->delete('account.user', {id => $userid});
  $db->delete('snapusers', {id => $userid});

}


sub savePassword ($self, $userid, $password) {
  my $db = $self->app->mysql->db;
  my $attribs = {};
  for my $method (@{ $self->app->config->{account}->{passwordmethods} }) {
    $attribs->{'password' . $method} = $self->hashPassword($password, $method);
  }
  $db->update('passwords',
    $attribs,
    {userid => $userid},
    { returning => 'id' }
  )->hash->{id};
}


sub validatePassword ($self, $username, $plain) {
  my $userid = 0;
  my $db = $self->app->mysql->db;

  # Superadmins in the configuration file don't need to be in the database
  if ($self->app->config->{account}->{superadmins}->{$username} eq $plain) {
    $userid = 1;
  } else {
#    my $result = $db->select([ 'account.user', [ -left => 'account.password', id => 'userid' ] ])->hash;
    my $result = $db->select([ 'snapusers', [ -left => 'passwords', id => 'userid' ] ], 'passwords.*', {'snapusers.username' => $username})->hash;

    for my $method (@{ $self->app->config->{account}->{passwordmethods} }) {
      if ($method eq "sha512") {
        if (passwdcmp($plain, $result->{passwordsha512})) {
          $userid = $result->{$userid};
          last;
        }
      } elsif ($method eq "bcrypt") {
        if (passwdcmp($plain, $result->{passwordbcrypt})) {
          $userid = $result->{$userid};
          last;
        }
      } elsif ($method eq "argon2id") {
        if (argon2id_verify($result->{passwordargon2id}, $plain)) {
          $userid = $result->{$userid};
          last;
        }
      } elsif ($method eq "mysql") {
        if ($result->{passwordmysql} eq sprintf('*%s', uc sha1_hex(sha1($plain)))) {
          $userid = $result->{$userid};
          last;
        }
      } elsif ($method eq "pbkdf2") {
        if ($pbkdf2->validate($result->{passwordpbkdf2}, $plain)) {
          $userid = $result->{$userid};
          last;
        }
      }
    }
  }
  return $userid;
}


sub hashPassword ($self, $password, $method) {
  if ($method eq "sha512") {
    return mkpasswd($password, 'sha512');
  } elsif ($method eq "bcrypt") {
    return mkpasswd($password, 'bcrypt', 10);
  } elsif ($method eq "argon2id") {
    my $rng = Bytes::Random::Secure::Tiny->new;
    return argon2id_pass($password, $rng->bytes_hex(16), 3, '32M', 1, 16);
  } elsif ($method eq "mysql") {
    return sprintf('*%s', uc sha1_hex(sha1($password)));
  } elsif ($method eq "pbkdf2") {
    return $pbkdf2->generate($password);
  }  else {
    warn sprintf('Unknown password encryption method: %s', $method);
    return undef;
  }
}




sub insertLogin ($self, $ip, $username, $value) {
  my $db = $self->app->mysql->db;
=pod
  $db->insert('account.login', {
    userid => $userid,
    ip     => $ip,
  }, {returning => 'id'})->hash->{id};
=cut
  $db->insert('snapallsessions', {
    userlogin   => $username,
    remote_host => $ip,
    value       => $value
  }, {returning => 'allsessionid'})->hash->{allsessionid};
}


sub insertLoginFailure ($self, $ip, $username) {
  my $db = $self->app->mysql->db;
=pod
  $db->insert('account.loginfailure', {
    ip       => $ip,
    username => $username,
  }, {returning => 'id'})->hash->{id};
=cut

  $db->insert('loginfailures', {
    ip       => $ip,
    username => $username
  }, {returning => 'loginfailureid'})->hash->{loginfailureid};
}


sub getLoginFailures ($self, $ip) {
  my $db = $self->app->mysql->db;
=pod
  my $result = $db->query("SELECT failuretime,ip,username FROM account.loginfailure WHERE (failuretime >= $failuretime) AND (ip = ?) ORDER BY failuretime DESC LIMIT ?",
    $options->{ip}, $limit
  )->hashes->to_array;
  return $result;
=cut
  my $result = $db->query("
    SELECT failuretime
    FROM loginfailures
    WHERE (failuretime >=  now() - interval ? minute) AND (ip = ?)
    ORDER BY failuretime DESC LIMIT ?",
      $self->app->config->{account}->{blocktime},
      $ip,
      $self->app->config->{account}->{blocklimit}
  )->hashes->to_array;
  return $result;
}


1;