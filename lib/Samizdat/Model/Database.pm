package Samizdat::Model::Database;

use Mojo::Base -base, -signatures;

has 'config';
has 'pg';
has 'mysql';

sub database ($self) {
  return ('mysql' eq ($self->config->{dbtype} // 'postgresql')) ? $self->mysql->db : $self->pg->db;
}

sub _table ($self) {
  my $dbtype = $self->config->{dbtype} // 'postgresql';
  return ($dbtype eq 'mysql') ? '`databases`' : 'database.databases';
}

sub _types_table ($self) {
  my $dbtype = $self->config->{dbtype} // 'postgresql';
  return ($dbtype eq 'mysql') ? '`databasetypes`' : 'database.databasetypes';
}

sub get ($self, $params = {}) {
  my $db = $self->database;
  my $where = $params->{where} // {};
  my $limit = $params->{limit} // {};

  my @args = ($self->_table, '*', $where);
  push @args, $limit if keys %$limit;
  return $db->select(@args)->hashes;
}

sub get_types ($self) {
  my $db = $self->database;
  return $db->select($self->_types_table)->hashes;
}

sub create ($self, $data) {
  my $db = $self->database;
  return $db->insert($self->_table, $data, { returning => 'databaseid' })->hash->{databaseid};
}

sub update ($self, $databaseid, $data) {
  my $db = $self->database;
  $data->{updated} = \'NOW()';
  return $db->update($self->_table, $data, { databaseid => $databaseid });
}

sub delete ($self, $databaseid) {
  my $db = $self->database;
  return $db->delete($self->_table, { databaseid => $databaseid });
}

sub neighbours ($self, $databaseid) {
  my $db = $self->database;
  my $table = $self->_table;
  my $result = {
    minid  => $db->query("SELECT MIN(databaseid) AS minid FROM $table")->hash->{minid},
    maxid  => $db->query("SELECT MAX(databaseid) AS maxid FROM $table")->hash->{maxid},
    previd => $db->query("SELECT MAX(databaseid) AS previd FROM $table WHERE databaseid < ?", $databaseid)->hash->{previd},
    nextid => $db->query("SELECT MIN(databaseid) AS nextid FROM $table WHERE databaseid > ?", $databaseid)->hash->{nextid},
  };
  $result->{previd} //= $result->{minid};
  $result->{nextid} //= $result->{maxid};
  return $result;
}

1;
