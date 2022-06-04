package Samizdat::Model::Account;

use strict;
use warnings FATAL => 'all';
use experimental qw(signatures);
use Mojo::Base -base;
use Bytes::Random::Secure::Tiny;
use Crypt::Argon2 qw/argon2id_pass argon2id_verify/;
use Crypt::PBKDF2;
use Digest::SHA1 qw/sha1 sha1_hex/;
use App::bmkpasswd -all;

has 'db';

my $pbkdf2 = Crypt::PBKDF2->new();


sub addUser {
  my $self = shift;
  my $username = shift;
  my $attribs = shift // undef;
  $attribs->{username} = $username;
  my $password = delete $attribs->{password};
  my $userid = $self->db->insert('account.users', $attribs, { returning => 'id' })->hash->{id};
  $self->db->insert('account.passwords', {
    userid => $userid,

  });
  return $userid;
}

sub getUsers {
  my $self = shift;
  my $where = shift;
  my $result = $self->db->select('account.users', undef, $where)->hashes->to_array;
}


sub saveUser {
  my $self = shift;
  my $userid = shift;
  my $attribs = shift // undef;
  $self->db->update('account.users', $attribs, {userid => $userid});
}


sub deleteUser {
  my $self = shift;
  my $userid = shift;

  $self->db->delete('account.user', {id => $userid});
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

  my $result = $self->db->select(['account.users', [-left => 'account.password', id => 'userid']])->hash;
  for my $method (@{ $accountcfg->{passwordmethods} }) {
    if ($method eq "sha512") {
      return passwdcmp($plain, $result->{passwordsha512});
    }
    elsif ($method eq "bcrypt") {
      return passwdcmp($plain, $result->{passwordbcrypt});
    }
    elsif ($method eq "argon2id") {
      return argon2id_verify($result->{passwordargon2id}, $plain);
    }
    elsif ($method eq "mysql") {
      return $result->{passwordmysql} eq sprintf('*%s', uc sha1_hex(sha1($plain)));
    }
    elsif ($method eq "pbkdf2") {
      return $pbkdf2->validate($result->{passwordpbkdf2}, $plain);
    }
  }
  return undef;
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
  my $result = $self->db->select('account.loginfailure',
    ['failuretime','ip','username'],
    {
      failuretime => { '>=', \{$failuretime} },
      ip => $options->{ip},
    },
    {
      limit => $limit,
      order_by => { -desc => 'failuretime' },
    }
  )->hashes->to_array;
  return $result;
}

sub insertLogin {
  my $self = shift;
  my $userid = shift;
  my $ip = shift;
  $self->db->insert('account.login', {
    userid => $userid,
    ip     => $ip,
  }, {returning => 'id'})->hash->{id};
}

sub insertLoginFailure {
  my $self = shift;
  my $username = shift;
  my $ip = shift;
  $self->db->insert('account.loginfailure', {
    ip       => $ip,
    username => $username,
  }, {returning => 'id'})->hash->{id};
}

1;