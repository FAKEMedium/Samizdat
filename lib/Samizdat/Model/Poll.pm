package Samizdat::Model::Poll;

use Mojo::Base -base, -signatures;

has 'pg';

sub addsigner ($self, $signer) {
  return $self->pg->db->insert('poll.signers', $signer, {returning => 'signerid'})->hash->{signerid};
}

sub signers ($self, $pollid = 1, $limit = 10) {
  my $where = { pollid => $pollid, confirmed => {'=', undef}};
  my $other = { order_by => {-desc => 'signerid'}, limit => $limit };
  return $self->pg->db->select('poll.signers', '*', $where, $other)->hashes->to_array;
}

sub getsigner ($self, $signerid = 0) {
  return $self->pg->db->select('poll.signers', '*', {signerid => $signerid})->hash;
}

sub removesigner ($self, $signerid = 0) {
  $self->pg->db->delete('poll.signers', {signerid => $signerid});
}

sub savesigner ($self, $signerid, $signer) {
  $self->pg->db->update('poll.signers', $signer, {signerid => $signerid});
}


sub addpoll ($self, $poll) {
  return $self->pg->db->insert('poll.polls', $poll, {returning => 'pollid'})->hash->{pollid};
}

sub getpoll ($self, $pollid = 0) {
  if (!$pollid) {

  }
  return $self->pg->db->select('poll.polls', '*', {pollid => $pollid})->hash;
}

1;