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

has 'pg';

my $pbkdf2 = Crypt::PBKDF2->new();


sub addUser {
  my $self = shift;
  my $username = shift;
  my $attribs = shift // undef;
  $attribs->{username} = $username;
  my $password = delete $attribs->{password};
  my $userid = $self->pg->db->insert('account.users', $attribs, { returning => 'id' })->hash->{id};
  $self->pg->db->insert('account.passwords', {
    userid => $userid,

  });
  return $userid;
}

sub getUsers {
  my $self = shift;
  my $where = shift;
  return $self->pg->db->select('account.users', undef, $where);
}


sub saveUser {
  my $self = shift;
  my $userid = shift;
  my $attribs = shift // undef;
  $self->pg->db->update('account.users', $attribs, {userid => $userid});
}


sub deleteUser {
  my $self = shift;
  my $userid = shift;

}

sub savePassword {
  my $self = shift;
  my $userid = shift;
  my $password = shift;
}

sub check {
  my $self = shift;
  my $username = shift;
  my $password = shift;
}

1;


__END__