package Samizdat::Model::BIS;

use Mojo::Base -base, -signatures;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Net::DNS::Resolver;
use Socket qw(AF_INET AF_INET6 inet_pton inet_ntop);
use Encode qw(decode_utf8);
use Samizdat::Model::Public;

has 'config';
has 'redis';
has 'pg';
has 'ua' => sub {
  my $ua = Mojo::UserAgent->new;
  $ua->max_redirects(3);
  $ua->request_timeout(10);
  return $ua;
};
has 'resolver' => sub {
  my $res = Net::DNS::Resolver->new;
  $res->tcp_timeout(5);
  $res->udp_timeout(5);
  return $res;
};
has 'public' => sub ($self) {
  return Samizdat::Model::Public->new(pg => $self->pg);
};
has 'languages' => sub ($self) {
  # Cache the languages hash for fast lookups
  return $self->public->languages();
};
has 'selectedimage' => sub ($self) {
  return {
    src    => '/media/images/basedinsweden.png',
    width  => 1359,
    height => 865
  };
};


=head1 NAME

Samizdat::Model::BIS - Based in Sweden compliance tracking model

=head1 SYNOPSIS

    my $bis = $c->bis;

    # Add a domain to track
    my $domain_id = $bis->add_domain(
      domain => 'example.se',
      title => 'Example Organization',
      tags => ['government', 'healthcare']
    );

    # Start a new check run
    my $run_id = $bis->start_run();

    # Check a domain
    $bis->check_domain($domain_id, $run_id);

    # Complete the run
    $bis->complete_run($run_id);

    # Get latest scores
    my $scores = $bis->get_latest_scores(tag => 'healthcare');

=head1 DESCRIPTION

This model tracks Swedish organizations' hosting compliance by checking
DNS records and WHOIS data to determine if infrastructure is located
in Sweden or hosted by Swedish companies.

=head1 METHODS

=head2 add_domain

Add a new domain to track.

    my $domain_id = $bis->add_domain(
      domain => 'example.se',
      title => 'Example Org',
      description => 'Government healthcare provider',
      tags => ['government', 'healthcare']
    );

=cut

sub add_domain ($self, %params) {
  my $domain = $params{domain} or die "domain required";
  my $title = $params{title} || '';
  my $description = $params{description} || '';
  my $tags = $params{tags} || [];
  my $lang = $params{lang} || 'en';

  # Ensure UTF-8 strings are properly decoded for database storage
  # If they're already UTF-8 flagged, leave them alone; if not, decode them
  utf8::decode($title) unless utf8::is_utf8($title);
  utf8::decode($description) unless utf8::is_utf8($description);

  # Insert or update domain
  my $result = $self->pg->db->query(
    'INSERT INTO bis.domains (domain)
     VALUES (?)
     ON CONFLICT (domain) DO UPDATE
     SET updated_at = NOW()
     RETURNING id',
    $domain
  );

  my $domain_id = $result->hash->{id};

  # Add or update localized description
  if ($title || $description) {
    my $languageid = $self->get_language_id($lang);

    $self->pg->db->query(
      'INSERT INTO bis.domain_descriptions (domain_id, languageid, title, description)
       VALUES (?, ?, ?, ?)
       ON CONFLICT (domain_id, languageid) DO UPDATE
       SET title = EXCLUDED.title,
           description = EXCLUDED.description',
      $domain_id, $languageid, $title, $description
    );
  }

  # Add tags (tags are keys like 'government', 'healthcare')
  for my $tag_key (@$tags) {
    # Look up tag by key in bis.tag_names
    my $tag = $self->pg->db->query(
      'SELECT DISTINCT tag_id FROM bis.tag_names WHERE key = ?',
      $tag_key
    )->hash;

    if ($tag) {
      $self->pg->db->query(
        'INSERT INTO bis.domain_tags (domain_id, tag_id)
         VALUES (?, ?)
         ON CONFLICT DO NOTHING',
        $domain_id, $tag->{tag_id}
      );
    }
  }

  return $domain_id;
}

=head2 start_run

Start a new check run.

    my $run_id = $bis->start_run();

=cut

sub start_run ($self) {
  # Keep Redis cache between runs for better performance
  # Cached IP lookups can be reused across multiple domains
  # Uncomment below to clear cache if needed for testing
  # if ($self->redis) {
  #   my $keys = $self->redis->db->keys('bis:cache:*');
  #   $self->redis->db->del(@$keys) if @$keys;
  # }

  my $result = $self->pg->db->query(
    'INSERT INTO bis.runs (started_at, status)
     VALUES (NOW(), ?)
     RETURNING id',
    'running'
  );

  return $result->hash->{id};
}

=head2 check_domain

Check all DNS records for a domain and calculate compliance.

    $bis->check_domain($domain_id, $run_id);

=cut

sub check_domain ($self, $domain_id, $run_id) {
  # Get domain
  my $domain = $self->pg->db->select('bis.domains', '*', {id => $domain_id})->hash;
  return unless $domain;

  my $domain_name = $domain->{domain};
  my @checks;
  my $total_checks = 0;
  my $compliant_checks = 0;

  # Check A records
  my $a_records = $self->lookup_dns($domain_name, 'A');
  my $a_compliant = @$a_records ? 1 : undef;  # NULL if no A records
  for my $record (@$a_records) {
    my $check = $self->check_ip($record->{value}, 'A');
    $check->{record_value} = $record->{value};
    push @checks, $check;
    $total_checks++;
    if ($check->{is_compliant}) {
      $compliant_checks++;
    } else {
      $a_compliant = 0;
    }
  }

  # Check AAAA records
  my $aaaa_records = $self->lookup_dns($domain_name, 'AAAA');
  my $aaaa_compliant = @$aaaa_records ? 1 : undef;  # NULL if no AAAA
  for my $record (@$aaaa_records) {
    my $check = $self->check_ip($record->{value}, 'AAAA');
    $check->{record_value} = $record->{value};
    push @checks, $check;
    $total_checks++;
    if ($check->{is_compliant}) {
      $compliant_checks++;
    } else {
      $aaaa_compliant = 0;
    }
  }

  # Check MX records
  my $mx_records = $self->lookup_dns($domain_name, 'MX');
  my $mx_compliant = @$mx_records ? 1 : undef;  # NULL if no MX
  for my $record (@$mx_records) {
    # Resolve MX hostname to IP
    my $mx_a_records = $self->lookup_dns($record->{value}, 'A');
    for my $mx_a (@$mx_a_records) {
      my $check = $self->check_ip($mx_a->{value}, 'MX');
      $check->{record_value} = $record->{value};
      push @checks, $check;
      $total_checks++;
      if ($check->{is_compliant}) {
        $compliant_checks++;
      } else {
        $mx_compliant = 0;
      }
    }
  }

  # Check NS records
  my $ns_records = $self->lookup_dns($domain_name, 'NS');
  my $ns_compliant = @$ns_records ? 1 : undef;  # NULL if no NS records
  for my $record (@$ns_records) {
    # Resolve NS hostname to IP
    my $ns_a_records = $self->lookup_dns($record->{value}, 'A');
    for my $ns_a (@$ns_a_records) {
      my $check = $self->check_ip($ns_a->{value}, 'NS');
      $check->{record_value} = $record->{value};
      push @checks, $check;
      $total_checks++;
      if ($check->{is_compliant}) {
        $compliant_checks++;
      } else {
        $ns_compliant = 0;
      }
    }
  }

  # Store all checks
  for my $check (@checks) {
    $self->pg->db->insert('bis.checks', {
      run_id => $run_id,
      domain_id => $domain_id,
      record_type => $check->{record_type},
      record_value => $check->{record_value},
      ip_address => $check->{ip_address},
      country_code => $check->{country_code},
      asn => $check->{asn},
      as_name => $check->{as_name},
      hosting_provider => $check->{hosting_provider},
      is_compliant => $check->{is_compliant},
      checked_at => \'NOW()'
    });
  }

  # Calculate score
  my $score = $total_checks > 0 ? int(($compliant_checks / $total_checks) * 100) : 0;
  my $has_bis_badge = ($score == 100 && $total_checks > 0) ? 1 : 0;

  # Determine primary provider (most common non-compliant provider)
  my $primary_provider = '';
  my %provider_counts;
  for my $check (@checks) {
    next unless $check->{hosting_provider};
    $provider_counts{$check->{hosting_provider}}++;
  }
  if (%provider_counts) {
    ($primary_provider) = sort { $provider_counts{$b} <=> $provider_counts{$a} } keys %provider_counts;
  }

  # Store score
  $self->pg->db->insert('bis.scores', {
    run_id => $run_id,
    domain_id => $domain_id,
    score => $score,
    total_checks => $total_checks,
    compliant_checks => $compliant_checks,
    a_compliant => $a_compliant,
    aaaa_compliant => $aaaa_compliant,
    mx_compliant => $mx_compliant,
    ns_compliant => $ns_compliant,
    has_bis_badge => $has_bis_badge,
    primary_provider => $primary_provider,
    calculated_at => \'NOW()'
  });

  # Update run progress
  $self->pg->db->query(
    'UPDATE bis.runs SET domains_checked = domains_checked + 1 WHERE id = ?',
    $run_id
  );

  return {
    domain => $domain_name,
    score => $score,
    total_checks => $total_checks,
    compliant_checks => $compliant_checks,
    has_bis_badge => $has_bis_badge
  };
}

=head2 lookup_dns

Look up DNS records for a domain.

    my $records = $bis->lookup_dns('example.se', 'A');

=cut

sub lookup_dns ($self, $domain, $type) {
  my @records;

  my $query = $self->resolver->query($domain, $type);
  return \@records unless $query;

  for my $rr ($query->answer) {
    next unless $rr->type eq $type;

    my $value;
    if ($type eq 'A' || $type eq 'AAAA') {
      $value = $rr->address;
    } elsif ($type eq 'MX') {
      $value = $rr->exchange;
    } elsif ($type eq 'NS') {
      $value = $rr->nsdname;
    } else {
      next;
    }

    push @records, {
      type => $type,
      value => $value
    };
  }

  return \@records;
}

=head2 check_ip

Check an IP address for country and hosting provider.

    my $check = $bis->check_ip('192.0.2.1', 'A');

=cut

sub check_ip ($self, $ip, $record_type) {
  # Check Redis cache first
  my $cache_key = "bis:cache:ip:$ip";
  if ($self->redis) {
    my $cached = $self->redis->db->get($cache_key);
    if ($cached) {
      my $data = decode_json($cached);
      $data->{record_type} = $record_type;
      return $data;
    }
  }

  # Look up IP geolocation and ASN using ip-api.com (free tier: 45 req/min)
  my $tx = $self->ua->get("http://ip-api.com/json/$ip?fields=status,country,countryCode,as,asname");

  my $result = {
    record_type => $record_type,
    ip_address => $ip,
    country_code => undef,
    asn => undef,
    as_name => undef,
    hosting_provider => undef,
    is_compliant => 0
  };

  if ($tx->result->is_success) {
    my $data = $tx->result->json;
    if ($data->{status} eq 'success') {
      $result->{country_code} = $data->{countryCode};

      # Parse ASN from "as" field (format: "AS12345 Provider Name")
      if ($data->{as} && $data->{as} =~ /^AS(\d+)\s*(.*)/) {
        $result->{asn} = $1;
        $result->{as_name} = $2 || $data->{asname} || '';
      }

      # Identify hosting provider
      $result->{hosting_provider} = $self->identify_provider($result->{asn}, $result->{as_name});

      # Check if compliant (Swedish)
      $result->{is_compliant} = ($result->{country_code} eq 'SE') ? 1 : 0;

      # Cache result for 1 hour
      if ($self->redis) {
        $self->redis->db->setex($cache_key, 3600, encode_json($result));
      }
    }
  }

  # Rate limiting: sleep 1.5 seconds to stay under 45 req/min
  sleep 1.5;

  return $result;
}

=head2 identify_provider

Identify hosting provider from ASN and AS name.
Returns the provider key (e.g., 'aws', 'bahnhof').

    my $provider_key = $bis->identify_provider(12345, 'BAHNHOF-NET');

=cut

sub identify_provider ($self, $asn, $as_name) {
  return '' unless $as_name;

  # Check against provider patterns in database
  # Join with provider_names to get the key
  my $providers = $self->pg->db->query(
    'SELECT DISTINCT p.id, pn.key, p.as_name_patterns
     FROM bis.providers p
     JOIN bis.provider_names pn ON p.id = pn.provider_id
     WHERE p.as_name_patterns IS NOT NULL'
  )->hashes;

  for my $provider (@$providers) {
    next unless $provider->{as_name_patterns};

    for my $pattern (@{$provider->{as_name_patterns}}) {
      if ($as_name =~ /\Q$pattern\E/i) {
        return $provider->{key};
      }
    }
  }

  return '';
}

=head2 complete_run

Complete a check run and calculate statistics.

    $bis->complete_run($run_id);

=cut

sub complete_run ($self, $run_id) {
  # Calculate statistics
  my $stats = $self->pg->db->query(
    'SELECT
      COUNT(DISTINCT domain_id) as total_domains,
      COUNT(DISTINCT CASE WHEN has_bis_badge THEN domain_id END) as compliant_domains,
      AVG(score) as avg_score,
      AVG(CASE WHEN a_compliant THEN 100 ELSE 0 END) as a_compliance_rate,
      AVG(CASE WHEN mx_compliant THEN 100 ELSE 0 END) as mx_compliance_rate,
      AVG(CASE WHEN ns_compliant THEN 100 ELSE 0 END) as ns_compliance_rate
     FROM bis.scores
     WHERE run_id = ?',
    $run_id
  )->hash;

  my $compliance_rate = $stats->{total_domains} > 0
    ? ($stats->{compliant_domains} / $stats->{total_domains}) * 100
    : 0;

  # Store statistics
  $self->pg->db->insert('bis.statistics', {
    run_id => $run_id,
    total_domains => $stats->{total_domains},
    compliant_domains => $stats->{compliant_domains},
    compliance_rate => $compliance_rate,
    a_compliance_rate => $stats->{a_compliance_rate},
    mx_compliance_rate => $stats->{mx_compliance_rate},
    ns_compliance_rate => $stats->{ns_compliance_rate},
    avg_score => $stats->{avg_score},
    calculated_at => \'NOW()'
  });

  # Mark run as completed
  $self->pg->db->query(
    'UPDATE bis.runs SET status = ?, completed_at = NOW() WHERE id = ?',
    'completed', $run_id
  );

  return $stats;
}

=head2 get_recent_runs

Get recent check runs with their statistics.

    my $runs = $bis->get_recent_runs(limit => 10);

=cut

sub get_recent_runs ($self, %params) {
  my $limit = $params{limit} || 10;

  my $runs = $self->pg->db->select(
    'bis.runs',
    '*',
    undef,
    {order_by => {-desc => 'started_at'}, limit => $limit}
  )->hashes->to_array;

  # Add statistics for each run
  for my $run (@$runs) {
    my $stats = $self->pg->db->select(
      'bis.statistics',
      '*',
      {run_id => $run->{id}}
    )->hash;
    $run->{statistics} = $stats;
  }

  return $runs;
}

=head2 get_latest_scores

Get latest scores for all domains or filtered by tag key.

    my $scores = $bis->get_latest_scores(tag => 'healthcare', limit => 50);

=cut

sub get_latest_scores ($self, %params) {
  my $tag = $params{tag};
  my $search = $params{search};
  my $limit = $params{limit} || 100;
  my $offset = $params{offset} || 0;
  my $with_total = $params{with_total} || 0;
  my $lang = $params{lang} || 'en';

  my $languageid = $self->get_language_id($lang);

  # Start with base query, joining with domain_descriptions for title search
  my $sql = 'SELECT DISTINCT s.*, dd.title
             FROM bis.latest_scores s
             LEFT JOIN bis.domain_descriptions dd ON s.domain_id = dd.domain_id AND dd.languageid = ?';
  my @bind = ($languageid);

  my @where_clauses;

  if ($tag) {
    # Filter by tag key using bis.tag_names
    $sql .= ' JOIN bis.domain_tags dt ON s.domain_id = dt.domain_id
              JOIN bis.tag_names tn ON dt.tag_id = tn.tag_id';
    push @where_clauses, 'tn.key = ?';
    push @bind, $tag;
  }

  if ($search) {
    # Search in both domain name and title using ILIKE (case-insensitive)
    push @where_clauses, '(s.domain ILIKE ? OR dd.title ILIKE ?)';
    my $search_pattern = '%' . $search . '%';
    push @bind, $search_pattern, $search_pattern;
  }

  # Add WHERE clause if we have conditions
  if (@where_clauses) {
    $sql .= ' WHERE ' . join(' AND ', @where_clauses);
  }

  # Get total count if requested
  my $total;
  if ($with_total) {
    my $count_sql = $sql;
    $count_sql =~ s/SELECT DISTINCT s\.\*, dd\.title/SELECT COUNT(DISTINCT s.domain_id)/;
    $total = $self->pg->db->query($count_sql, @bind)->hash->{count};
  }

  $sql .= ' ORDER BY s.score DESC LIMIT ? OFFSET ?';
  push @bind, $limit, $offset;

  my $scores = $self->pg->db->query($sql, @bind)->hashes->to_array;

  return $with_total ? {scores => $scores, total => $total} : $scores;
}

=head2 get_sector_stats

Get compliance statistics by sector with localized names.

    my $stats = $bis->get_sector_stats(lang => 'sv');

=cut

sub get_sector_stats ($self, %params) {
  my $lang = $params{lang} || 'en';
  my $languageid = $self->get_language_id($lang);

  # Custom query with language parameter
  return $self->pg->db->query(
    'SELECT
      tn.key as sector,
      tn.display_name,
      COUNT(DISTINCT d.id) as total_domains,
      COUNT(DISTINCT CASE WHEN s.has_bis_badge THEN d.id END) as compliant_domains,
      ROUND(AVG(s.score), 2) as avg_score,
      ROUND(100.0 * COUNT(DISTINCT CASE WHEN s.has_bis_badge THEN d.id END) / NULLIF(COUNT(DISTINCT d.id), 0), 2) as compliance_rate
     FROM bis.tags t
     JOIN bis.tag_names tn ON t.id = tn.tag_id AND tn.languageid = ?
     JOIN bis.domain_tags dt ON t.id = dt.tag_id
     JOIN bis.domains d ON dt.domain_id = d.id
     JOIN bis.scores s ON d.id = s.domain_id
     WHERE s.run_id = (SELECT MAX(id) FROM bis.runs WHERE status = ?)
       AND d.active = TRUE
     GROUP BY tn.key, tn.display_name, t.priority
     ORDER BY t.priority DESC',
    $languageid, 'completed'
  )->hashes->to_array;
}

=head2 get_provider_stats

Get statistics by hosting provider with localized names.

    my $stats = $bis->get_provider_stats(lang => 'sv');

=cut

sub get_provider_stats ($self, %params) {
  my $lang = $params{lang} || 'en';
  my $languageid = $self->get_language_id($lang);

  # Custom query with language parameter
  return $self->pg->db->query(
    'SELECT
      c.hosting_provider,
      pn.name as provider_name,
      bp.country_code,
      bp.is_swedish,
      bp.cloud_act_applies,
      COUNT(DISTINCT c.domain_id) as domain_count,
      COUNT(*) as total_records
     FROM bis.checks c
     LEFT JOIN bis.provider_names pn ON c.hosting_provider = pn.key AND pn.languageid = ?
     LEFT JOIN bis.providers bp ON pn.provider_id = bp.id
     WHERE c.run_id = (SELECT MAX(id) FROM bis.runs WHERE status = ?)
     GROUP BY c.hosting_provider, pn.name, bp.country_code, bp.is_swedish, bp.cloud_act_applies
     ORDER BY domain_count DESC',
    $languageid, 'completed'
  )->hashes->to_array;
}

=head2 get_tags

Get all tags with localized names.

    my $tags = $bis->get_tags(lang => 'sv');

=cut

sub get_tags ($self, %params) {
  my $lang = $params{lang} || 'en';
  my $languageid = $self->get_language_id($lang);

  return $self->pg->db->query(
    'SELECT
      t.id,
      t.color,
      t.priority,
      tn.key,
      tn.display_name,
      tn.description
     FROM bis.tags t
     JOIN bis.tag_names tn ON t.id = tn.tag_id
     WHERE tn.languageid = ?
     ORDER BY t.priority DESC',
    $languageid
  )->hashes->to_array;
}

=head2 get_providers

Get all providers with localized names.

    my $providers = $bis->get_providers(lang => 'sv');

=cut

sub get_providers ($self, %params) {
  my $lang = $params{lang} || 'en';
  my $languageid = $self->get_language_id($lang);

  return $self->pg->db->query(
    'SELECT
      p.id,
      p.country_code,
      p.is_swedish,
      p.cloud_act_applies,
      pn.key,
      pn.name,
      pn.notes
     FROM bis.providers p
     JOIN bis.provider_names pn ON p.id = pn.provider_id
     WHERE pn.languageid = ?
     ORDER BY p.is_swedish DESC, pn.name ASC',
    $languageid
  )->hashes->to_array;
}

=head2 get_historical_trends

Get historical compliance trends.

    my $trends = $bis->get_historical_trends(days => 90);

=cut

sub get_historical_trends ($self, %params) {
  my $days = $params{days} || 90;

  return $self->pg->db->query(
    'SELECT
      r.started_at as date,
      s.compliance_rate,
      s.a_compliance_rate,
      s.mx_compliance_rate,
      s.ns_compliance_rate,
      s.avg_score
     FROM bis.statistics s
     JOIN bis.runs r ON s.run_id = r.id
     WHERE r.started_at >= NOW() - ($1 || \' DAY\')::INTERVAL
       AND r.status = $2
     ORDER BY r.started_at ASC',
    $days, 'completed'
  )->hashes->to_array;
}

=head2 get_language_id

Get language ID from language code using cached languages hash.

    my $languageid = $bis->get_language_id('sv');

=cut

sub get_language_id ($self, $lang) {
  $lang ||= 'en';
  return $self->languages->{$lang} // 1;  # Default to English (1)
}

=head2 get_domain_details

Get domain details with checks and tags for a specific domain.

    my $details = $bis->get_domain_details(
      domain => 'example.se',
      lang => 'en'
    );

Returns hashref with domain, checks, and tags.

=cut

sub get_domain_details ($self, %params) {
  my $domain_name = $params{domain} or return;
  my $lang = $params{lang} || 'en';

  # Get domain details
  my $domain = $self->pg->db->query(
    'SELECT * FROM bis.latest_scores WHERE domain = ?',
    $domain_name
  )->hash;

  return unless $domain;

  # Get languageid and fetch localized title/description
  my $languageid = $self->get_language_id($lang);
  my $description = $self->pg->db->query(
    'SELECT title, description FROM bis.domain_descriptions
     WHERE domain_id = ? AND languageid = ?',
    $domain->{domain_id}, $languageid
  )->hash;

  # Add localized fields to domain hash
  if ($description) {
    $domain->{title} = $description->{title} || '';
    $domain->{description} = $description->{description} || '';
  } else {
    $domain->{title} = '';
    $domain->{description} = '';
  }

  # Get checks for this domain
  my $checks = $self->pg->db->query(
    'SELECT * FROM bis.checks
     WHERE domain_id = ? AND run_id = (SELECT MAX(id) FROM bis.runs WHERE status = ?)
     ORDER BY record_type, checked_at',
    $domain->{domain_id}, 'completed'
  )->hashes->to_array;

  # Get tags with localized names
  my $tags = $self->pg->db->query(
    'SELECT t.id, t.color, t.priority, tn.key, tn.display_name, tn.description
     FROM bis.tags t
     JOIN bis.domain_tags dt ON t.id = dt.tag_id
     JOIN bis.tag_names tn ON t.id = tn.tag_id AND tn.languageid = ?
     WHERE dt.domain_id = ?
     ORDER BY t.priority DESC',
    $languageid, $domain->{domain_id}
  )->hashes->to_array;

  return {
    domain => $domain,
    checks => $checks,
    tags => $tags
  };
}

=head2 nav

Navigate to next or previous domain respecting applied filters.

    my $next_domain = $bis->nav(
      domain => 'example.se',
      to => 'next',  # or 'prev'
      tag => 'government',
      search => ''
    );

=cut

sub nav ($self, %params) {
  my $domain_name = $params{domain} or return;
  my $to = $params{to} || 'next';
  my $tag = $params{tag} || '';
  my $search = $params{search} || '';

  # Determine comparison operator and order
  my $operator = $to eq 'prev' ? '<' : '>';
  my $order = $to eq 'prev' ? 'DESC' : 'ASC';

  # Build WHERE clause
  my @where_parts = ("domain $operator ?");
  my @bind_params = ($domain_name);

  if ($tag) {
    push @where_parts, 'EXISTS (SELECT 1 FROM bis.domain_tags dt JOIN bis.tag_names tn ON dt.tag_id = tn.tag_id WHERE dt.domain_id = bis.latest_scores.domain_id AND tn.key = ?)';
    push @bind_params, $tag;
  }

  if ($search) {
    push @where_parts, '(domain ILIKE ? OR title ILIKE ?)';
    push @bind_params, "%$search%", "%$search%";
  }

  my $where_clause = join(' AND ', @where_parts);

  # Find next/previous domain
  my $sql = qq{
    SELECT domain, domain_id, score
    FROM bis.latest_scores
    WHERE $where_clause
    ORDER BY domain $order
    LIMIT 1
  };

  # Debug logging
  warn "BIS nav SQL: $sql\n";
  warn "BIS nav params: " . join(', ', @bind_params) . "\n";

  my $result = $self->pg->db->query($sql, @bind_params)->hash;

  warn "BIS nav result: " . ($result ? $result->{domain} : 'NONE') . "\n";

  return $result || {};
}

=head2 get_sector_info

Get sector info with localized name.

    my $sector_info = $bis->get_sector_info(
      sector => 'healthcare',
      lang => 'sv'
    );

=cut

sub get_sector_info ($self, %params) {
  my $sector = $params{sector} or return;
  my $lang = $params{lang} || 'en';

  my $languageid = $self->get_language_id($lang);

  return $self->pg->db->query(
    'SELECT t.color, tn.display_name, tn.description
     FROM bis.tags t
     JOIN bis.tag_names tn ON t.id = tn.tag_id AND tn.languageid = ?
     WHERE tn.key = ?',
    $languageid, $sector
  )->hash;
}

=head2 get_domains_with_tags

Get domains with their tags, optionally filtered by tag.

    my $domains = $bis->get_domains_with_tags(
      tag => 'healthcare',
      limit => 100,
      offset => 0
    );

=cut

sub get_domains_with_tags ($self, %params) {
  my $tag = $params{tag};
  my $limit = $params{limit} || 100;
  my $offset = $params{offset} || 0;

  my $sql = 'SELECT d.*, array_agg(tn.key) as tags
             FROM bis.domains d
             LEFT JOIN bis.domain_tags dt ON d.id = dt.domain_id
             LEFT JOIN bis.tag_names tn ON dt.tag_id = tn.tag_id';
  my @bind;

  if ($tag) {
    $sql .= ' WHERE d.id IN (
                SELECT domain_id FROM bis.domain_tags dt2
                JOIN bis.tag_names tn2 ON dt2.tag_id = tn2.tag_id
                WHERE tn2.key = ?
              )';
    push @bind, $tag;
  }

  $sql .= ' GROUP BY d.id ORDER BY d.domain LIMIT ? OFFSET ?';
  push @bind, $limit, $offset;

  return $self->pg->db->query($sql, @bind)->hashes->to_array;
}

=head2 update_domain

Update domain information.

    $bis->update_domain(
      id => 1,
      active => 1,
      title => 'Updated Title',
      description => 'Updated description',
      tags => ['government', 'healthcare'],
      lang => 'en'
    );

=cut

sub update_domain ($self, %params) {
  my $id = $params{id} or die "domain id required";

  # Update domain
  $self->pg->db->update('bis.domains', {
    active => $params{active} // 1,
    updated_at => \'NOW()'
  }, {id => $id});

  # Update domain descriptions if provided
  if ($params{title} || $params{description}) {
    my $lang = $params{lang} || 'en';
    my $languageid = $self->get_language_id($lang);

    $self->pg->db->query(
      'INSERT INTO bis.domain_descriptions (domain_id, languageid, title, description)
       VALUES (?, ?, ?, ?)
       ON CONFLICT (domain_id, languageid) DO UPDATE
       SET title = EXCLUDED.title, description = EXCLUDED.description',
      $id, $languageid, $params{title}, $params{description}
    );
  }

  # Update tags if provided
  if ($params{tags}) {
    $self->update_domain_tags(
      domain_id => $id,
      tags => $params{tags}
    );
  }

  return 1;
}

=head2 update_domain_tags

Update tags for a domain.

    $bis->update_domain_tags(
      domain_id => 1,
      tags => ['government', 'healthcare']
    );

=cut

sub update_domain_tags ($self, %params) {
  my $domain_id = $params{domain_id} or die "domain_id required";
  my $tags = $params{tags} || [];

  # Remove existing tags
  $self->pg->db->delete('bis.domain_tags', {domain_id => $domain_id});

  # Add new tags (tags are keys now)
  for my $tag_key (@$tags) {
    my $tag = $self->pg->db->query(
      'SELECT DISTINCT tag_id FROM bis.tag_names WHERE key = ?',
      $tag_key
    )->hash;
    if ($tag) {
      $self->pg->db->insert('bis.domain_tags', {
        domain_id => $domain_id,
        tag_id => $tag->{tag_id}
      });
    }
  }

  return 1;
}

=head2 delete_domain

Delete a domain.

    $bis->delete_domain(id => 1);

=cut

sub delete_domain ($self, %params) {
  my $id = $params{id} or die "domain id required";

  $self->pg->db->delete('bis.domains', {id => $id});

  return 1;
}

=head2 add_tag

Add a new tag with localized name.

    my $tag_id = $bis->add_tag(
      key => 'healthcare',
      display_name => 'Healthcare',
      description => 'Healthcare organizations',
      color => '#0066cc',
      priority => 10,
      lang => 'en'
    );

=cut

sub add_tag ($self, %params) {
  my $key = $params{key} or die "key required";
  my $display_name = $params{display_name} or die "display_name required";
  my $lang = $params{lang} || 'en';

  # Insert tag
  my $result = $self->pg->db->query(
    'INSERT INTO bis.tags (color, priority) VALUES (?, ?) RETURNING id',
    $params{color} || '#0066cc',
    $params{priority} || 0
  );
  my $tag_id = $result->hash->{id};

  # Insert localized tag name
  my $languageid = $self->get_language_id($lang);

  $self->pg->db->insert('bis.tag_names', {
    tag_id => $tag_id,
    languageid => $languageid,
    key => $key,
    display_name => $display_name,
    description => $params{description} || ''
  });

  return $tag_id;
}

=head2 get_runs_with_stats

Get check runs with their statistics.

    my $runs = $bis->get_runs_with_stats(
      limit => 50,
      offset => 0
    );

=cut

sub get_runs_with_stats ($self, %params) {
  my $limit = $params{limit} || 50;
  my $offset = $params{offset} || 0;

  my $runs = $self->pg->db->select(
    'bis.runs',
    '*',
    undef,
    {order_by => {-desc => 'started_at'}, limit => $limit, offset => $offset}
  )->hashes->to_array;

  # Add statistics for each run
  for my $run (@$runs) {
    my $stats = $self->pg->db->select(
      'bis.statistics',
      '*',
      {run_id => $run->{id}}
    )->hash;
    $run->{statistics} = $stats;
  }

  return $runs;
}

=head2 get_active_domains

Get all active domain IDs for checking.

    my $domains = $bis->get_active_domains();

=cut

sub get_active_domains ($self) {
  return $self->pg->db->select(
    'bis.domains',
    ['id'],
    {active => 1}
  )->hashes->to_array;
}

=head2 add_provider

Add a new hosting provider with localized name.

    my $provider_id = $bis->add_provider(
      key => 'aws',
      name => 'Amazon Web Services',
      country_code => 'US',
      is_swedish => 0,
      cloud_act_applies => 1,
      asn_list => [16509, 14618],
      as_name_patterns => ['AMAZON-AES', 'AMAZON-02'],
      ip_ranges => ['52.0.0.0/8'],
      notes => 'US cloud provider',
      lang => 'en'
    );

=cut

sub add_provider ($self, %params) {
  my $key = $params{key} or die "key required";
  my $name = $params{name} or die "name required";
  my $country_code = $params{country_code} or die "country_code required";
  my $lang = $params{lang} || 'en';

  # Insert provider
  my $result = $self->pg->db->query(
    'INSERT INTO bis.providers (country_code, is_swedish, cloud_act_applies, asn_list, as_name_patterns, ip_ranges)
     VALUES (?, ?, ?, ?, ?, ?) RETURNING id',
    $country_code,
    $params{is_swedish} // 0,
    $params{cloud_act_applies} // 0,
    $params{asn_list},
    $params{as_name_patterns},
    $params{ip_ranges}
  );
  my $provider_id = $result->hash->{id};

  # Insert localized provider name
  my $languageid = $self->get_language_id($lang);

  $self->pg->db->insert('bis.provider_names', {
    provider_id => $provider_id,
    languageid => $languageid,
    key => $key,
    name => $name,
    notes => $params{notes} || ''
  });

  return $provider_id;
}

1;

=head1 SEE ALSO

L<Samizdat::Controller::BIS>, L<Samizdat::Plugin::BIS>

Based in Sweden initiative: L<https://basedinsweden.se/>

=head1 AUTHOR

Samizdat Development Team

=cut
