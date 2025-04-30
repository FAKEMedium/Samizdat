package Samizdat::Model::Email;

use Mojo::Base -base, -signatures;
use Mojo::Util qw(trim);
use Data::Dumper;

has 'config';
has 'pg';
has 'mysql';


sub get ($self, $params = {}) {
  my $db = $self->mysql->db;
  my $where = $params->{where} // {};
  return $db->select('maildomain', "*", $where)->hashes;
}


1;