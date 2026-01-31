package Samizdat::Model::Customer;

use Mojo::Base -base, -signatures;
use Mojo::Util qw(trim);

has 'app';

sub dbtype ($self) {
  return $self->app->config->{manager}->{customer}->{dbtype} // 'postgresql';
}

sub database ($self) {
  return ('mysql' eq $self->dbtype) ? $self->app->mysql->db : $self->app->pg->db;
}

sub eucountries ($self) {
  return [qw(AT BE BG CY CZ DE DK EE ES FI FR EL HR HU IE IT LI LV LT LU MT NL PL PT RO SE SI SK)];
}

sub get ($self, $params = {}) {
  my $where = $params->{where} // {};
  my $limit = $params->{limit} // {};

  return $self->dbtype eq 'mysql'
    ? $self->_get_mysql($where, $limit)
    : $self->_get_pg($where, $limit);
}

sub _get_mysql ($self, $where, $limit) {
  my $db = $self->database;
  my $customers = [];

  $db->select('customer', '*', $where, $limit)->hashes->each(sub ($customer, $num) {
    # Normalize fields to match PostgreSQL format
    # lang: 'sv_SE' -> 'sv'
    if ($customer->{lang}) {
      $customer->{lang} = lc(substr($customer->{lang}, 0, 2));
    }
    # currency: 'sek' -> 'SEK'
    if ($customer->{currency}) {
      $customer->{currency} = uc($customer->{currency});
    }
    # trust: 'blocked'/'normal'/'trusted' -> 0/1/2
    my %trust_map = (blocked => 0, normal => 1, trusted => 2);
    if ($customer->{trust} && exists $trust_map{$customer->{trust}}) {
      $customer->{trust} = $trust_map{$customer->{trust}};
    }

    # Fill in billing fields from primary if empty
    $customer->{billingemail}   ||= $customer->{contactemail};
    $customer->{billingcity}    ||= $customer->{city};
    $customer->{billingzip}     ||= $customer->{zip};
    $customer->{billingaddress} ||= $customer->{address};
    $customer->{billingcountry} ||= $customer->{country};
    $customer->{billinglang}    ||= $customer->{lang};
    push @$customers, $customer;
  });

  return $customers;
}

sub _get_pg ($self, $where, $limit) {
  my $db = $self->database;
  my $customers = [];

  # Build WHERE clause for customerid if specified
  my $where_sql = '';
  my @bind;
  if ($where->{customerid}) {
    $where_sql = 'WHERE c.customerid = ?';
    push @bind, $where->{customerid};
  }

  # Build LIMIT/ORDER clause
  my $limit_sql = '';
  if (ref $limit eq 'HASH') {
    $limit_sql .= "ORDER BY $limit->{-order_by}" if $limit->{-order_by};
    $limit_sql .= " LIMIT $limit->{-limit}" if $limit->{-limit};
    $limit_sql .= " OFFSET $limit->{-offset}" if $limit->{-offset};
  }

  my $sql = qq{
    SELECT
      c.customerid,
      c.contactid,
      c.orgnoid,
      c.entitytypeid,
      c.created,
      c.updated,
      co.lastcheck,
      co.email AS contactemail,
      co.givenname AS firstname,
      co.commonname AS lastname,
      co.displayname AS company,
      co.organization,
      co.address,
      co.pc AS zip,
      co.city,
      co.telephone AS phone1,
      co.mobile AS phone2,
      cnt.cc AS country,
      l.code AS lang,
      o.orgno,
      o.vatno,
      s.currencyid,
      cur.symbol AS currency,
      s.period,
      s.invoicetype,
      s.vat,
      s.trust,
      s.active,
      s.newsletter,
      s.reference,
      s.freetext,
      s.recommendedby
    FROM customer.customers c
    LEFT JOIN account.contacts co ON c.contactid = co.contactid
    LEFT JOIN customer.orgnos o ON c.orgnoid = o.orgnoid
    LEFT JOIN customer.settings s ON c.customerid = s.customerid
    LEFT JOIN public.countries cnt ON co.countryid = cnt.countryid
    LEFT JOIN public.languages l ON co.languageid = l.languageid
    LEFT JOIN public.currencies cur ON s.currencyid = cur.currencyid
    $where_sql
    $limit_sql
  };

  $db->query($sql, @bind)->hashes->each(sub ($customer, $num) {
    # Set default for active if NULL
    $customer->{active} //= 1;

    # Billing fields default to primary contact info
    $customer->{billingemail}   = $customer->{contactemail};
    $customer->{billingcity}    = $customer->{city};
    $customer->{billingzip}     = $customer->{zip};
    $customer->{billingaddress} = $customer->{address};
    $customer->{billingcountry} = $customer->{country};
    $customer->{billinglang}    = $customer->{lang};

    # TODO: fetch billing contact from entityroleusers if exists
    push @$customers, $customer;
  });

  return $customers;
}

sub name ($self, $customer) {
  my $name = trim($customer->{company} // '');
  if ($name eq '') {
    $name = trim(sprintf('%s %s', $customer->{firstname} // '', $customer->{lastname} // ''));
  }
  $name =~ s/ {2,}/ /g;
  return $name;
}

sub add ($self, $customer) {
  return $self->dbtype eq 'mysql'
    ? $self->_add_mysql($customer)
    : $self->_add_pg($customer);
}

sub _add_mysql ($self, $customer) {
  my $db = $self->database;
  return $db->insert('customer', $customer);
}

sub _add_pg ($self, $customer) {
  my $db = $self->database;
  my $tx = $db->begin;

  # 1. Create contact
  my $contact = $db->insert('account.contacts', {
    email        => $customer->{contactemail} // '',
    givenname    => $customer->{firstname},
    commonname   => $customer->{lastname},
    displayname  => $customer->{company} || join(' ', grep { $_ } $customer->{firstname}, $customer->{lastname}) || '',
    organization => $customer->{company},
    address      => $customer->{address},
    pc           => $customer->{zip},
    city         => $customer->{city},
    telephone    => $customer->{phone1},
    mobile       => $customer->{phone2},
    countryid    => $self->_lookup_country($customer->{country}),
    languageid   => $self->_lookup_language($customer->{lang}),
  }, { returning => 'contactid' })->hash;

  # 2. Create orgno if provided
  my $orgnoid;
  if ($customer->{orgno}) {
    my $countryid = $self->_lookup_country($customer->{country}) // 1;
    my $existing = $db->select('customer.orgnos', ['orgnoid'], {
      orgno => $customer->{orgno}, country => $countryid
    })->hash;

    if ($existing) {
      $orgnoid = $existing->{orgnoid};
    } else {
      $orgnoid = $db->insert('customer.orgnos', {
        orgno   => $customer->{orgno},
        country => $countryid,
        vatno   => $customer->{vatno},
      }, { returning => 'orgnoid' })->hash->{orgnoid};
    }
  }

  # 3. Create customer
  my $result = $db->insert('customer.customers', {
    contactid    => $contact->{contactid},
    orgnoid      => $orgnoid,
    entitytypeid => $customer->{company} ? 2 : 1,  # 1=individual, 2=company
    created      => \'NOW()',
  }, { returning => 'customerid' })->hash;

  # 4. Create settings
  $db->insert('customer.settings', {
    customerid    => $result->{customerid},
    languageid    => $self->_lookup_language($customer->{lang}) // 1,
    currencyid    => $self->_lookup_currency($customer->{currency}) // 1,
    period        => $customer->{period} // 'monthly',
    invoicetype   => $customer->{invoicetype} // 'email',
    vat           => $customer->{vat} // 0.25,
    trust         => $customer->{trust} // 0,
    active        => $customer->{active} // 1,
    newsletter    => $customer->{newsletter} // 0,
    reference     => $customer->{reference},
    freetext      => $customer->{freetext},
    recommendedby => $customer->{recommendedby},
  });

  $tx->commit;
  return $result->{customerid};
}

sub update ($self, $customerid = 0, $customer = {}) {
  return 0 unless $customerid;

  return $self->dbtype eq 'mysql'
    ? $self->_update_mysql($customerid, $customer)
    : $self->_update_pg($customerid, $customer);
}

sub _update_mysql ($self, $customerid, $customer) {
  my $db = $self->database;
  return $db->update('customer', $customer, { customerid => $customerid });
}

sub _update_pg ($self, $customerid, $customer) {
  my $db = $self->database;
  my $tx = $db->begin;

  # Get existing customer to find contactid
  my $existing = $db->select('customer.customers', ['contactid', 'orgnoid'], { customerid => $customerid })->hash;
  return 0 unless $existing;

  # Update contact
  if ($existing->{contactid}) {
    my $contact_update = {};
    $contact_update->{email}        = $customer->{contactemail} if exists $customer->{contactemail};
    $contact_update->{givenname}    = $customer->{firstname} if exists $customer->{firstname};
    $contact_update->{commonname}   = $customer->{lastname} if exists $customer->{lastname};
    $contact_update->{displayname}  = $customer->{company} if exists $customer->{company};
    $contact_update->{organization} = $customer->{company} if exists $customer->{company};
    $contact_update->{address}      = $customer->{address} if exists $customer->{address};
    $contact_update->{pc}           = $customer->{zip} if exists $customer->{zip};
    $contact_update->{city}         = $customer->{city} if exists $customer->{city};
    $contact_update->{telephone}    = $customer->{phone1} if exists $customer->{phone1};
    $contact_update->{mobile}       = $customer->{phone2} if exists $customer->{phone2};
    $contact_update->{countryid}    = $self->_lookup_country($customer->{country}) if exists $customer->{country};
    $contact_update->{languageid}   = $self->_lookup_language($customer->{lang}) if exists $customer->{lang};

    $db->update('account.contacts', $contact_update, { contactid => $existing->{contactid} }) if %$contact_update;
  }

  # Update settings
  my $settings_update = {};
  $settings_update->{languageid}    = $self->_lookup_language($customer->{lang}) if exists $customer->{lang};
  $settings_update->{currencyid}    = $self->_lookup_currency($customer->{currency}) if exists $customer->{currency};
  $settings_update->{period}        = $customer->{period} if exists $customer->{period};
  $settings_update->{invoicetype}   = $customer->{invoicetype} if exists $customer->{invoicetype};
  $settings_update->{vat}           = $customer->{vat} if exists $customer->{vat};
  $settings_update->{trust}         = $customer->{trust} if exists $customer->{trust};
  $settings_update->{active}        = $customer->{active} if exists $customer->{active};
  $settings_update->{newsletter}    = $customer->{newsletter} if exists $customer->{newsletter};
  $settings_update->{reference}     = $customer->{reference} if exists $customer->{reference};
  $settings_update->{freetext}      = $customer->{freetext} if exists $customer->{freetext};
  $settings_update->{recommendedby} = $customer->{recommendedby} if exists $customer->{recommendedby};

  $db->update('customer.settings', $settings_update, { customerid => $customerid }) if %$settings_update;

  # Update customers table (audit fields)
  $db->update('customer.customers', { updated => \'NOW()' }, { customerid => $customerid });

  $tx->commit;
  return 1;
}

sub delete ($self, $customerid) {
  return 0 unless $customerid;
  my $db = $self->database;

  if ($self->dbtype eq 'mysql') {
    return $db->delete('customer', { customerid => $customerid });
  } else {
    # PostgreSQL: cascade will handle related records
    return $db->delete('customer.customers', { customerid => $customerid });
  }
}

sub archive ($self, $customerid) {
  # TODO: implement archiving
  return 0;
}

sub userlogins ($self, $params = {}) {
  my $where = $params->{where} // {};

  if ($self->dbtype eq 'mysql') {
    return $self->database->select('snapusers', '*', $where)->hashes;
  } else {
    # PostgreSQL: query account.users joined with contacts
    my $db = $self->database;
    my $where_sql = '';
    my @bind;

    if ($where->{customerid}) {
      $where_sql = 'WHERE eru.customerid = ?';
      push @bind, $where->{customerid};
    }

    return $db->query(qq{
      SELECT
        u.userid AS id,
        u.username AS userlogin,
        c.email,
        c.displayname AS name,
        c.organization AS org,
        u.created,
        u.modified AS updated
      FROM account.users u
      JOIN account.contacts c ON u.contactid = c.contactid
      LEFT JOIN customer.entityroleusers eru ON u.userid = eru.userid
      $where_sql
    }, @bind)->hashes;
  }
}

sub neighbours ($self, $customerid) {
  my $db = $self->database;
  my $table = $self->dbtype eq 'mysql' ? 'customer' : 'customer.customers';

  my ($minid, $maxid) = @{$db->query(
    "SELECT MIN(customerid) AS minid, MAX(customerid) AS maxid FROM $table"
  )->array};

  my $neighbours = {
    minid => $minid,
    maxid => $maxid,
    nextid => $minid,
    previd => $maxid,
  };

  my $next = $db->query(
    "SELECT customerid FROM $table WHERE customerid > ? ORDER BY customerid ASC LIMIT 1",
    $customerid
  )->array;
  $neighbours->{nextid} = $next->[0] if $next;

  my $prev = $db->query(
    "SELECT customerid FROM $table WHERE customerid < ? ORDER BY customerid DESC LIMIT 1",
    $customerid
  )->array;
  $neighbours->{previd} = $prev->[0] if $prev;

  return $neighbours;
}

# Lookup helpers for PostgreSQL
sub _lookup_country ($self, $country_code) {
  return undef unless $country_code;
  my $result = $self->app->pg->db->select('public.countries', ['countryid'], { cc => uc($country_code) })->hash;
  return $result ? $result->{countryid} : undef;
}

sub _lookup_language ($self, $lang_code) {
  return undef unless $lang_code;
  my ($base) = $lang_code =~ /^([a-z]{2})/i;
  my $result = $self->app->pg->db->select('public.languages', ['languageid'], { code => lc($base) })->hash;
  return $result ? $result->{languageid} : 1;
}

sub _lookup_currency ($self, $currency_code) {
  return undef unless $currency_code;
  my $result = $self->app->pg->db->select('public.currencies', ['currencyid'], { symbol => uc($currency_code) })->hash;
  return $result ? $result->{currencyid} : undef;
}

1;
