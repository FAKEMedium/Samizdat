package Samizdat::Model::Mailer;

use Mojo::Base -base, -signatures;

has 'config';
has 'pg';
has 'minion';

sub db ($self) { $self->pg->db }

# Mails (formerly notifications)

sub mails ($self, $params = {}) {
  my $where = $params->{where} // {};
  my $order = $params->{order} // { -desc => 'created' };

  return $self->db->select('mailer.mails', '*', $where, $order)->hashes;
}

sub mail_get ($self, $mailid) {
  return $self->db->select('mailer.mails', '*', { mailid => $mailid })->hash;
}

sub mail_create ($self, $data) {
  my $result = $self->db->insert('mailer.mails', {
    name       => $data->{name},
    customerid => $data->{customerid},
    is_draft   => $data->{is_draft} // 1,
    status     => 'draft',
    creator    => $data->{creator},
  }, { returning => '*' });
  return $result->hash;
}

sub mail_update ($self, $mailid, $data) {
  my %update = map { $_ => $data->{$_} } grep { exists $data->{$_} } qw(name is_draft status scheduled);
  $update{modified} = \'now()';
  my $result = $self->db->update('mailer.mails', \%update, { mailid => $mailid }, { returning => '*' });
  return $result->hash;
}

sub mail_delete ($self, $mailid) {
  return $self->db->delete('mailer.mails', { mailid => $mailid })->rows;
}

# Copy mail as draft (including contents and attachments)
sub mail_copy ($self, $mailid, $params = {}) {
  my $original = $self->mail_get($mailid);
  return unless $original;

  my $name = $params->{name} || 'Copy of ' . $original->{name};

  # Create new mail as draft
  my $new_mail = $self->db->insert('mailer.mails', {
    name       => $name,
    customerid => $original->{customerid},
    is_draft   => 1,
    status     => 'draft',
    creator    => $params->{creator} // $original->{creator},
  }, { returning => '*' })->hash;

  # Copy contents
  my $contents = $self->mail_contents($mailid);
  for my $c (@$contents) {
    my $new_content = $self->db->insert('mailer.mail_contents', {
      mailid       => $new_mail->{mailid},
      languageid   => $c->{languageid},
      'from'       => $c->{from},
      organization => $c->{organization},
      subject      => $c->{subject},
      body_md      => $c->{body_md},
    }, { returning => '*' })->hash;

    # Copy attachments for this content
    my $attachments = $self->attachments($c->{contentid});
    for my $a (@$attachments) {
      $self->db->insert('mailer.attachments', {
        contentid => $new_content->{contentid},
        filename  => $a->{filename},
        filepath  => $a->{filepath},
        mimetype  => $a->{mimetype},
      });
    }
  }

  return $new_mail;
}

# Mail contents (localized)

sub mail_contents ($self, $mailid) {
  return $self->db->select('mailer.mail_contents', '*', { mailid => $mailid })->hashes;
}

sub content_get ($self, $contentid) {
  return $self->db->select('mailer.mail_contents', '*', { contentid => $contentid })->hash;
}

sub content_upsert ($self, $data) {
  my $existing = $self->db->select('mailer.mail_contents', '*', {
    mailid     => $data->{mailid},
    languageid => $data->{languageid},
  })->hash;

  if ($existing) {
    return $self->db->update('mailer.mail_contents', {
      subject => $data->{subject},
      body_md => $data->{body_md},
    }, { contentid => $existing->{contentid} }, { returning => '*' })->hash;
  } else {
    return $self->db->insert('mailer.mail_contents', $data, { returning => '*' })->hash;
  }
}

sub content_delete ($self, $contentid) {
  return $self->db->delete('mailer.mail_contents', { contentid => $contentid })->rows;
}

# Attachments

sub attachments ($self, $contentid) {
  return $self->db->select('mailer.attachments', '*', { contentid => $contentid })->hashes;
}

sub attachment_add ($self, $data) {
  return $self->db->insert('mailer.attachments', $data, { returning => '*' })->hash;
}

sub attachment_delete ($self, $attachmentid) {
  return $self->db->delete('mailer.attachments', { attachmentid => $attachmentid })->rows;
}

# Lists

sub lists ($self, $params = {}) {
  my $where = $params->{where} // {};
  my $order = $params->{order} // { -asc => 'name' };
  return $self->db->select('mailer.lists', '*', $where, $order)->hashes;
}

sub list_get ($self, $listid) {
  return $self->db->select('mailer.lists', '*', { listid => $listid })->hash;
}

sub list_create ($self, $data) {
  return $self->db->insert('mailer.lists', {
    name        => $data->{name},
    description => $data->{description},
    customerid  => $data->{customerid},
    is_public   => $data->{is_public} // 0,
  }, { returning => '*' })->hash;
}

sub list_update ($self, $listid, $data) {
  my %update = map { $_ => $data->{$_} } grep { exists $data->{$_} } qw(name description is_public);
  return $self->db->update('mailer.lists', \%update, { listid => $listid }, { returning => '*' })->hash;
}

sub list_delete ($self, $listid) {
  return $self->db->delete('mailer.lists', { listid => $listid })->rows;
}

sub list_addresses ($self, $listid) {
  return $self->db->query(q{
    SELECT a.*, la.subscribed
    FROM mailer.addresses a
    JOIN mailer.list_addresses la ON la.addressid = a.addressid
    WHERE la.listid = ?
    ORDER BY a.email
  }, $listid)->hashes;
}

sub list_add_address ($self, $listid, $addressid) {
  return $self->db->insert('mailer.list_addresses', {
    listid    => $listid,
    addressid => $addressid,
  }, { returning => '*' })->hash;
}

sub list_remove_address ($self, $listid, $addressid) {
  return $self->db->delete('mailer.list_addresses', { listid => $listid, addressid => $addressid })->rows;
}

# Addresses (formerly recipients)

sub addresses ($self, $params = {}) {
  my $where = $params->{where} // {};
  my $order = $params->{order} // { -asc => 'email' };
  return $self->db->select('mailer.addresses', '*', $where, $order)->hashes;
}

sub address_get ($self, $addressid) {
  return $self->db->select('mailer.addresses', '*', { addressid => $addressid })->hash;
}

sub address_by_email ($self, $email) {
  return $self->db->select('mailer.addresses', '*', { email => $email })->hash;
}

sub address_create ($self, $data) {
  return $self->db->insert('mailer.addresses', {
    email      => $data->{email},
    first_name => $data->{first_name},
    last_name  => $data->{last_name},
    source     => $data->{source} // 'import',
    languageid => $data->{languageid} // 1,
  }, { returning => '*' })->hash;
}

sub address_import ($self, $list, $source = 'import') {
  my $count = 0;
  for my $a (@$list) {
    eval {
      $self->db->insert('mailer.addresses', {
        email      => $a->{email},
        name       => $a->{name},
        first_name => $a->{first_name},
        last_name  => $a->{last_name},
        source     => $source,
        languageid => $a->{languageid} // 1,
      });
      $count++;
    };
  }
  return $count;
}

# Import addresses into a list
# Options:
#   format: 'text' (parse for emails) or 'csv' (column mapping)
#   data: raw text or CSV content
#   columns: { email => 0, name => 1, first_name => 2, last_name => 3 } (for CSV)
#   listid: target list
#   customerid: owner customer
#   source: import source tag
sub import_to_list ($self, $params) {
  my $format = $params->{format} // 'text';
  my $data = $params->{data} // '';
  my $listid = $params->{listid};
  my $customerid = $params->{customerid};
  my $source = $params->{source} // 'import';
  my $columns = $params->{columns} // {};

  my @addresses;

  if ($format eq 'text') {
    @addresses = $self->_parse_text_for_emails($data);
  } elsif ($format eq 'csv') {
    @addresses = $self->_parse_csv($data, $columns);
  }

  my @results;
  my $created = 0;
  my $linked = 0;
  my $needs_review = 0;

  for my $addr (@addresses) {
    my $email = lc($addr->{email} // '');
    next unless $email && $email =~ /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    # Check if address exists for this customer
    my $existing = $self->db->select('mailer.addresses', '*', {
      customerid => $customerid,
      email      => $email,
    })->hash;

    my $addressid;
    my $review_flag = 0;

    if ($existing) {
      $addressid = $existing->{addressid};
      $linked++;
    } else {
      # Process name fields
      my ($name, $first_name, $last_name) = $self->_process_name_fields($addr);
      $review_flag = 1 if $addr->{name} && !$addr->{first_name} && !$addr->{last_name};

      my $new = $self->db->insert('mailer.addresses', {
        customerid   => $customerid,
        email        => $email,
        name         => $name,
        first_name   => $first_name,
        last_name    => $last_name,
        needs_review => $review_flag,
        source       => $source,
        languageid   => $addr->{languageid} // 1,
      }, { returning => '*' })->hash;

      $addressid = $new->{addressid};
      $created++;
      $needs_review++ if $review_flag;
    }

    # Link to list if not already linked
    if ($listid && $addressid) {
      eval {
        $self->db->insert('mailer.list_addresses', {
          listid    => $listid,
          addressid => $addressid,
        });
      };
    }

    push @results, {
      email        => $email,
      name         => $addr->{name},
      first_name   => $addr->{first_name},
      last_name    => $addr->{last_name},
      addressid    => $addressid,
      is_new       => !$existing,
      needs_review => $review_flag,
    };
  }

  return {
    success      => 1,
    created      => $created,
    linked       => $linked,
    needs_review => $needs_review,
    total        => scalar(@results),
    results      => \@results,
  };
}

sub _parse_text_for_emails ($self, $text) {
  my @addresses;
  # Extract email addresses from text
  while ($text =~ /([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/g) {
    push @addresses, { email => lc($1) };
  }
  return @addresses;
}

sub _parse_csv ($self, $data, $columns) {
  my @addresses;
  my @lines = split /\r?\n/, $data;

  # Skip header if first line looks like a header
  my $start = 0;
  if (@lines && $lines[0] =~ /email|address|e-mail/i) {
    $start = 1;
  }

  for my $i ($start .. $#lines) {
    my $line = $lines[$i];
    next unless $line =~ /\S/;

    # Simple CSV parsing (handle quoted fields)
    my @fields;
    while ($line =~ /("([^"]*(?:""[^"]*)*)"|[^,]*)(,|$)/g) {
      my $field = defined $2 ? $2 : $1;
      $field =~ s/""/"/g if defined $2;
      $field =~ s/^\s+|\s+$//g;
      push @fields, $field;
      last if $3 eq '';
    }

    my %addr;
    $addr{email}      = $fields[$columns->{email}]      if defined $columns->{email};
    $addr{name}       = $fields[$columns->{name}]       if defined $columns->{name};
    $addr{first_name} = $fields[$columns->{first_name}] if defined $columns->{first_name};
    $addr{last_name}  = $fields[$columns->{last_name}]  if defined $columns->{last_name};

    push @addresses, \%addr if $addr{email};
  }

  return @addresses;
}

sub _process_name_fields ($self, $addr) {
  my $name = $addr->{name} // '';
  my $first_name = $addr->{first_name} // '';
  my $last_name = $addr->{last_name} // '';

  # If we have first and last, concatenate to name
  if ($first_name || $last_name) {
    $name ||= join(' ', grep { $_ } ($first_name, $last_name));
  }
  # If we only have name, try to split
  elsif ($name && !$first_name && !$last_name) {
    my @parts = split /\s+/, $name;
    if (@parts >= 2) {
      $first_name = shift @parts;
      $last_name = join(' ', @parts);
    } elsif (@parts == 1) {
      $first_name = $parts[0];
    }
  }

  return ($name, $first_name, $last_name);
}

sub addresses_needing_review ($self, $customerid) {
  return $self->db->select('mailer.addresses', '*', {
    customerid   => $customerid,
    needs_review => 1,
  }, { -asc => 'email' })->hashes;
}

sub address_update ($self, $addressid, $data) {
  my %update = map { $_ => $data->{$_} } grep { exists $data->{$_} }
    qw(name first_name last_name languageid verified needs_review);
  return $self->db->update('mailer.addresses', \%update, { addressid => $addressid }, { returning => '*' })->hash;
}

sub address_delete ($self, $addressid) {
  return $self->db->delete('mailer.addresses', { addressid => $addressid })->rows;
}

# Deliveries

sub deliveries ($self, $mailid) {
  return $self->db->select('mailer.deliveries', '*', { mailid => $mailid }, { -asc => 'email' })->hashes;
}

sub delivery_stats ($self, $mailid) {
  my $stats = $self->db->query(q{
    SELECT status, COUNT(*) as count
    FROM mailer.deliveries
    WHERE mailid = ?
    GROUP BY status
  }, $mailid)->hashes;

  my %result = map { $_->{status} => $_->{count} } @$stats;
  $result{total} = 0;
  $result{total} += $_ for values %result;

  # Add bounce count
  my $bounces = $self->db->query(q{
    SELECT COUNT(*) as count
    FROM mailer.bounces b
    JOIN mailer.deliveries d ON d.deliveryid = b.deliveryid
    WHERE d.mailid = ?
  }, $mailid)->hash;
  $result{bounced} = $bounces->{count} // 0;

  return \%result;
}

# Get bounces for a mail with removal suggestions
sub mail_bounces ($self, $mailid) {
  return $self->db->query(q{
    SELECT b.*, d.email, a.addressid, a.first_name, a.last_name,
           CASE
             WHEN b.bounce_type = 'hard' THEN true
             WHEN b.bounce_type = 'complaint' THEN true
             WHEN b.bounce_type = 'soft' AND (
               SELECT COUNT(*) FROM mailer.bounces b2
               JOIN mailer.deliveries d2 ON d2.deliveryid = b2.deliveryid
               WHERE d2.email = d.email
             ) >= 3 THEN true
             ELSE false
           END AS suggest_remove
    FROM mailer.bounces b
    JOIN mailer.deliveries d ON d.deliveryid = b.deliveryid
    LEFT JOIN mailer.addresses a ON a.addressid = d.addressid
    WHERE d.mailid = ?
    ORDER BY b.bounce_type, d.email
  }, $mailid)->hashes;
}

# Bulk remove addresses by IDs
sub addresses_bulk_delete ($self, $addressids) {
  return 0 unless $addressids && @$addressids;
  my $placeholders = join(',', ('?') x @$addressids);
  return $self->db->query(
    "DELETE FROM mailer.addresses WHERE addressid IN ($placeholders)",
    @$addressids
  )->rows;
}

# Get addresses suggested for removal (hard bounces, complaints, repeated soft bounces)
sub addresses_to_remove ($self, $customerid = undef) {
  my $where = $customerid ? 'AND a.customerid = ?' : '';
  my @params = $customerid ? ($customerid) : ();

  return $self->db->query(qq{
    SELECT DISTINCT a.addressid, a.email, a.first_name, a.last_name,
           b.bounce_type, b.bounce_code, b.diagnostic,
           (SELECT COUNT(*) FROM mailer.bounces b2
            JOIN mailer.deliveries d2 ON d2.deliveryid = b2.deliveryid
            WHERE d2.email = a.email) AS bounce_count
    FROM mailer.addresses a
    JOIN mailer.deliveries d ON d.addressid = a.addressid
    JOIN mailer.bounces b ON b.deliveryid = d.deliveryid
    WHERE (
      b.bounce_type IN ('hard', 'complaint')
      OR (
        b.bounce_type = 'soft'
        AND (SELECT COUNT(*) FROM mailer.bounces b3
             JOIN mailer.deliveries d3 ON d3.deliveryid = b3.deliveryid
             WHERE d3.email = a.email) >= 3
      )
    )
    $where
    ORDER BY b.bounce_type, a.email
  }, @params)->hashes;
}

sub delivery_create ($self, $data) {
  return $self->db->insert('mailer.deliveries', $data, { returning => '*' })->hash;
}

sub delivery_update ($self, $deliveryid, $data) {
  return $self->db->update('mailer.deliveries', $data, { deliveryid => $deliveryid }, { returning => '*' })->hash;
}

# Unsubscriptions

sub unsubscriptions ($self, $params = {}) {
  my $where = $params->{where} // {};
  return $self->db->select('mailer.unsubscriptions', '*', $where, { -desc => 'created' })->hashes;
}

sub is_unsubscribed ($self, $email) {
  return $self->db->select('mailer.unsubscriptions', 'unsubscriptionid', { email => $email })->hash ? 1 : 0;
}

sub unsubscribe ($self, $email, $reason = 'unsubscribe') {
  return if $self->is_unsubscribed($email);
  return $self->db->insert('mailer.unsubscriptions', {
    email  => $email,
    reason => $reason,
  }, { returning => '*' })->hash;
}

sub unsubscribe_by_token ($self, $token) {
  my $unsub = $self->db->select('mailer.unsubscriptions', '*', { token => $token })->hash;
  return $unsub;
}

sub generate_unsubscribe_token ($self, $email) {
  use Digest::SHA qw(hmac_sha256_base64);
  use MIME::Base64 qw(encode_base64);

  my $secret = $self->config->{secret} // 'mailer-unsubscribe-secret';
  my $sig = hmac_sha256_base64($email, $secret);
  return encode_base64("$email:$sig", '');
}

sub verify_unsubscribe_token ($self, $token) {
  use MIME::Base64 qw(decode_base64);

  my $decoded = eval { decode_base64($token) };
  return unless $decoded;

  my ($email, $sig) = split /:/, $decoded, 2;
  return unless $email && $sig;

  # Verify by regenerating
  my $expected = $self->generate_unsubscribe_token($email);
  return $email if $expected eq $token;
  return;
}

sub resubscribe ($self, $email) {
  return $self->db->delete('mailer.unsubscriptions', { email => $email })->rows;
}

sub unsubscription_delete ($self, $unsubscriptionid) {
  return $self->db->delete('mailer.unsubscriptions', { unsubscriptionid => $unsubscriptionid })->rows;
}

# Bounces

sub bounces ($self, $params = {}) {
  my $where = $params->{where} // {};
  return $self->db->select('mailer.bounces', '*', $where, { -desc => 'received' })->hashes;
}

sub bounce_get ($self, $bounceid) {
  return $self->db->select('mailer.bounces', '*', { bounceid => $bounceid })->hash;
}

sub bounce_create ($self, $data) {
  return $self->db->insert('mailer.bounces', $data, { returning => '*' })->hash;
}

sub bounce_delete ($self, $bounceid) {
  return $self->db->delete('mailer.bounces', { bounceid => $bounceid })->rows;
}

# Stats

sub stats ($self, $params = {}) {
  my $where = $params->{where} // {};
  return $self->db->select('mailer.stats', '*', $where, { -desc => 'created' })->hashes;
}

sub stat_create ($self, $data) {
  return $self->db->insert('mailer.stats', $data, { returning => '*' })->hash;
}

# Config (per-customer key/value settings)

sub configs ($self, $customerid) {
  return $self->db->select('mailer.configs', '*', { customerid => $customerid }, { -asc => 'key' })->hashes;
}

sub config_get ($self, $customerid, $key) {
  my $row = $self->db->select('mailer.configs', 'value', { customerid => $customerid, key => $key })->hash;
  return $row ? $row->{value} : undef;
}

sub config_set ($self, $customerid, $key, $value) {
  my $existing = $self->db->select('mailer.configs', 'configid', { customerid => $customerid, key => $key })->hash;

  if ($existing) {
    return $self->db->update('mailer.configs', { value => $value }, { configid => $existing->{configid} }, { returning => '*' })->hash;
  } else {
    return $self->db->insert('mailer.configs', {
      customerid => $customerid,
      key        => $key,
      value      => $value,
    }, { returning => '*' })->hash;
  }
}

sub config_delete ($self, $customerid, $key) {
  return $self->db->delete('mailer.configs', { customerid => $customerid, key => $key })->rows;
}

# Common config keys:
#   sender_name    - Default From name
#   sender_email   - Default From email
#   reply_to       - Reply-To address
#   organization   - Organization header
#   footer_text    - Footer added to all emails
#   unsubscribe_text - Unsubscribe link text

# Search

sub search ($self, $q, $type = 'mail') {
  my $pattern = '%' . $q . '%';

  if ($type eq 'mail') {
    return $self->db->select('mailer.mails', '*', { name => { -ilike => $pattern } }, { -desc => 'created' })->hashes;
  } elsif ($type eq 'address') {
    return $self->db->query(q{
      SELECT * FROM mailer.addresses
      WHERE email ILIKE ? OR first_name ILIKE ? OR last_name ILIKE ?
      ORDER BY email
      LIMIT 50
    }, $pattern, $pattern, $pattern)->hashes;
  } elsif ($type eq 'bounce') {
    return $self->db->select('mailer.bounces', '*', { email => { -ilike => $pattern } }, { -desc => 'received' })->hashes;
  }

  return [];
}

# Privacy self-service

sub privacy_data ($self, $private_id) {
  # Get address by private_id
  my $address = $self->db->select('mailer.addresses', '*', { private_id => $private_id })->hash;
  return { address => undef } unless $address;

  # Get list memberships
  my $lists = $self->db->query(q{
    SELECT l.listid, l.name, l.description, la.subscribed
    FROM mailer.lists l
    JOIN mailer.list_addresses la ON la.listid = l.listid
    WHERE la.addressid = ?
    ORDER BY l.name
  }, $address->{addressid})->hashes;

  # Get delivery history (what mails were sent to this address)
  my $deliveries = $self->db->query(q{
    SELECT d.mailid, m.name as mail_name, d.status, d.sent
    FROM mailer.deliveries d
    JOIN mailer.mails m ON m.mailid = d.mailid
    WHERE d.addressid = ?
    ORDER BY d.queued DESC
    LIMIT 50
  }, $address->{addressid})->hashes;

  return {
    address    => $address,
    lists      => $lists,
    deliveries => $deliveries,
  };
}

sub privacy_delete ($self, $private_id) {
  # Get address by private_id
  my $address = $self->db->select('mailer.addresses', 'addressid', { private_id => $private_id })->hash;
  return 0 unless $address;

  # Delete address (cascades to list_addresses and deliveries via FK)
  return $self->db->delete('mailer.addresses', { addressid => $address->{addressid} })->rows;
}

# Queue mail for sending

sub queue_mail ($self, $mailid, $params = {}) {
  my $mail = $self->mail_get($mailid);
  return { success => 0, error => 'Mail not found' } unless $mail;
  return { success => 0, error => 'Mail not in draft status' } unless $mail->{status} eq 'draft';

  my $contents = $self->mail_contents($mailid);
  return { success => 0, error => 'No content defined' } unless @$contents;

  # Build language lookup
  my %content_by_lang = map { $_->{languageid} => $_ } @$contents;
  my $default_lang = (sort keys %content_by_lang)[0];

  # Get target addresses based on params
  my @targets;

  if ($params->{listid}) {
    my $list_addrs = $self->list_addresses($params->{listid});
    for my $a (@$list_addrs) {
      push @targets, {
        email      => $a->{email},
        languageid => $a->{languageid},
        addressid  => $a->{addressid},
      };
    }
  }

  if ($params->{customer_filter}) {
    # Get customers matching filter
    push @targets, @{ $params->{customers} // [] };
  }

  # Create delivery records (skip unsubscribed)
  my $queued = 0;
  my $skipped = 0;

  for my $target (@targets) {
    next if $self->is_unsubscribed($target->{email});

    my $lang = $target->{languageid} // $default_lang;
    $lang = $default_lang unless exists $content_by_lang{$lang};

    eval {
      $self->delivery_create({
        mailid     => $mailid,
        email      => $target->{email},
        languageid => $lang,
        customerid => $target->{customerid},
        addressid  => $target->{addressid},
        status     => 'pending',
      });
      $queued++;
    };
    if ($@) {
      $skipped++ if $@ =~ /duplicate/i;
    }
  }

  # Update mail status
  $self->mail_update($mailid, { status => 'scheduled', is_draft => 0 });

  # Queue Minion job if available
  if ($self->minion) {
    $self->minion->enqueue(mailer_send_batch => [$mailid] => { priority => 5 });
  }

  return {
    success => 1,
    queued  => $queued,
    skipped => $skipped,
    toast   => sprintf('Queued %d deliveries (%d skipped)', $queued, $skipped),
  };
}

# Get pending deliveries for a batch send
# Interleaves domains to spread out sends per provider (reduces blacklist risk)

sub pending_deliveries ($self, $mailid, $limit = 50) {
  return $self->db->query(q{
    WITH ranked AS (
      SELECT d.*, c.subject, c.body_md, c.contentid,
             a.name, a.first_name, a.last_name, a.private_id,
             split_part(d.email, '@', 2) AS domain,
             ROW_NUMBER() OVER (PARTITION BY split_part(d.email, '@', 2) ORDER BY d.queued) AS domain_rank
      FROM mailer.deliveries d
      JOIN mailer.mail_contents c ON c.mailid = d.mailid AND c.languageid = d.languageid
      LEFT JOIN mailer.addresses a ON a.addressid = d.addressid
      WHERE d.mailid = ? AND d.status = 'pending'
    )
    SELECT deliveryid, mailid, email, languageid, customerid, addressid,
           status, queued, sent, error, subject, body_md, contentid,
           name, first_name, last_name, private_id
    FROM ranked
    ORDER BY domain_rank, domain, queued
    LIMIT ?
  }, $mailid, $limit)->hashes;
}

sub mark_sent ($self, $deliveryid) {
  return $self->db->update('mailer.deliveries', {
    status => 'sent',
    sent   => \'now()',
  }, { deliveryid => $deliveryid })->rows;
}

sub mark_failed ($self, $deliveryid, $error) {
  return $self->db->update('mailer.deliveries', {
    status => 'failed',
    error  => $error,
  }, { deliveryid => $deliveryid })->rows;
}

# Mustache-style template substitution
# Available placeholders:
#   {{email}}, {{name}}, {{first_name}}, {{last_name}}
#   {{unsubscribe_url}}, {{privacy_url}}
#   {{date}}, {{year}}

sub render_template ($self, $text, $vars = {}) {
  return $text unless $text;

  # Built-in variables
  my %data = (
    date => scalar(localtime),
    year => (localtime)[5] + 1900,
    %$vars,
  );

  # Replace {{placeholder}} with values
  $text =~ s/\{\{(\w+)\}\}/defined $data{$1} ? $data{$1} : ''/ge;

  return $text;
}

# Render content for a specific delivery
# Expects delivery from pending_deliveries (includes address fields)
# URLs are entry points only - actual private_id links sent via email verification
sub render_delivery ($self, $delivery, $base_url = '') {
  # Entry point URLs (no private data, customer-scoped)
  my $customerid = $delivery->{customerid} // 0;
  my $unsubscribe_url = $base_url . '/manager/mailer/unsubscribe?c=' . $customerid;
  my $privacy_url     = $base_url . '/manager/mailer/privacy?c=' . $customerid;

  my %vars = (
    email           => $delivery->{email} // '',
    name            => $delivery->{name} // '',
    first_name      => $delivery->{first_name} // '',
    last_name       => $delivery->{last_name} // '',
    unsubscribe_url => $unsubscribe_url,
    privacy_url     => $privacy_url,
  );

  return {
    subject => $self->render_template($delivery->{subject}, \%vars),
    body_md => $self->render_template($delivery->{body_md}, \%vars),
  };
}

# Look up address by email and customerid
sub address_by_email_customer ($self, $email, $customerid) {
  return $self->db->select('mailer.addresses', '*', {
    email      => lc($email),
    customerid => $customerid,
  })->hash;
}

# Generate time-limited magic link token (expires in 1 hour)
sub generate_magic_token ($self, $private_id, $action = 'privacy') {
  use Digest::SHA qw(hmac_sha256_base64);
  use MIME::Base64 qw(encode_base64url);

  my $secret = $self->config->{secret} // 'mailer-magic-secret';
  my $expires = time() + 3600;  # 1 hour
  my $payload = "$private_id:$action:$expires";
  my $sig = hmac_sha256_base64($payload, $secret);

  return encode_base64url("$payload:$sig", '');
}

# Verify magic link token, returns { private_id, action } or undef
sub verify_magic_token ($self, $token) {
  use Digest::SHA qw(hmac_sha256_base64);
  use MIME::Base64 qw(decode_base64url);

  my $decoded = eval { decode_base64url($token) };
  return unless $decoded;

  my ($private_id, $action, $expires, $sig) = split /:/, $decoded, 4;
  return unless $private_id && $action && $expires && $sig;

  # Check expiry
  return if time() > $expires;

  # Verify signature
  my $secret = $self->config->{secret} // 'mailer-magic-secret';
  my $payload = "$private_id:$action:$expires";
  my $expected_sig = hmac_sha256_base64($payload, $secret);

  return unless $sig eq $expected_sig;

  return { private_id => $private_id, action => $action };
}

1;
