package Samizdat::Model::Poll;

use Mojo::Base -base, -signatures;

has 'config';
has 'database';

sub addsigner ($self, $signer) {
  my $db = $self->database->db;
  return $db->insert('poll.signers', $signer, {returning => 'signerid'})->hash->{signerid};
}

sub signers ($self, $pollid = 1, $limit = 10) {
  my $db = $self->database->db;
  my $where = { pollid => $pollid, confirmed => {'=', undef}};
  my $other = { order_by => {-desc => 'signerid'}, limit => $limit };
  return $db->select('poll.signers', '*', $where, $other)->hashes->to_array;
}

sub getsigner ($self, $signerid = 0) {
  my $db = $self->database->db;
  return $db->select('poll.signers', '*', {signerid => $signerid})->hash;
}

sub removesigner ($self, $signerid = 0) {
  my $db = $self->database->db;
  $db->delete('poll.signers', {signerid => $signerid});
}

sub savesigner ($self, $signerid, $signer) {
  my $db = $self->database->db;
  $db->update('poll.signers', $signer, {signerid => $signerid});
}


sub addpoll ($self, $poll) {
  my $db = $self->database->db;
  return $db->insert('poll.polls', $poll, {returning => 'pollid'})->hash->{pollid};
}

sub getpoll ($self, $pollid = 0) {
  if (!$pollid) {

  }
  my $db = $self->database->db;
  return $db->select('poll.polls', '*', {pollid => $pollid})->hash;
}

1;