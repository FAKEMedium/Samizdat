package Samizdat::Model::Certificate;

use Mojo::Base -base, -signatures;

has 'pg';
has 'config';

sub get ($self, $params = {}) {
  my $db = $self->pg->db;
  my $where = $params->{where} // {};
  my $limit = $params->{limit};
  my $offset = $params->{offset} // 0;

  my $where_sql = '';
  my @bind;

  if ($where->{certificateid}) {
    $where_sql = 'WHERE c.certificateid = ?';
    push @bind, $where->{certificateid};
  } elsif ($where->{customerid}) {
    $where_sql = 'WHERE c.customerid = ?';
    push @bind, $where->{customerid};
  } elsif ($where->{hash}) {
    $where_sql = 'WHERE c.hash = ?';
    push @bind, $where->{hash};
  }

  my $limit_sql = '';
  $limit_sql .= " LIMIT $limit" if $limit;
  $limit_sql .= " OFFSET $offset" if $offset;

  my $sql = qq{
    SELECT
      c.certificateid,
      c.customerid,
      c.value,
      c.fullvalue,
      c.notafter,
      c.keyfile,
      c.certfile,
      c.hash,
      c.issuerid,
      i.issuername
    FROM certificate.certificates c
    LEFT JOIN certificate.issuers i ON c.issuerid = i.issuerid
    $where_sql
    ORDER BY c.notafter DESC
    $limit_sql
  };

  return $db->query($sql, @bind)->hashes->to_array;
}

sub find ($self, $id) {
  my $results = $self->get({ where => { certificateid => $id } });
  return $results->[0];
}

sub find_by_hash ($self, $hash) {
  my $results = $self->get({ where => { hash => $hash } });
  return $results->[0];
}

sub create ($self, $data) {
  my $db = $self->pg->db;

  my $insert = {
    customerid => $data->{customerid},
    value      => $data->{value},
    fullvalue  => $data->{fullvalue},
    notafter   => $data->{notafter},
    keyfile    => $data->{keyfile},
    certfile   => $data->{certfile},
    hash       => $data->{hash} // _generate_hash($data->{value}),
    issuerid   => $data->{issuerid},
  };

  return $db->insert('certificate.certificates', $insert, { returning => '*' })->hash;
}

sub update ($self, $id, $data) {
  my $db = $self->pg->db;

  my $update = {};
  $update->{customerid} = $data->{customerid} if exists $data->{customerid};
  $update->{value}      = $data->{value} if exists $data->{value};
  $update->{fullvalue}  = $data->{fullvalue} if exists $data->{fullvalue};
  $update->{notafter}   = $data->{notafter} if exists $data->{notafter};
  $update->{keyfile}    = $data->{keyfile} if exists $data->{keyfile};
  $update->{certfile}   = $data->{certfile} if exists $data->{certfile};
  $update->{hash}       = $data->{hash} if exists $data->{hash};
  $update->{issuerid}   = $data->{issuerid} if exists $data->{issuerid};

  return $db->update('certificate.certificates', $update, { certificateid => $id }, { returning => '*' })->hash if %$update;
  return $self->find($id);
}

sub delete ($self, $id) {
  my $db = $self->pg->db;
  return $db->delete('certificate.certificates', { certificateid => $id }, { returning => '*' })->hash;
}

sub count ($self, $params = {}) {
  my $db = $self->pg->db;
  my $where = $params->{where} // {};

  my $sql = 'SELECT COUNT(*) as count FROM certificate.certificates';
  my @bind;

  if ($where->{customerid}) {
    $sql .= ' WHERE customerid = ?';
    push @bind, $where->{customerid};
  }

  return $db->query($sql, @bind)->hash->{count} // 0;
}

sub get_expiring ($self, $days = 30) {
  my $db = $self->pg->db;

  my $sql = qq{
    SELECT
      c.certificateid,
      c.customerid,
      c.notafter,
      c.keyfile,
      c.certfile,
      c.hash,
      i.issuername
    FROM certificate.certificates c
    LEFT JOIN certificate.issuers i ON c.issuerid = i.issuerid
    WHERE c.notafter <= NOW() + INTERVAL '$days days'
      AND c.notafter > NOW()
    ORDER BY c.notafter ASC
  };

  return $db->query($sql)->hashes->to_array;
}

sub get_expired ($self) {
  my $db = $self->pg->db;

  my $sql = q{
    SELECT
      c.certificateid,
      c.customerid,
      c.notafter,
      c.keyfile,
      c.certfile,
      c.hash,
      i.issuername
    FROM certificate.certificates c
    LEFT JOIN certificate.issuers i ON c.issuerid = i.issuerid
    WHERE c.notafter <= NOW()
    ORDER BY c.notafter DESC
  };

  return $db->query($sql)->hashes->to_array;
}

sub issuers ($self) {
  my $db = $self->pg->db;
  return $db->select('certificate.issuers', '*', undef, { -order_by => 'issuername' })->hashes->to_array;
}

sub find_issuer ($self, $id) {
  my $db = $self->pg->db;
  return $db->select('certificate.issuers', '*', { issuerid => $id })->hash;
}

sub find_issuer_by_name ($self, $name) {
  my $db = $self->pg->db;
  return $db->select('certificate.issuers', '*', { issuername => $name })->hash;
}

sub create_issuer ($self, $name) {
  my $db = $self->pg->db;
  return $db->insert('certificate.issuers', { issuername => $name }, { returning => '*' })->hash;
}

sub _generate_hash ($value) {
  return undef unless $value;
  require Digest::SHA;
  return Digest::SHA::sha256_hex($value);
}

1;
