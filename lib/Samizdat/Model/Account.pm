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

has 'config';
has 'database'; # Mojo::Pg or Mojo::mysql
has 'redis';

my $pbkdf2 = Crypt::PBKDF2->new();

sub username ($self, $cookie) {
  my $db = $self->database->db;
  return 1; # Temporary solution
}

sub addUser ($self, $username, $attribs = undef) {
  my $db = $self->database->db;
  my $userid = 0;
  $attribs->{username} = $username;
  delete $attribs->{password};
  if ('mysql' eq $self->config->{databasetype}) {
    $userid = $db->insert('snapusers',
      $attribs,
      { returning => 'id' }
    )->hash->{id};
    $db->insert('passwords', {
      userid => $userid,
    });
  } else {
    $userid = $db->insert('account.users',
      $attribs,
      { returning => 'id' }
    )->hash->{id};
    $db->insert('account.password', {
      userid => $userid,
    });
  }
  return $userid;
}


sub getUsers ($self, $where){
  my $db = $self->database->db;
  my $result;
  if ('mysql' eq $self->config->{databasetype}) {
    $result = $db->select('snapusers',
      undef,
      $where
    )->hashes->to_array;
  } else {
   $result = $db->select('account.users',
      undef,
      $where
    )->hashes->to_array;
  }
  retun $result;
}


sub saveUser ($self, $userid, $attribs = undef) {
  my $db = $self->database->db;
  if ('mysql' eq $self->config->{databasetype}) {
    $db->update('snapusers',
      $attribs,
      {userid => $userid},
      { returning => 'id' }
    )->hash->{id};
  } else {
    $db->update('account.users',
      $attribs,
      { userid => $userid },
      { returning => 'id' }
    )->hash->{id};
  }
}


sub deleteUser ($self, $userid) {
  my $db = $self->database->db;
  if ('mysql' eq $self->config->{databasetype}) {
    $db->delete('snapusers', { id => $userid });
  } else {
    $db->delete('account.users', { id => $userid });
  }
}


sub savePassword ($self, $userid, $password) {
  my $db = $self->database->db;
  my $attribs = {};
  for my $method (@{ $self->config->{passwordmethods} }) {
    $attribs->{'password' . $method} = $self->hashPassword($password, $method);
  }

  if ('mysql' eq $self->config->{databasetype}) {
  } else {
    $db->update('account.passwords',
      $attribs,
      { userid => $userid },
      { returning => 'id' }
    )->hash->{id};
  }
}


sub validatePassword ($self, $username, $plain) {
  my $userid = 0;
  my $db = $self->database->db;

  # Superadmins in the configuration file don't need to be in the database
  if ($self->config->{superadmins}->{$username} eq $plain) {
    $userid = 1;
  } else {
    my $result;
    if ('mysql' eq $self->config->{databasetype}) {
      $result = $db->select([ 'snapusers', [ -left => 'passwords', id => 'userid' ] ], 'passwords.*', {'snapusers.username' => $username})->hash;
    } else {
      $result = $db->select([ 'account.users', [ -left => 'account.password', id => 'userid' ] ])->hash;
    }

    for my $method (@{ $self->config->{passwordmethods} }) {
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

sub session ($self, $authcookie) {
  my $session = $self->redis->db->hgetall("samizdat:$authcookie");
  $self->redis->db->del("samizdat:$authcookie");
  return $session;
}

sub logout ($self, $authcookie) {
  my $session = $self->redis->db->hgetall("samizdat:$authcookie");
  $self->redis->db->del("samizdat:$authcookie");
  return $session;
}

sub login ($self, $authcookie, $data) {
  $self->redis->db->hmset("samizdat:$authcookie", %$data);
  $self->redis->db->expire("samizdat:$authcookie", 3600);
}

sub insertLogin ($self, $ip, $userid, $value) {
  my $db = $self->database->db;
  if ('mysql' eq $self->config->{databasetype}) {
    $db->insert('snapallsessions', {
      userlogin   => $userid,
      remote_host => $ip,
      value       => $value
    }, {returning => 'allsessionid'})->hash->{allsessionid};
  } else {
    $db->insert('account.logins', {
      userid => $userid,
      ip     => $ip,
    }, { returning => 'id' })->hash->{id};
  }
}


sub insertLoginFailure ($self, $ip, $username) {
  my $db = $self->database->db;
  if ('mysql' eq $self->config->{databasetype}) {
    $db->insert('loginfailures', {
      ip       => $ip,
      username => $username
    }, {returning => 'loginfailureid'})->hash->{loginfailureid};
  } else {
    $db->insert('account.loginfailures', {
      ip       => $ip,
      username => $username,
    }, { returning => 'id' })->hash->{id};
  }
}


sub getLoginFailures ($self, $ip) {
  my $db = $self->database->db;
  my $result;
  if ('mysql' eq $self->config->{databasetype}) {
    $result = $db->query("
      SELECT failuretime,ip,username
      FROM loginfailures
      WHERE (failuretime >=  now() - interval ? minute) AND (ip = ?)
      ORDER BY failuretime DESC LIMIT ?",
        $self->config->{blocktime},
        $ip,
        $self->config->{blocklimit}
    )->hashes->to_array;
  } else {
    $result = $db->query("
      SELECT failuretime,ip,username
      FROM account.loginfailures
      WHERE failuretime >= now() - (? * interval '1 minute') AND (ip = ?)
      ORDER BY failuretime DESC LIMIT ?",
        $self->config->{blocktime},
        $ip,
        $self->config->{blocklimit}
    )->hashes->to_array;
  }
  return $result;
}


1;