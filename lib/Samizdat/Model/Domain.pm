package Samizdat::Model::Domain;

use Mojo::Base -base, -signatures;
use Mojo::Util qw(trim);
use Data::Dumper;

has 'config';
has 'pg';
has 'mysql';

sub database ($self) {
  return ('mysql' eq ($self->config->{dbtype} // 'postgresql')) ? $self->mysql->db : $self->pg->db;
}

sub get ($self, $params = {}) {
  my $db = $self->database;
  my $where = $params->{where} // {};
  my $due = sprintf("IF((DATEDIFF(NOW(), curexpiry) > %d) AND (dontrenew = 0), 1, 0) AS due", 60);
  return $db->select('domain', "*, $due", $where)->hashes;
}


1;