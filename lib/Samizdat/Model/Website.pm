package Samizdat::Model::Website;

use Mojo::Base -base, -signatures;
use Socket qw(inet_pton AF_INET AF_INET6);

has 'pg';
has 'config';

sub get ($self, $params = {}) {
  my $db = $self->pg->db;
  my $where = $params->{where} // {};
  my $limit = $params->{limit} // {};
  my $searchterm = $params->{searchterm};

  my @where_clauses;
  my @bind;

  if ($where->{websiteid}) {
    push @where_clauses, 'w.websiteid = ?';
    push @bind, $where->{websiteid};
  }
  if ($where->{customerid}) {
    push @where_clauses, 'w.customerid = ?';
    push @bind, $where->{customerid};
  }
  if (defined $searchterm && $searchterm ne '') {
    push @where_clauses, '(d.domainname ILIKE ? OR w.home ILIKE ?)';
    push @bind, "%$searchterm%", "%$searchterm%";
  }

  my $where_sql = @where_clauses ? 'WHERE ' . join(' AND ', @where_clauses) : '';

  my $limit_sql = '';
  if (ref $limit eq 'HASH') {
    $limit_sql .= "ORDER BY $limit->{-order_by}" if $limit->{-order_by};
    $limit_sql .= " LIMIT $limit->{-limit}" if $limit->{-limit};
    $limit_sql .= " OFFSET $limit->{-offset}" if $limit->{-offset};
  }

  my $sql = qq{
    SELECT
      w.websiteid,
      w.customerid,
      w.home,
      w.serverid,
      w.passwordid,
      w.certificateid,
      w.shellid,
      w.ip4,
      w.ip6,
      w.ip_only,
      w.redirecturl,
      w.active,
      w.web_usage,
      w.primarydomain,
      d.domainname,
      s.hostname AS servername,
      st.servertypename,
      sh.shell
    FROM website.websites w
    LEFT JOIN website.domains d ON w.primarydomain = d.domainid
    LEFT JOIN website.servers s ON w.serverid = s.serverid
    LEFT JOIN website.servertypes st ON s.servertypeid = st.servertypeid
    LEFT JOIN website.shells sh ON w.shellid = sh.shellid
    $where_sql
    $limit_sql
  };

  return $db->query($sql, @bind)->hashes;
}

sub get_by_id ($self, $websiteid) {
  my $results = $self->get({ where => { websiteid => $websiteid } });
  return $results->[0];
}

sub get_by_customer ($self, $customerid) {
  return $self->get({ where => { customerid => $customerid } });
}

sub domains ($self, $params = {}) {
  my $db = $self->pg->db;
  my $where = $params->{where} // {};

  my $where_sql = '';
  my @bind;

  if ($where->{websiteid}) {
    $where_sql = 'WHERE d.websiteid = ?';
    push @bind, $where->{websiteid};
  } elsif ($where->{customerid}) {
    $where_sql = 'WHERE d.customerid = ?';
    push @bind, $where->{customerid};
  } elsif ($where->{domainname}) {
    $where_sql = 'WHERE d.domainname = ?';
    push @bind, $where->{domainname};
  }

  my $sql = qq{
    SELECT
      d.domainid,
      d.domainname,
      d.websiteid,
      d.customerid,
      d.incert,
      w.home,
      w.active
    FROM website.domains d
    LEFT JOIN website.websites w ON d.websiteid = w.websiteid
    $where_sql
    ORDER BY d.domainname
  };

  return $db->query($sql, @bind)->hashes;
}

sub servers ($self, $params = {}) {
  my $db = $self->pg->db;
  my $where = $params->{where} // {};

  return $db->query(q{
    SELECT
      s.serverid,
      s.hostname,
      s.jailname,
      s.servertypeid,
      s.default_ip4,
      s.default_ip6,
      st.servertypename
    FROM website.servers s
    LEFT JOIN website.servertypes st ON s.servertypeid = st.servertypeid
    ORDER BY s.hostname
  })->hashes;
}

sub servertypes ($self) {
  my $db = $self->pg->db;
  return $db->select('website.servertypes', '*', undef, { -order_by => 'servertypename' })->hashes;
}

sub shells ($self) {
  my $db = $self->pg->db;
  return $db->select('website.shells', '*', undef, { -order_by => 'shell' })->hashes;
}

sub add ($self, $website) {
  my $db = $self->pg->db;

  # Prepare hook data
  my $hook_data = {
    customerid => $website->{customerid},
    domain     => $website->{domainname} // '',
    home       => $website->{home} // '',
    serverid   => $website->{serverid} // '',
  };

  # Run pre-create hooks
  $self->run_hooks('precreate', $hook_data);

  my $tx = $db->begin;

  my $result = $db->insert('website.websites', {
    customerid    => $website->{customerid},
    home          => $website->{home},
    serverid      => $website->{serverid},
    shellid       => $website->{shellid},
    ip4           => $website->{ip4} || undef,
    ip6           => $website->{ip6} || undef,
    ip_only       => $website->{ip_only} // 0,
    redirecturl   => $website->{redirecturl},
    active        => $website->{active} // 1,
  }, { returning => 'websiteid' })->hash;

  my $websiteid = $result->{websiteid};

  # Create primary domain if domainname provided
  if ($website->{domainname}) {
    my $domain = $db->insert('website.domains', {
      domainname => $website->{domainname},
      websiteid  => $websiteid,
      customerid => $website->{customerid},
      incert     => 1,
    }, { returning => 'domainid' })->hash;

    $db->update('website.websites', { primarydomain => $domain->{domainid} }, { websiteid => $websiteid });
  }

  $tx->commit;

  # Run post-create hooks
  $hook_data->{websiteid} = $websiteid;
  $self->run_hooks('postcreate', $hook_data);

  return $websiteid;
}

sub update ($self, $websiteid, $website) {
  my $db = $self->pg->db;

  # Get existing website for hook data
  my $existing = $self->get_by_id($websiteid);

  my $update = {};
  $update->{serverid}    = $website->{serverid} if exists $website->{serverid};
  $update->{shellid}     = $website->{shellid} if exists $website->{shellid};
  $update->{ip4}         = $website->{ip4} || undef if exists $website->{ip4};
  $update->{ip6}         = $website->{ip6} || undef if exists $website->{ip6};
  $update->{ip_only}     = $website->{ip_only} if exists $website->{ip_only};
  $update->{redirecturl} = $website->{redirecturl} if exists $website->{redirecturl};
  $update->{active}      = $website->{active} if exists $website->{active};

  return 0 unless %$update;

  # Prepare hook data
  my $hook_data = {
    websiteid  => $websiteid,
    customerid => $existing->{customerid} // '',
    domain     => $existing->{domainname} // '',
    home       => $existing->{home} // '',
    serverid   => $website->{serverid} // $existing->{serverid} // '',
  };

  # Run pre-update hooks
  $self->run_hooks('preupdate', $hook_data);

  my $result = $db->update('website.websites', $update, { websiteid => $websiteid });

  # Run post-update hooks
  $self->run_hooks('postupdate', $hook_data);

  return $result;
}

sub delete ($self, $websiteid) {
  my $db = $self->pg->db;

  # Get existing website for hook data
  my $existing = $self->get_by_id($websiteid);

  # Prepare hook data
  my $hook_data = {
    websiteid  => $websiteid,
    customerid => $existing->{customerid} // '',
    domain     => $existing->{domainname} // '',
    home       => $existing->{home} // '',
    serverid   => $existing->{serverid} // '',
  };

  # Run pre-delete hooks
  $self->run_hooks('predelete', $hook_data);

  my $result = $db->delete('website.websites', { websiteid => $websiteid });

  # Run post-delete hooks
  $self->run_hooks('postdelete', $hook_data);

  return $result;
}

sub add_domain ($self, $domain) {
  my $db = $self->pg->db;

  return $db->insert('website.domains', {
    domainname => $domain->{domainname},
    websiteid  => $domain->{websiteid},
    customerid => $domain->{customerid},
    incert     => $domain->{incert} // 1,
  }, { returning => 'domainid' })->hash->{domainid};
}

sub delete_domain ($self, $domainid) {
  my $db = $self->pg->db;
  return $db->delete('website.domains', { domainid => $domainid });
}

sub set_primary_domain ($self, $websiteid, $domainid) {
  my $db = $self->pg->db;
  return $db->update('website.websites', { primarydomain => $domainid }, { websiteid => $websiteid });
}

sub get_phpconfig ($self, $websiteid) {
  my $db = $self->pg->db;
  return $db->select('website.phpconfigs', '*', { websiteid => $websiteid })->hash;
}

sub set_phpconfig ($self, $websiteid, $active, $config = '') {
  my $db = $self->pg->db;
  my $existing = $self->get_phpconfig($websiteid);

  if ($active) {
    if ($existing) {
      $db->update('website.phpconfigs', { phpconfig => $config, active => 1 }, { websiteid => $websiteid });
    } else {
      $db->insert('website.phpconfigs', { websiteid => $websiteid, phpconfig => $config, active => 1 });
    }
  } else {
    if ($existing) {
      $db->update('website.phpconfigs', { active => 0 }, { websiteid => $websiteid });
    }
  }
}

sub get_serverextra ($self, $websiteid) {
  my $db = $self->pg->db;
  return $db->select('website.serverextras', '*', { websiteid => $websiteid })->hash;
}

sub set_serverextra ($self, $websiteid, $active, $configextra = '') {
  my $db = $self->pg->db;
  my $existing = $self->get_serverextra($websiteid);

  if ($active) {
    if ($existing) {
      $db->update('website.serverextras', { configextra => $configextra, active => 1 }, { websiteid => $websiteid });
    } else {
      $db->insert('website.serverextras', { websiteid => $websiteid, configextra => $configextra, active => 1 });
    }
  } else {
    if ($existing) {
      $db->update('website.serverextras', { active => 0 }, { websiteid => $websiteid });
    }
  }
}

sub delete_phpconfig ($self, $websiteid) {
  my $db = $self->pg->db;
  return $db->delete('website.phpconfigs', { websiteid => $websiteid });
}

sub delete_serverextra ($self, $websiteid) {
  my $db = $self->pg->db;
  return $db->delete('website.serverextras', { websiteid => $websiteid });
}

# Validate IP settings before save
# Returns undef on success, error message on failure
sub validate_ip ($self, $website, $websiteid = undef) {
  my $ip4 = $website->{ip4};
  my $ip6 = $website->{ip6};
  my $ip_only = $website->{ip_only};

  # ip_only requires at least one IP
  if ($ip_only && !$ip4 && !$ip6) {
    return 'IP-only mode requires at least one IP address (IPv4 or IPv6)';
  }

  # Validate each IP if provided
  for my $ip ($ip4, $ip6) {
    next unless $ip;
    my $error = $self->_validate_single_ip($ip, $websiteid);
    return $error if $error;
  }

  return undef;  # Success
}

sub _validate_single_ip ($self, $ip, $websiteid = undef) {
  my $db = $self->pg->db;
  my $is_ipv6 = $ip =~ /:/;
  my $field = $is_ipv6 ? 'ip6' : 'ip4';

  # Check not used by another website
  my $website_check = $db->query(
    "SELECT websiteid FROM website.websites WHERE $field = ? AND websiteid != ?",
    $ip, $websiteid // 0
  )->hash;
  if ($website_check) {
    return "IP $ip is already used by website $website_check->{websiteid}";
  }

  # Check not used by any server as default IP
  my $server_field = $is_ipv6 ? 'default_ip6' : 'default_ip4';
  my $server_check = $db->query(
    "SELECT serverid, hostname FROM website.servers WHERE $server_field = ?",
    $ip
  )->hash;
  if ($server_check) {
    return "IP $ip is used as default by server $server_check->{hostname}";
  }

  # Check IP is within configured ranges
  my $iprange = $self->config->{iprange} // {};
  my $ranges = $is_ipv6 ? ($iprange->{ip6} // []) : ($iprange->{ip4} // []);

  if (@$ranges && !$self->_ip_in_ranges($ip, $ranges, $is_ipv6)) {
    return "IP $ip is not within allowed ranges";
  }

  return undef;  # Valid
}

sub _ip_in_ranges ($self, $ip, $ranges, $is_ipv6) {
  for my $cidr (@$ranges) {
    return 1 if $self->_ip_in_cidr($ip, $cidr, $is_ipv6);
  }
  return 0;
}

sub _ip_in_cidr ($self, $ip, $cidr, $is_ipv6) {
  my ($network, $prefix) = split '/', $cidr;
  $prefix //= $is_ipv6 ? 128 : 32;

  my $family = $is_ipv6 ? AF_INET6 : AF_INET;
  my $ip_bin = inet_pton($family, $ip) or return 0;
  my $net_bin = inet_pton($family, $network) or return 0;

  # Create netmask
  my $bits = $is_ipv6 ? 128 : 32;
  my $mask = "\xff" x ($prefix / 8);
  if (my $remainder = $prefix % 8) {
    $mask .= chr(256 - (1 << (8 - $remainder)));
  }
  $mask .= "\x00" x (($bits - $prefix + 7) / 8);
  $mask = substr($mask, 0, $bits / 8);

  # Compare masked addresses
  return ($ip_bin & $mask) eq ($net_bin & $mask);
}


# Run configured hooks for website lifecycle events
# Hook types: precreate, postcreate, preupdate, postupdate, predelete, postdelete
# Placeholders in commands: {customerid}, {domain}, {websiteid}, {home}, {serverid}
sub run_hooks ($self, $hook_type, $data = {}) {
  my $hooks = $self->config->{hooks} // {};
  my $commands = $hooks->{$hook_type} // [];

  return unless @$commands;

  say "Website hooks [$hook_type]:";

  for my $cmd (@$commands) {
    # Substitute placeholders with actual values
    my $expanded = $cmd;
    for my $key (keys %$data) {
      my $value = $data->{$key} // '';
      $expanded =~ s/\{$key\}/$value/g;
    }

    # For now, just log the command (later: system() with suid wrapper)
    say "  -> $expanded";

    # TODO: Uncomment when ready to execute
    # my $result = system($expanded);
    # if ($result != 0) {
    #   warn "Hook command failed: $expanded (exit code: $result)";
    # }
  }
}

1;
