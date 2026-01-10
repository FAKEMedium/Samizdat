package Samizdat::Model::Email;

use Mojo::Base -base, -signatures;
use Mojo::Util qw(trim);
use Data::Dumper;

has 'config';
has 'pg';
has 'mysql';

sub database ($self) {
  return ('mysql' eq ($self->config->{dbtype} // 'postgresql')) ? $self->mysql->db : $self->pg->db;
}

# Domain methods
sub get_domains ($self, $params = {}) {
  my $where = $params->{where} || {};
  my $order = $params->{order} || 'domain ASC';
  my $limit = $params->{limit};
  my $offset = $params->{offset} || 0;

  my $sql = 'SELECT * FROM postfix.domain';
  my @bind;
  my @conditions = ("domain != 'ALL'");  # Exclude ALL (used for defaults)

  if (keys %$where) {
    for my $key (keys %$where) {
      if (ref $where->{$key} eq 'HASH' && exists $where->{$key}{'-like'}) {
        push @conditions, "$key ILIKE ?";
        push @bind, $where->{$key}{'-like'};
      } else {
        push @conditions, "$key = ?";
        push @bind, $where->{$key};
      }
    }
  }

  $sql .= ' WHERE ' . join(' AND ', @conditions);
  $sql .= " ORDER BY $order";
  $sql .= " LIMIT $limit" if $limit;
  $sql .= " OFFSET $offset" if $offset;

  return $self->database->query($sql, @bind)->hashes->to_array;
}

sub find_domain ($self, $domain) {
  return $self->database->query('SELECT * FROM postfix.domain WHERE domain = ?', $domain)->hash;
}

sub create_domain ($self, $data) {
  $data->{created} = \'NOW()';
  $data->{modified} = \'NOW()';
  return $self->database->insert('postfix.domain', $data, {returning => '*'})->hash;
}

sub update_domain ($self, $domain, $data) {
  $data->{modified} = \'NOW()';
  return $self->database->update('postfix.domain', $data, {domain => $domain}, {returning => '*'})->hash;
}

sub delete_domain ($self, $domain) {
  my $db = $self->database;
  my $tx = $db->begin;

  # Delete all aliases for this domain
  $tx->db->delete('postfix.alias', {domain => $domain});

  # Delete all mailboxes for this domain
  $tx->db->delete('postfix.mailbox', {domain => $domain});

  # Delete alias_domain entry if this domain is an alias domain
  $tx->db->delete('postfix.alias_domain', {alias_domain => $domain});

  # Delete alias_domain entries where this domain is the target
  $tx->db->delete('postfix.alias_domain', {target_domain => $domain});

  # Delete the domain itself
  my $result = $tx->db->delete('postfix.domain', {domain => $domain}, {returning => '*'})->hash;
  $tx->commit;

  return $result;
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
      if (ref $where->{$key} eq 'HASH' && exists $where->{$key}{'-like'}) {
        push @conditions, "$key ILIKE ?";
        push @bind, $where->{$key}{'-like'};
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

  return $self->database->query($sql, @bind)->hashes->to_array;
}

sub find_mailbox ($self, $username) {
  return $self->database->query('SELECT * FROM postfix.mailbox WHERE username = ?', $username)->hash;
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

  return $self->database->insert('postfix.mailbox', $data, {returning => '*'})->hash;
}

sub update_mailbox ($self, $username, $data) {
  $data->{modified} = \'NOW()';
  return $self->database->update('postfix.mailbox', $data, {username => $username}, {returning => '*'})->hash;
}

sub delete_mailbox ($self, $username) {
  my $db = $self->database;

  # Extract domain from username
  my ($domain) = $username =~ /\@(.+)$/;

  my $tx = $db->begin;

  # Delete aliases that forward to this mailbox (within same domain)
  if (defined $domain) {
    $tx->db->delete('postfix.alias', {
      goto => $username,
      domain => $domain
    });
  }

  my $result = $tx->db->delete('postfix.mailbox', {username => $username}, {returning => '*'})->hash;
  $tx->commit;

  return $result;
}

# Alias methods
sub get_aliases ($self, $params = {}) {
  my $where = $params->{where} || {};
  my $order = $params->{order} || 'address ASC';
  my $limit = $params->{limit};
  my $offset = $params->{offset} || 0;
  my $exclude_mailboxes = $params->{exclude_mailboxes} // 1;  # Default: exclude mailbox aliases

  my $sql = 'SELECT * FROM postfix.alias';
  my @bind;
  my @conditions;

  # Exclude aliases that are mailboxes (managed through mailbox interface)
  if ($exclude_mailboxes) {
    push @conditions, 'address NOT IN (SELECT username FROM postfix.mailbox)';
  }

  if (keys %$where) {
    for my $key (keys %$where) {
      if (ref $where->{$key} eq 'HASH' && exists $where->{$key}{'-like'}) {
        push @conditions, "$key ILIKE ?";
        push @bind, $where->{$key}{'-like'};
      } else {
        push @conditions, "$key = ?";
        push @bind, $where->{$key};
      }
    }
  }

  $sql .= ' WHERE ' . join(' AND ', @conditions) if @conditions;
  $sql .= " ORDER BY $order";
  $sql .= " LIMIT $limit" if $limit;
  $sql .= " OFFSET $offset" if $offset;

  return $self->database->query($sql, @bind)->hashes->to_array;
}

sub find_alias ($self, $address) {
  return $self->database->query('SELECT * FROM postfix.alias WHERE address = ?', $address)->hash;
}

sub create_alias ($self, $data) {
  $data->{created} = \'NOW()';
  $data->{modified} = \'NOW()';

  # Extract domain from address
  if ($data->{address} =~ /\@(.+)$/) {
    $data->{domain} = $1;
  }

  return $self->database->insert('postfix.alias', $data, {returning => '*'})->hash;
}

sub update_alias ($self, $address, $data) {
  $data->{modified} = \'NOW()';
  return $self->database->update('postfix.alias', $data, {address => $address}, {returning => '*'})->hash;
}

sub delete_alias ($self, $address) {
  return $self->database->delete('postfix.alias', {address => $address}, {returning => '*'})->hash;
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

  return $self->database->query($sql, @bind)->hashes->to_array;
}

sub find_quota ($self, $username) {
  return $self->database->query('SELECT * FROM postfix.quota WHERE username = ?', $username)->hash;
}

sub update_quota ($self, $username, $data) {
  # Use INSERT to trigger merge_quota function
  return $self->database->insert('postfix.quota', {
    username => $username,
    bytes => $data->{bytes} || 0,
    messages => $data->{messages} || 0
  });
}

# Alias domain methods
sub get_alias_domains ($self, $params = {}) {
  my $where = $params->{where} || {};
  my $sql = 'SELECT * FROM postfix.alias_domain';
  my @bind;

  if (keys %$where) {
    my @conditions;
    for my $key (keys %$where) {
      push @conditions, "$key = ?";
      push @bind, $where->{$key};
    }
    $sql .= ' WHERE ' . join(' AND ', @conditions);
  }

  $sql .= ' ORDER BY alias_domain ASC';
  return $self->database->query($sql, @bind)->hashes->to_array;
}

sub find_alias_domain ($self, $domain) {
  return $self->database->query('SELECT * FROM postfix.alias_domain WHERE alias_domain = ?', $domain)->hash;
}

sub create_alias_domain ($self, $data) {
  $data->{created} = \'NOW()';
  $data->{modified} = \'NOW()';
  return $self->database->insert('postfix.alias_domain', $data, {returning => '*'})->hash;
}

sub delete_alias_domain ($self, $domain) {
  return $self->database->delete('postfix.alias_domain', {alias_domain => $domain}, {returning => '*'})->hash;
}

# Get alias domains that point TO a given target domain
sub get_alias_domains_for_target ($self, $target_domain) {
  my $sql = q{
    SELECT ad.alias_domain, ad.target_domain, ad.active, ad.created, ad.modified
    FROM postfix.alias_domain ad
    WHERE ad.target_domain = ?
    ORDER BY ad.alias_domain ASC
  };
  return $self->database->query($sql, $target_domain)->hashes->to_array;
}

# Get domains available as alias targets for a customer (domains not already used as alias_domain)
sub get_available_target_domains ($self, $customerid) {
  my $sql = q{
    SELECT d.domain, d.description
    FROM postfix.domain d
    WHERE d.customerid = ?
      AND d.domain NOT IN (SELECT alias_domain FROM postfix.alias_domain)
    ORDER BY d.domain ASC
  };
  return $self->database->query($sql, $customerid)->hashes->to_array;
}

# Admin methods
sub get_admins ($self, $params = {}) {
  my $where = $params->{where} || {};
  my $order = $params->{order} || 'username ASC';
  my $limit = $params->{limit};
  my $offset = $params->{offset} || 0;

  my $sql = 'SELECT username, created, modified, active, superadmin, phone, email_other FROM postfix.admin';
  my @bind;

  if (keys %$where) {
    my @conditions;
    for my $key (keys %$where) {
      if (ref $where->{$key} eq 'HASH' && exists $where->{$key}{'-like'}) {
        push @conditions, "$key ILIKE ?";
        push @bind, $where->{$key}{'-like'};
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

  return $self->database->query($sql, @bind)->hashes->to_array;
}

sub find_admin ($self, $username) {
  return $self->database->query(
    'SELECT username, created, modified, active, superadmin, phone, email_other FROM postfix.admin WHERE username = ?',
    $username
  )->hash;
}

sub create_admin ($self, $data) {
  $data->{created} = \'NOW()';
  $data->{modified} = \'NOW()';
  # Hash password if provided
  if ($data->{password}) {
    $data->{password} = $self->_hash_password($data->{password});
  }
  return $self->database->insert('postfix.admin', $data, {returning => 'username, created, modified, active, superadmin, phone, email_other'})->hash;
}

sub update_admin ($self, $username, $data) {
  $data->{modified} = \'NOW()';
  # Hash password if provided
  if ($data->{password}) {
    $data->{password} = $self->_hash_password($data->{password});
  }
  return $self->database->update('postfix.admin', $data, {username => $username}, {returning => 'username, created, modified, active, superadmin, phone, email_other'})->hash;
}

sub delete_admin ($self, $username) {
  return $self->database->delete('postfix.admin', {username => $username}, {returning => '*'})->hash;
}

sub count_admins ($self, $params = {}) {
  my $where = $params->{where} || {};
  my $sql = 'SELECT COUNT(*) as count FROM postfix.admin';
  my @bind;

  if (keys %$where) {
    my @conditions;
    for my $key (keys %$where) {
      if (ref $where->{$key} eq 'HASH' && exists $where->{$key}{'-like'}) {
        push @conditions, "$key ILIKE ?";
        push @bind, $where->{$key}{'-like'};
      } else {
        push @conditions, "$key = ?";
        push @bind, $where->{$key};
      }
    }
    $sql .= ' WHERE ' . join(' AND ', @conditions);
  }

  my $result = $self->database->query($sql, @bind)->hash;
  return $result->{count} || 0;
}

sub _hash_password ($self, $password) {
  # Use dovecot-compatible Argon2id password hashing
  require Crypt::Argon2;
  # Generate 16-byte random salt
  my $salt = join('', map { chr(int(rand(256))) } 1..16);
  # Parameters: t=3 (time cost), m=64M (memory), p=1 (parallelism), tag_size=32
  my $hash = Crypt::Argon2::argon2id_pass($password, $salt, 3, '64M', 1, 32);
  return '{ARGON2ID}' . $hash;
}

# Statistics and counts
sub count_domains ($self, $params = {}) {
  my $where = $params->{where} || {};
  my $sql = 'SELECT COUNT(*) as count FROM postfix.domain';
  my @bind;
  my @conditions = ("domain != 'ALL'");  # Exclude ALL (used for defaults)

  if (keys %$where) {
    for my $key (keys %$where) {
      if (ref $where->{$key} eq 'HASH' && exists $where->{$key}{'-like'}) {
        push @conditions, "$key ILIKE ?";
        push @bind, $where->{$key}{'-like'};
      } else {
        push @conditions, "$key = ?";
        push @bind, $where->{$key};
      }
    }
  }

  $sql .= ' WHERE ' . join(' AND ', @conditions);
  my $result = $self->database->query($sql, @bind)->hash;
  return $result->{count} || 0;
}

sub count_mailboxes ($self, $params = {}) {
  my $where = $params->{where} || {};
  my $sql = 'SELECT COUNT(*) as count FROM postfix.mailbox';
  my @bind;

  if (keys %$where) {
    my @conditions;
    for my $key (keys %$where) {
      if (ref $where->{$key} eq 'HASH' && exists $where->{$key}{'-like'}) {
        push @conditions, "$key ILIKE ?";
        push @bind, $where->{$key}{'-like'};
      } else {
        push @conditions, "$key = ?";
        push @bind, $where->{$key};
      }
    }
    $sql .= ' WHERE ' . join(' AND ', @conditions);
  }

  my $result = $self->pg->db->query($sql, @bind)->hash;
  return $result->{count} || 0;
}

sub count_aliases ($self, $params = {}) {
  my $where = $params->{where} || {};
  my $exclude_mailboxes = $params->{exclude_mailboxes} // 1;

  my $sql = 'SELECT COUNT(*) as count FROM postfix.alias';
  my @bind;
  my @conditions;

  # Exclude aliases that are mailboxes
  if ($exclude_mailboxes) {
    push @conditions, 'address NOT IN (SELECT username FROM postfix.mailbox)';
  }

  if (keys %$where) {
    for my $key (keys %$where) {
      if (ref $where->{$key} eq 'HASH' && exists $where->{$key}{'-like'}) {
        push @conditions, "$key ILIKE ?";
        push @bind, $where->{$key}{'-like'};
      } else {
        push @conditions, "$key = ?";
        push @bind, $where->{$key};
      }
    }
  }

  $sql .= ' WHERE ' . join(' AND ', @conditions) if @conditions;

  my $result = $self->database->query($sql, @bind)->hash;
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

  return $self->database->query($sql, $domain)->hash;
}

1;
