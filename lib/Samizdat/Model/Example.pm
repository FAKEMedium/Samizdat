package Samizdat::Model::Example;

use Mojo::Base -base, -signatures;
use Data::Dumper;

has 'pg';
has 'config';

# Get examples from database with optional filtering
sub get ($self, $params = {}) {
  my $where = $params->{where} || {};
  my $order = $params->{order} || 'created DESC';
  my $limit = $params->{limit};
  my $offset = $params->{offset} || 0;

  # Build SQL query dynamically
  my $sql = 'SELECT * FROM example.example';
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

# Get a single example by ID
sub find ($self, $id) {
  return $self->pg->db->query('SELECT * FROM example.example WHERE id = ?', $id)->hash;
}

# Create a new example
sub create ($self, $data) {
  # Set timestamps
  $data->{created} = \'NOW()';
  $data->{updated} = \'NOW()';

  return $self->pg->db->insert('example.example', $data, {returning => '*'})->hash;
}

# Update an existing example
sub update ($self, $id, $data) {
  # Update timestamp
  $data->{updated} = \'NOW()';

  return $self->pg->db->update('example.example', $data, {id => $id}, {returning => '*'})->hash;
}

# Delete an example
sub delete ($self, $id) {
  return $self->pg->db->delete('example.example', {id => $id}, {returning => '*'})->hash;
}

# Count examples matching criteria
sub count ($self, $params = {}) {
  my $where = $params->{where} || {};

  my $sql = 'SELECT COUNT(*) as count FROM example.example';
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

# Search examples with full-text search
sub search ($self, $searchterm, $params = {}) {
  my $limit = $params->{limit} || 50;
  my $offset = $params->{offset} || 0;

  my $sql = q{
    SELECT * FROM example.example
    WHERE
      title ILIKE ? OR
      description ILIKE ? OR
      content ILIKE ?
    ORDER BY created DESC
    LIMIT ? OFFSET ?
  };

  my $pattern = '%' . $searchterm . '%';

  return $self->pg->db->query($sql, $pattern, $pattern, $pattern, $limit, $offset)->hashes->to_array;
}

# Get statistics about examples
sub stats ($self, $params = {}) {
  my $sql = q{
    SELECT
      COUNT(*) as total,
      COUNT(CASE WHEN status = 'active' THEN 1 END) as active,
      COUNT(CASE WHEN status = 'inactive' THEN 1 END) as inactive,
      COUNT(CASE WHEN created > NOW() - INTERVAL '7 days' THEN 1 END) as recent
    FROM example.example
  };

  return $self->pg->db->query($sql)->hash;
}

1;