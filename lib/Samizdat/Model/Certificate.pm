package Samizdat::Model::Certificate;

use Mojo::Base -base, -signatures;
use Data::Dumper;

has 'pg';
has 'config';

# Get certificates from database with optional filtering
sub get ($self, $params = {}) {
  my $where = $params->{where} || {};
  my $order = $params->{order} || 'created DESC';
  my $limit = $params->{limit};
  my $offset = $params->{offset} || 0;

  # Build SQL query dynamically
  my $sql = 'SELECT * FROM certificates.certificates';
  my @bind;

  if (keys %$where) {
    my @conditions;
    for my $key (keys %$where) {
      if (ref $where->{$key} eq 'HASH') {
        # Handle operators like {-like => '%value%'}
        my ($op, $val) = each %{$where->{$key}};
        $op =~ s/^-//;
        push @conditions, "$key $op ?";
        push @bind, $val;
      } elsif (ref $where->{$key} eq 'ARRAY') {
        # Handle IN queries
        my $placeholders = join(',', ('?') x @{$where->{$key}});
        push @conditions, "$key IN ($placeholders)";
        push @bind, @{$where->{$key}};
      } else {
        push @conditions, "$key = ?";
        push @bind, $where->{$key};
      }
    }
    $sql .= ' WHERE ' . join(' AND ', @conditions);
  }

  $sql .= " ORDER BY $order";
  $sql .= " LIMIT $limit" if $limit;
  $sql .= " OFFSET $offset" if $offset;

  return $self->pg->db->query($sql, @bind)->hashes->to_array;
}

# Get a single certificate by ID
sub find ($self, $id) {
  return $self->pg->db->query('SELECT * FROM certificates.certificates WHERE certificateid = ?', $id)->hash;
}

# Create a new certificate
sub create ($self, $data) {
  # Set timestamps
  $data->{created} = \'NOW()';
  $data->{updated} = \'NOW()';

  return $self->pg->db->insert('certificates.certificates', $data, {returning => '*'})->hash;
}

# Update an existing certificate
sub update ($self, $id, $data) {
  # Update timestamp
  $data->{updated} = \'NOW()';

  return $self->pg->db->update('certificates.certificates', $data, {certificateid => $id}, {returning => '*'})->hash;
}

# Delete a certificate
sub delete ($self, $id) {
  return $self->pg->db->delete('certificates.certificates', {certificateid => $id}, {returning => '*'})->hash;
}

# Count certificates matching criteria
sub count ($self, $params = {}) {
  my $where = $params->{where} || {};

  my $sql = 'SELECT COUNT(*) as count FROM certificates.certificates';
  my @bind;

  if (keys %$where) {
    my @conditions;
    for my $key (keys %$where) {
      push @conditions, "$key = ?";
      push @bind, $where->{$key};
    }
    $sql .= ' WHERE ' . join(' AND ', @conditions);
  }

  my $result = $self->pg->db->query($sql, @bind)->hash;
  return $result->{count} || 0;
}

# Search certificates with full-text search
sub search ($self, $searchterm, $params = {}) {
  my $limit = $params->{limit} || 50;
  my $offset = $params->{offset} || 0;

  my $sql = q{
    SELECT * FROM certificates.certificates
    WHERE
      domain ILIKE ? OR
      commonname ILIKE ? OR
      issuer ILIKE ?
    ORDER BY created DESC
    LIMIT ? OFFSET ?
  };

  my $pattern = '%' . $searchterm . '%';

  return $self->pg->db->query($sql, $pattern, $pattern, $pattern, $limit, $offset)->hashes->to_array;
}

# Get expiring certificates (within X days)
sub get_expiring ($self, $days = 30) {
  my $sql = q{
    SELECT * FROM certificates.certificates
    WHERE expires_at <= NOW() + INTERVAL '? days'
      AND expires_at > NOW()
    ORDER BY expires_at ASC
  };

  return $self->pg->db->query($sql, $days)->hashes->to_array;
}

# Get expired certificates
sub get_expired ($self) {
  my $sql = q{
    SELECT * FROM certificates.certificates
    WHERE expires_at <= NOW()
    ORDER BY expires_at DESC
  };

  return $self->pg->db->query($sql)->hashes->to_array;
}

1;
