package Samizdat::Model::Email;

use Mojo::Base -base, -signatures;
use Mojo::Util qw(trim);
use Data::Dumper;

has 'config';
has 'pg';
has 'mysql';

# Domain methods
sub get_domains ($self, $params = {}) {
  my $where = $params->{where} || {};
  my $order = $params->{order} || 'domain ASC';
  my $limit = $params->{limit};
  my $offset = $params->{offset} || 0;

  my $sql = 'SELECT * FROM postfix.domain';
  my @bind;

  if (keys %$where) {
    my @conditions;
    for my $key (keys %$where) {
      push @conditions, "$key = ?";
      push @bind, $where->{$key};
    }
    $sql .= ' WHERE ' . join(' AND ', @conditions);
  }

  $sql .= " ORDER BY $order";
  $sql .= " LIMIT $limit" if $limit;
  $sql .= " OFFSET $offset" if $offset;

  return $self->pg->db->query($sql, @bind)->hashes->to_array;
}

sub find_domain ($self, $domain) {
  return $self->pg->db->query('SELECT * FROM postfix.domain WHERE domain = ?', $domain)->hash;
}

sub create_domain ($self, $data) {
  $data->{created} = \'NOW()';
  $data->{modified} = \'NOW()';
  return $self->pg->db->insert('postfix.domain', $data, {returning => '*'})->hash;
}

sub update_domain ($self, $domain, $data) {
  $data->{modified} = \'NOW()';
  return $self->pg->db->update('postfix.domain', $data, {domain => $domain}, {returning => '*'})->hash;
}

sub delete_domain ($self, $domain) {
  return $self->pg->db->delete('postfix.domain', {domain => $domain}, {returning => '*'})->hash;
}

# Mailbox methods
sub get_mailboxes ($self, $params = {}) {
  my $where = $params->{where} || {};
  my $order = $params->{order} || 'username ASC';
  my $limit = $params->{limit};
  my $offset = $params->{offset} || 0;

  my $sql = 'SELECT * FROM postfix.mailbox';
  my @bind;

  if (keys %$where) {
    my @conditions;
    for my $key (keys %$where) {
      push @conditions, "$key = ?";
      push @bind, $where->{$key};
    }
    $sql .= ' WHERE ' . join(' AND ', @conditions);
  }

  $sql .= " ORDER BY $order";
  $sql .= " LIMIT $limit" if $limit;
  $sql .= " OFFSET $offset" if $offset;

  return $self->pg->db->query($sql, @bind)->hashes->to_array;
}

sub find_mailbox ($self, $username) {
  return $self->pg->db->query('SELECT * FROM postfix.mailbox WHERE username = ?', $username)->hash;
}

sub create_mailbox ($self, $data) {
  $data->{created} = \'NOW()';
  $data->{modified} = \'NOW()';

  # Extract domain from username
  if ($data->{username} =~ /\@(.+)$/) {
    $data->{domain} = $1;
    $data->{local_part} = substr($data->{username}, 0, rindex($data->{username}, '@'));
  }

  # Set maildir path if not provided
  $data->{maildir} ||= $data->{username} . '/';

  return $self->pg->db->insert('postfix.mailbox', $data, {returning => '*'})->hash;
}

sub update_mailbox ($self, $username, $data) {
  $data->{modified} = \'NOW()';
  return $self->pg->db->update('postfix.mailbox', $data, {username => $username}, {returning => '*'})->hash;
}

sub delete_mailbox ($self, $username) {
  return $self->pg->db->delete('postfix.mailbox', {username => $username}, {returning => '*'})->hash;
}

# Alias methods
sub get_aliases ($self, $params = {}) {
  my $where = $params->{where} || {};
  my $order = $params->{order} || 'address ASC';
  my $limit = $params->{limit};
  my $offset = $params->{offset} || 0;

  my $sql = 'SELECT * FROM postfix.alias';
  my @bind;

  if (keys %$where) {
    my @conditions;
    for my $key (keys %$where) {
      push @conditions, "$key = ?";
      push @bind, $where->{$key};
    }
    $sql .= ' WHERE ' . join(' AND ', @conditions);
  }

  $sql .= " ORDER BY $order";
  $sql .= " LIMIT $limit" if $limit;
  $sql .= " OFFSET $offset" if $offset;

  return $self->pg->db->query($sql, @bind)->hashes->to_array;
}

sub find_alias ($self, $address) {
  return $self->pg->db->query('SELECT * FROM postfix.alias WHERE address = ?', $address)->hash;
}

sub create_alias ($self, $data) {
  $data->{created} = \'NOW()';
  $data->{modified} = \'NOW()';

  # Extract domain from address
  if ($data->{address} =~ /\@(.+)$/) {
    $data->{domain} = $1;
  }

  return $self->pg->db->insert('postfix.alias', $data, {returning => '*'})->hash;
}

sub update_alias ($self, $address, $data) {
  $data->{modified} = \'NOW()';
  return $self->pg->db->update('postfix.alias', $data, {address => $address}, {returning => '*'})->hash;
}

sub delete_alias ($self, $address) {
  return $self->pg->db->delete('postfix.alias', {address => $address}, {returning => '*'})->hash;
}

# Quota methods
sub get_quotas ($self, $params = {}) {
  my $where = $params->{where} || {};
  my $order = $params->{order} || 'username ASC';
  my $limit = $params->{limit};
  my $offset = $params->{offset} || 0;

  my $sql = 'SELECT * FROM postfix.quota';
  my @bind;

  if (keys %$where) {
    my @conditions;
    for my $key (keys %$where) {
      push @conditions, "$key = ?";
      push @bind, $where->{$key};
    }
    $sql .= ' WHERE ' . join(' AND ', @conditions);
  }

  $sql .= " ORDER BY $order";
  $sql .= " LIMIT $limit" if $limit;
  $sql .= " OFFSET $offset" if $offset;

  return $self->pg->db->query($sql, @bind)->hashes->to_array;
}

sub find_quota ($self, $username) {
  return $self->pg->db->query('SELECT * FROM postfix.quota WHERE username = ?', $username)->hash;
}

sub update_quota ($self, $username, $data) {
  # Use INSERT to trigger merge_quota function
  return $self->pg->db->insert('postfix.quota', {
    username => $username,
    bytes => $data->{bytes} || 0,
    messages => $data->{messages} || 0
  });
}

# Statistics and counts
sub count_domains ($self, $params = {}) {
  my $where = $params->{where} || {};
  my $sql = 'SELECT COUNT(*) as count FROM postfix.domain';
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

sub count_mailboxes ($self, $params = {}) {
  my $where = $params->{where} || {};
  my $sql = 'SELECT COUNT(*) as count FROM postfix.mailbox';
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

sub count_aliases ($self, $params = {}) {
  my $where = $params->{where} || {};
  my $sql = 'SELECT COUNT(*) as count FROM postfix.alias';
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

# Get domain statistics
sub domain_stats ($self, $domain) {
  my $sql = q{
    SELECT
      d.domain,
      d.description,
      d.active,
      d.mailboxes as mailbox_limit,
      d.aliases as alias_limit,
      d.maxquota,
      d.quota,
      (SELECT COUNT(*) FROM postfix.mailbox WHERE domain = d.domain) as mailbox_count,
      (SELECT COUNT(*) FROM postfix.alias WHERE domain = d.domain) as alias_count,
      (SELECT SUM(quota) FROM postfix.mailbox WHERE domain = d.domain) as total_mailbox_quota,
      (SELECT SUM(bytes) FROM postfix.quota q
       JOIN postfix.mailbox m ON q.username = m.username
       WHERE m.domain = d.domain) as total_used_quota
    FROM postfix.domain d
    WHERE d.domain = ?
  };

  return $self->pg->db->query($sql, $domain)->hash;
}

1;
