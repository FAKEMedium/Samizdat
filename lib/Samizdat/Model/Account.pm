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


sub addUser {
  my $self = shift;
  my $username = shift;
  my $attribs = shift // undef;
  $attribs->{username} = $username;
  my $password = delete $attribs->{password};
  my $userid = $self->app->pg->db->insert('account.user',
    $attribs,
    { returning => 'id' }
  )->hash->{id};
  $self->app->pg->db->insert('account.password', {
    userid => $userid,

  });
  return $userid;
}


sub getUsers {
  my $self = shift;
  my $where = shift;

  my $result = $self->app->pg->db->select('account.user',
    undef,
    $where
  )->hashes->to_array;
}


sub saveUser {
  my $self = shift;
  my $userid = shift;
  my $attribs = shift // undef;
  $self->app->pg->db->update('account.user',
    $attribs,
    {userid => $userid},
    { returning => 'id' }
  )->hash->{id};
}


sub deleteUser {
  my $self = shift;
  my $userid = shift;

  $self->app->pg->db->delete('account.user', {id => $userid});
}


sub savePassword {
  my $self = shift;
  my $userid = shift;
  my $password = shift;
}


sub validatePassword {
  my $self = shift;
  my $username = shift;
  my $plain = shift;
  my $accountcfg = shift;
  my $userid = undef;

  # Superadmins in the configuration file don't need to be in the database
  if ($accountcfg->{superadmins}->{$username} eq $plain) {
    $userid = 1; # Equivalent to unix root
  } else {
    my $result = $self->app->pg->db->select([ 'account.user', [ -left => 'account.password', id => 'userid' ] ])->hash;
    for my $method (@{ $accountcfg->{passwordmethods} }) {
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


sub cryptPassword {
  my $self = shift;
  my ($password, $method) = @_;
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


sub getLoginFailures {
  my $self = shift;
  my $limit = shift;
  my $options = shift;
  my $failuretime = sprintf("now() - interval '%s'", $options->{blocktime});
  my $result = $self->app->pg->db->query("
    SELECT failuretime,ip,username
    FROM account.loginfailure
    WHERE (failuretime >= $failuretime) AND (ip = ?)
    ORDER BY failuretime DESC
    LIMIT ?",
    $options->{ip},
    $limit
  )->hashes->to_array;
  return $result;
}


sub insertLogin {
  my $self = shift;
  my $userid = shift;
  my $ip = shift;
  $self->app->pg->db->insert('account.login', {
    userid => $userid,
    ip     => $ip,
  }, {returning => 'id'})->hash->{id};
}


sub insertLoginFailure {
  my $self = shift;
  my $username = shift;
  my $ip = shift;
  $self->app->pg->db->insert('account.loginfailure', {
    ip       => $ip,
    username => $username,
  }, {returning => 'id'})->hash->{id};
}


1;