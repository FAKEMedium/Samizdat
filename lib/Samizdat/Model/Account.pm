package Samizdat::Model::Account;

use Mojo::Base -base, -signatures;
use Bytes::Random::Secure::Tiny;
use Crypt::Argon2 qw/argon2id_pass argon2id_verify/;
use Crypt::PBKDF2;
use Digest::SHA1 qw/sha1 sha1_hex/;
use App::bmkpasswd -all;
use UUID qw(uuid);
use Data::Dumper;

has 'config';
has 'database'; # Mojo::Pg or Mojo::mysql
has 'redis';
has 'last_error' => '';

my $pbkdf2 = Crypt::PBKDF2->new();

sub username ($self, $cookie) {
  my $db = $self->database->db;
  if ('mysql' eq $self->config->{dbtype}) {
  } else {

  }
  return 1; # Temporary solution
}


sub addUser ($self, $username, $attribs = {}) {
  my $db = $self->database->db;
  my $contactid = 0;
  my $userid = 0;
  my $passwordid = 0;
  $attribs->{username} = $username;
  my $password = delete $attribs->{password} // 'RANDOM' . uuid();
  my $email = delete $attribs->{email} // '';

  if ('mysql' eq $self->config->{dbtype}) {
    $userid = $db->insert('snapusers',
      $attribs,
      { returning => 'id' }
    )->hash->{id};
    $db->insert('passwords', {
      userid => $userid,
    });
  } else {
    my $contactattribs = {
      email => $email,
    };

    eval {
      my $tx = $db->begin;

      $contactid = $db->insert('account.contacts',
        $contactattribs,
        { returning => 'contactid' }
      )->hash->{contactid};

      if ($contactid =~ /^\d+$/ && $contactid > 0) {
        # Create password record first (new schema: users reference passwords)
        $passwordid = $db->insert('account.passwords',
          { changed => \'NOW()' },
          { returning => 'passwordid' }
        )->hash->{passwordid};

        # Create user with contactid and passwordid
        $attribs->{contactid} = $contactid;
        $attribs->{passwordid} = $passwordid if $passwordid;
        $userid = $db->insert('account.users',
          $attribs,
          { returning => 'userid' }
        )->hash->{userid};
      }
      $tx->commit;
    };
    if ($@) {
      $self->{last_error} = ref($@) && $@->can('message') ? $@->message : "$@";
      return undef;
    }

    if ($passwordid =~ /^\d+$/ && $passwordid > 0) {
      $self->savePassword($userid, $password);
    }
  }
  return $userid;
}


sub addEmailConfirmationRequest ($self, $userid, $contactid, $newemail, $ip) {
  my $db = $self->database->db;
  my $confirmationuuid = undef;
  
  eval {
    my $tx = $db->begin;
    
    if ('mysql' eq $self->config->{dbtype}) {
      $confirmationuuid = $db->insert('snapemailconfirmations', {
        userid => $userid,
        newemail  => $newemail
      }, {returning => 'id'})->hash->{id};
    } else {
      $confirmationuuid = $db->insert('account.emailconfirmationrequests', {
        userid       => $userid,
        contactid    => $contactid,
        newemail     => $newemail,
        ip           => $ip,
      }, {returning => 'confirmationuuid'})->hash->{confirmationuuid};
    }
    
    $tx->commit;
  };
  if ($@) {
    $self->{last_error} = ref($@) && $@->can('message') ? $@->message : "$@";
    return undef;
  }
  
  return $confirmationuuid;
}


sub getEmailConfirmationRequest ($self, $confirmationuuid) {
  my $db = $self->database->db;
  if ('mysql' eq $self->config->{dbtype}) {
    return $db->select('snapemailconfirmations', '*', { confirmationuuid => $confirmationuuid })->hash;
  } else {
    return $db->select('account.emailconfirmationrequests', '*', { confirmationuuid => $confirmationuuid })->hash;
  }
}


sub deleteEmailConfirmationRequest ($self, $confirmationuuid) {
  my $db = $self->database->db;
  if ('mysql' eq $self->config->{dbtype}) {
    return $db->delete('snapemailconfirmations', { confirmationuuid => $confirmationuuid });
  } else {
    return $db->delete('account.emailconfirmationrequests', { confirmationuuid => $confirmationuuid });
  }
}


sub getUsers ($self, $where){
  my $db = $self->database->db;
  my $result;
  if ('mysql' eq $self->config->{dbtype}) {
    $result = $db->select('snapusers',
      undef,
      $where
    )->hashes->to_array;
  } else {
   $result = $db->select(['account.users', ['account.contacts', 'contacts.contactid' => 'users.contactid']],
      'users.*, contacts.*',
      $where
    )->hashes->to_array;
  }
  say Dumper $result;
  return $result;
}


sub getUserGroups ($self, $userid) {
  my $db = $self->database->db;
  my $result;
  if ('mysql' eq $self->config->{dbtype}) {
    $result = $db->select(['snapusergroups', ['snapgroups', 'groups.id' => 'usergroups.groupid']],
      'groups.id, groups.groupname',
      { 'usergroups.userid' => $userid }
    )->hashes->to_array;
  } else {
    $result = $db->select(['account.usergroups', ['account.groups', 'groups.groupid' => 'usergroups.groupid']],
      'groups.groupid, groups.groupname',
      { 'usergroups.userid' => $userid }
    )->hashes->to_array;
  }
  
  return $result;
}


sub updateContact ($self, $contactid, $attribs = undef) {
  my $db = $self->database->db;
  if ('mysql' eq $self->config->{dbtype}) {
    $db->update('snapusers',
      $attribs,
      {contactid => $contactid},
      { returning => 'contactid' }
    )->hash->{contactid};
  } else {
    $db->update('account.contacts',
      $attribs,
      { 'contacts.contactid' => $contactid },
      { returning => 'contactid' }
    )->hash->{contactid};
  }
}


sub updateUser ($self, $userid, $attribs = undef) {
  my $db = $self->database->db;
  if ('mysql' eq $self->config->{dbtype}) {
    $db->update('snapusers',
      $attribs,
      { id => $userid },
      { returning => 'id' }
    )->hash->{id};
  } else {
    $db->update('account.users',
      $attribs,
      { 'users.userid' => $userid },
      { returning => 'userid' }
    )->hash->{userid};
  }
}


sub deleteUser ($self, $userid) {
  my $db = $self->database->db;
  if ('mysql' eq $self->config->{dbtype}) {
    $db->delete('snapusers', { id => $userid });
  } else {
    $db->delete('account.users', { 'users.userid' => $userid });
  }
}


sub savePassword ($self, $userid, $password) {
  my $db = $self->database->db;
  my $attribs = {};
  if ($self->config->{convertpasswordto}) {
    # Only store in the specified format
    my $method = $self->config->{convertpasswordto};
    $attribs->{'password' . $method} = $self->hashPassword($password, $method);
  } else {
    # For compatibility, wtore in all configured methods
    for my $method (@{ $self->config->{passwordmethods} }) {
      $attribs->{'password' . $method} = $self->hashPassword($password, $method);
    }
  }

  if ('mysql' eq $self->config->{dbtype}) {
    $db->update('passwords',
      $attribs,
      { userid => $userid },
      { returning => 'id' }
    )->hash->{id};
  } else {
    # New schema: look up passwordid from users table
    my $user = $db->select('account.users', ['passwordid'], { userid => $userid })->hash;
    return unless $user && $user->{passwordid};
    $db->update('account.passwords',
      $attribs,
      { 'passwords.passwordid' => $user->{passwordid} },
      { returning => 'passwordid' }
    )->hash->{passwordid};
  }
}


sub validatePassword ($self, $username, $plain) {
  my $userid = undef;
  my $db = $self->database->db;

  # Superadmins in the configuration file don't need to be in the database
  if (exists($self->config->{superadmins}->{$username}) &&  $self->config->{superadmins}->{$username} eq $plain) {
    $userid = 0;
  } else {
    my $result;
    if ('mysql' eq $self->config->{dbtype}) {
      $result = $db->select([ 'snapusers', [ -left => 'passwords', id => 'userid' ] ], 'passwords.*', {'snapusers.username' => $username})->hash;
    } else {
      # New schema: join users.passwordid to passwords.passwordid
      $result = $db->select([ 'account.users', [ -left => 'account.passwords', 'users.passwordid' => 'passwords.passwordid' ] ],
        ['passwords.*', 'users.userid'], {'users.username' => $username})->hash;
    }
    for my $method (@{ $self->config->{passwordmethods} }) {
      if ($method eq "sha512") {
        if ($result->{passwordsha512} && passwdcmp($plain, $result->{passwordsha512})) {
          $userid = $result->{userid};
          last;
        }
      } elsif ($method eq "bcrypt") {
        if ($result->{passwordbcrypt} && bcrypt_check($plain, $result->{passwordbcrypt})) {
          $userid = $result->{userid};
          last;
        }
      } elsif ($method eq "argon2id") {
        if ($result->{passwordargon2id} && argon2id_verify($result->{passwordargon2id}, $plain)) {
          $userid = $result->{userid};
          last;
        }
      } elsif ($method eq "mysql") {
        if ($result->{passwordmysql} && $result->{passwordmysql} eq sprintf('*%s', uc sha1_hex(sha1($plain)))) {
          $userid = $result->{userid};
          last;
        }
      } elsif ($method eq "pbkdf2") {
        if ($result->{passwordpbkdf2} && $pbkdf2->validate($result->{passwordpbkdf2}, $plain)) {
          $userid = $result->{userid};
          last;
        }
      }
    }
  }
  return $userid;
}


sub hashPassword ($self, $password, $method) {
  if ($method eq "sha512") {
    return mkpasswd($password, 'sha512');
  } elsif ($method eq "bcrypt") {
    return mkpasswd($password, 'bcrypt', 10);
  } elsif ($method eq "argon2id") {
    my $rng = Bytes::Random::Secure::Tiny->new;
    return argon2id_pass($password, $rng->bytes_hex(16), 3, '32M', 1, 16);
  } elsif ($method eq "mysql") {
    return sprintf('*%s', uc sha1_hex(sha1($password)));
  } elsif ($method eq "pbkdf2") {
    return $pbkdf2->generate($password);
  }  else {
    warn sprintf('Unknown password encryption method: %s', $method);
    return undef;
  }
}


sub session ($self, $authcookie) {
  my $session = $self->redis->db->hgetall("samizdat:$authcookie") // undef;
  if ($session && %$session) {
    # Refresh session expiration
    $self->redis->db->expire("samizdat:$authcookie", $self->config->{sessiontimeout});
  }
  return $session;
}


sub deleteSession ($self, $authcookie) {
  my $session = $self->redis->db->hgetall("samizdat:$authcookie");
  $self->redis->db->del("samizdat:$authcookie");
  return $session;
}


sub addSession ($self, $authcookie, $data, $expires = undef) {
  my $res = $self->redis->db->hmset("samizdat:$authcookie", %$data);
  $expires //= $self->config->{sessiontimeout};
  $self->refreshSession($authcookie, $expires);
}


sub refreshSession ($self, $authcookie, $expires = undef) {
  $expires //= $self->config->{sessiontimeout};
  $self->redis->db->expire("samizdat:$authcookie", $expires);
}


sub insertLogin ($self, $ip, $userid, $value) {
  my $db = $self->database->db;
  if ('mysql' eq $self->config->{dbtype}) {
    $db->insert('snapallsessions', {
      userlogin   => $userid,
      remote_host => $ip,
      value       => $value
    }, {returning => 'allsessionid'})->hash->{allsessionid};
  } else {
    $db->insert('account.logins', {
      userid => $userid,
      ip     => $ip,
    }, { returning => 'loginid' })->hash->{loginid};
  }
}


sub insertLoginFailure ($self, $ip, $username) {
  my $db = $self->database->db;
  if ('mysql' eq $self->config->{dbtype}) {
    $db->insert('loginfailures', {
      ip       => $ip,
      username => $username
    }, {returning => 'loginfailureid'})->hash->{loginfailureid};
  } else {
    $db->insert('account.loginfailures', {
      ip       => $ip,
      username => $username,
    }, { returning => 'loginfailureid' })->hash->{loginfailureid};
  }
}


sub getLoginFailures ($self, $ip) {
  my $db = $self->database->db;
  my $result;
  if ('mysql' eq $self->config->{dbtype}) {
    $result = $db->query("
      SELECT failuretime,ip,username
      FROM loginfailures
      WHERE (failuretime >=  now() - interval ? minute) AND (ip = ?)
      ORDER BY failuretime DESC LIMIT ?",
        $self->config->{blocktime},
        $ip,
        $self->config->{blocklimit}
    )->hashes->to_array;
  } else {
    $result = $db->query("
      SELECT failuretime,ip,username
      FROM account.loginfailures
      WHERE failuretime >= now() - (? * interval '1 minute') AND (ip = ?)
      ORDER BY failuretime DESC LIMIT ?",
        $self->config->{blocktime},
        $ip,
        $self->config->{blocklimit}
    )->hashes->to_array;
  }
  return $result;
}


# Get user profile data
sub get_profile ($self, $userid) {
  my $db = $self->database->db;

  # Get user with contacts, country code and language code
  my $user;
  eval {
    $user = $db->query(
      'SELECT u.userid, u.username, u.contactid,
              c.*, co.cc AS country_cc, l.code AS language_code
       FROM account.users u
       LEFT JOIN account.contacts c ON u.contactid = c.contactid
       LEFT JOIN public.countries co ON c.countryid = co.countryid
       LEFT JOIN public.languages l ON c.languageid = l.languageid
       WHERE u.userid = ?',
      $userid
    )->hash;
  };

  if ($@ || !$user) {
    return {};
  }

  my $profile = {
    contacts => {
      givenname    => $user->{givenname} // '',
      commonname   => $user->{commonname} // '',
      displayname  => $user->{displayname} // '',
      email        => $user->{email} // '',
      organization => $user->{organization} // '',
      address      => $user->{address} // '',
      pc           => $user->{pc} // '',
      city         => $user->{city} // '',
      telephone    => $user->{telephone} // '',
      mobile       => $user->{mobile} // '',
      website      => $user->{website} // '',
      dob          => $user->{dob} // '',
      countryid    => $user->{countryid},
      country_cc   => $user->{country_cc} // '',
      languageid   => $user->{languageid},
      language_code => $user->{language_code} // '',
      stateid      => $user->{stateid},
    }
  };

  return $profile;
}


# Get presentation for a specific language with fallback
sub get_presentation_for_language ($self, $userid, $lang) {
  my $profile = $self->get_profile($userid);

  # Return the presentation for the requested language if it exists
  if ($profile->{presentations} && $profile->{presentations}->{$lang}) {
    return $profile->{presentations}->{$lang};
  }

  # Otherwise return the fallback presentation (any existing one)
  if ($profile->{presentations} && $profile->{presentations}->{_fallback}) {
    # Return a copy with the language changed to indicate it needs translation
    my $fallback = { %{$profile->{presentations}->{_fallback}} };
    $fallback->{lang} = $lang;
    $fallback->{needs_translation} = 1;
    delete $fallback->{presentationid}; # Remove ID since this is a template for new entry
    return $fallback;
  }

  # Return empty presentation structure
  return {
    lang => $lang,
    title => '',
    content => '',
    needs_translation => 0
  };
}


# Update user profile data
sub update_profile ($self, $userid, $profile_data) {
  my $db = $self->database->db;

  my $tx = $db->begin;

  # Look up contactid for this user
  my $user = $db->query('SELECT contactid FROM account.users WHERE userid = ?', $userid)->hash;
  my $contactid = $user->{contactid} if $user;

  eval {
    # Update contacts data
    if (exists $profile_data->{contacts} && $contactid) {
      my $contacts = $profile_data->{contacts};
      my @updates;
      my @values;

      # Direct text fields
      for my $field (qw(givenname commonname email organization address pc city telephone mobile website)) {
        if (exists $contacts->{$field}) {
          push @updates, "$field = ?";
          push @values, $contacts->{$field} // '';
        }
      }

      # Auto-compute displayname from givenname + commonname
      my $given = $contacts->{givenname} // '';
      my $common = $contacts->{commonname} // '';
      my $display = join(' ', grep { length } $given, $common);
      push @updates, "displayname = ?";
      push @values, $display;

      # Date of birth
      if (exists $contacts->{dob}) {
        push @updates, "dob = ?";
        my $dob = $contacts->{dob};
        push @values, (defined $dob && length $dob) ? $dob : undef;
      }

      # Resolve country alpha2 code to countryid
      if (exists $contacts->{country}) {
        my $cc = $contacts->{country};
        if (defined $cc && length $cc) {
          my $row = $db->query('SELECT countryid FROM public.countries WHERE cc = ?', uc $cc)->hash;
          push @updates, "countryid = ?";
          push @values, $row ? $row->{countryid} : undef;
        } else {
          push @updates, "countryid = ?";
          push @values, undef;
        }
      }

      # Resolve language code to languageid
      if (exists $contacts->{language}) {
        my $code = $contacts->{language};
        if (defined $code && length $code) {
          my $row = $db->query('SELECT languageid FROM public.languages WHERE code = ?', $code)->hash;
          push @updates, "languageid = ?";
          push @values, $row ? $row->{languageid} : undef;
        } else {
          push @updates, "languageid = ?";
          push @values, undef;
        }
      }

      # State (direct stateid)
      if (exists $contacts->{stateid}) {
        push @updates, "stateid = ?";
        my $stateid = $contacts->{stateid};
        push @values, (defined $stateid && length $stateid) ? $stateid : undef;
      }

      if (@updates) {
        push @values, $contactid;
        $db->query(
          "UPDATE account.contacts SET " . join(', ', @updates) . " WHERE contactid = ?",
          @values
        );
      }
    }

    $tx->commit;
  };
  if ($@) {
    $tx->rollback;
    die "Profile update failed: $@";
  }
}


sub list_users ($self, $limit = 25, $offset = 0) {
  my $db = $self->database->db;
  if ('mysql' eq $self->config->{dbtype}) {
    return $db->query('SELECT * FROM snapusers ORDER BY id DESC LIMIT ? OFFSET ?', $limit, $offset)->hashes->to_array;
  } else {
    return $db->query('
      SELECT u.username, u.useruuid, u.activated, u.blocked, u.created,
             c.displayname
      FROM account.users u
      LEFT JOIN account.contacts c ON u.contactid = c.contactid
      ORDER BY u.userid DESC
      LIMIT ? OFFSET ?
    ', $limit, $offset)->hashes->to_array;
  }
}


sub count_users ($self) {
  my $db = $self->database->db;
  if ('mysql' eq $self->config->{dbtype}) {
    return $db->query('SELECT COUNT(*) AS count FROM snapusers')->hash->{count};
  } else {
    return $db->query('SELECT COUNT(*) AS count FROM account.users')->hash->{count};
  }
}


sub list_groups ($self, $limit = 25, $offset = 0) {
  my $db = $self->database->db;
  return $db->query('
    SELECT g.groupid, g.groupname,
           COUNT(ug.usergroupid) AS member_count
    FROM account.groups g
    LEFT JOIN account.usergroups ug ON g.groupid = ug.groupid
    GROUP BY g.groupid, g.groupname
    ORDER BY g.groupname
    LIMIT ? OFFSET ?
  ', $limit, $offset)->hashes->to_array;
}


sub count_groups ($self) {
  my $db = $self->database->db;
  return $db->query('SELECT COUNT(*) AS count FROM account.groups')->hash->{count};
}


sub get_group ($self, $groupid) {
  my $db = $self->database->db;
  return $db->query('
    SELECT g.groupid, g.groupname
    FROM account.groups g
    WHERE g.groupid = ?
  ', $groupid)->hash;
}


sub get_group_members ($self, $groupid) {
  my $db = $self->database->db;
  return $db->query('
    SELECT u.username, u.useruuid, c.displayname
    FROM account.usergroups ug
    JOIN account.users u ON ug.userid = u.userid
    LEFT JOIN account.contacts c ON u.contactid = c.contactid
    WHERE ug.groupid = ?
    ORDER BY u.username
  ', $groupid)->hashes->to_array;
}


sub save_group ($self, $groupid, $attribs) {
  my $db = $self->database->db;
  if ($groupid) {
    $db->update('account.groups', $attribs, { groupid => $groupid });
    return $groupid;
  } else {
    return $db->insert('account.groups', $attribs, { returning => 'groupid' })->hash->{groupid};
  }
}


sub get_presentation ($self, $userid, $languageid = 1) {
  my $db = $self->database->db;
  return $db->query(
    'SELECT p.presentationid, p.presentation, p.userid, p.languageid, l.code AS language_code
     FROM account.presentations p
     LEFT JOIN public.languages l ON p.languageid = l.languageid
     WHERE p.userid = ? AND p.languageid = ?',
    $userid, $languageid
  )->hash;
}


sub get_public_user ($self, $useruuid) {
  my $db = $self->database->db;
  return $db->query(
    'SELECT u.userid, u.username, u.useruuid, u.created,
            c.displayname, c.organization, c.city, c.website,
            co.cc AS country_cc, l.code AS language_code
     FROM account.users u
     LEFT JOIN account.contacts c ON u.contactid = c.contactid
     LEFT JOIN public.countries co ON c.countryid = co.countryid
     LEFT JOIN public.languages l ON c.languageid = l.languageid
     WHERE u.useruuid = ?::uuid AND u.activated = true AND u.blocked = false',
    $useruuid
  )->hash;
}


sub list_public_users ($self, $limit = 25, $offset = 0) {
  my $db = $self->database->db;
  return $db->query('
    SELECT u.userid, u.username, u.useruuid, u.created,
           c.displayname, c.organization, c.city,
           co.cc AS country_cc
    FROM account.users u
    LEFT JOIN account.contacts c ON u.contactid = c.contactid
    LEFT JOIN public.countries co ON c.countryid = co.countryid
    WHERE u.activated = true AND u.blocked = false
    ORDER BY u.created DESC
    LIMIT ? OFFSET ?
  ', $limit, $offset)->hashes->to_array;
}


sub count_public_users ($self) {
  my $db = $self->database->db;
  return $db->query(
    'SELECT COUNT(*) AS count FROM account.users WHERE activated = true AND blocked = false'
  )->hash->{count};
}


sub get_user_image ($self, $userid) {
  my $db = $self->database->db;
  return $db->query(
    'SELECT imageid, filename FROM account.images WHERE userid = ?',
    $userid
  )->hash;
}


1;