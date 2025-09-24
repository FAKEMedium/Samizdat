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
  if ('mysql' eq $self->config->{databasetype}) {
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

  if ('mysql' eq $self->config->{databasetype}) {
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
        $attribs->{contactid} = $contactid;
        $userid = $db->insert('account.users',
          $attribs,
          { returning => 'userid' }
        )->hash->{userid};
        if ($userid =~ /^\d+$/) {
          $passwordid = $db->insert('account.passwords',
            { userid => $userid },
            { returning => 'passwordid' }
          )->hash->{passwordid};
        }
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
    
    if ('mysql' eq $self->config->{databasetype}) {
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
  if ('mysql' eq $self->config->{databasetype}) {
    return $db->select('snapemailconfirmations', '*', { confirmationuuid => $confirmationuuid })->hash;
  } else {
    return $db->select('account.emailconfirmationrequests', '*', { confirmationuuid => $confirmationuuid })->hash;
  }
}


sub deleteEmailConfirmationRequest ($self, $confirmationuuid) {
  my $db = $self->database->db;
  if ('mysql' eq $self->config->{databasetype}) {
    return $db->delete('snapemailconfirmations', { confirmationuuid => $confirmationuuid });
  } else {
    return $db->delete('account.emailconfirmationrequests', { confirmationuuid => $confirmationuuid });
  }
}


sub getUsers ($self, $where){
  my $db = $self->database->db;
  my $result;
  if ('mysql' eq $self->config->{databasetype}) {
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
  if ('mysql' eq $self->config->{databasetype}) {
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
  if ('mysql' eq $self->config->{databasetype}) {
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
  if ('mysql' eq $self->config->{databasetype}) {
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
  if ('mysql' eq $self->config->{databasetype}) {
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

  if ('mysql' eq $self->config->{databasetype}) {
    $db->update('passwords',
      $attribs,
      { userid => $userid },
      { returning => 'id' }
    )->hash->{id};
  } else {
    $db->update('account.passwords',
      $attribs,
      { 'passwords.userid' => $userid },
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
    if ('mysql' eq $self->config->{databasetype}) {
      $result = $db->select([ 'snapusers', [ -left => 'passwords', id => 'userid' ] ], 'passwords.*', {'snapusers.username' => $username})->hash;
    } else {
      $result = $db->select([ 'account.users', [ -left => 'account.passwords', 'passwords.userid' => 'users.userid' ] ],
        'passwords.*', {'users.username' => $username})->hash;
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
  if ('mysql' eq $self->config->{databasetype}) {
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
  if ('mysql' eq $self->config->{databasetype}) {
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
  if ('mysql' eq $self->config->{databasetype}) {
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

  # Get basic user info
  my $user;
  eval {
    $user = $db->query(
      'SELECT userid, username, displayname, email FROM account.users WHERE userid = ?',
      $userid
    )->hash;
  };

  if ($@ || !$user) {
    return {};
  }

  # Get contacts data
  my $contacts = {};
  eval {
    my $contact_data = $db->query(
      'SELECT * FROM account.contacts WHERE userid = ?',
      $userid
    )->hash;
    $contacts = $contact_data || {};
  };

  # Get presentations data (one per language)
  my $presentations = {};
  my $fallback_presentation = undef;
  eval {
    my $presentation_data = $db->query(
      'SELECT * FROM account.presentations WHERE userid = ?',
      $userid
    )->hashes;
    if ($presentation_data && @$presentation_data) {
      for my $pres (@$presentation_data) {
        # Index by language code for easy access
        if ($pres->{lang}) {
          $presentations->{$pres->{lang}} = $pres;
          # Keep first presentation as fallback for missing languages
          $fallback_presentation //= $pres;
        }
      }
    }
  };

  # Store fallback for use when a specific language variant is missing
  if ($fallback_presentation) {
    $presentations->{_fallback} = $fallback_presentation;
  }

  # Get images data
  my $images = {};
  eval {
    my $image_data = $db->query(
      'SELECT * FROM account.images WHERE userid = ?',
      $userid
    )->hashes;
    if ($image_data) {
      for my $img (@$image_data) {
        $images->{$img->{imageid}} = $img;
      }
    }
  };

  # Organize profile data by sections
  my $profile = {
    basic => {
      userid => $user->{userid},
      username => $user->{username},
      displayname => $user->{displayname} || '',
      email => $user->{email} || ''
    },
    contacts => $contacts,
    presentations => $presentations,
    images => $images
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
  
  eval {
    # Update basic user info if provided
    if (exists $profile_data->{basic}) {
      my $basic = $profile_data->{basic};
      my @updates;
      my @values;
      
      for my $field (qw(displayname email)) {
        if (defined $basic->{$field}) {
          push @updates, "$field = ?";
          push @values, $basic->{$field};
        }
      }
      
      if (@updates) {
        push @values, $userid;
        $db->query(
          "UPDATE account.users SET " . join(', ', @updates) . " WHERE userid = ?",
          @values
        );
      }
    }
    
    # Update contacts data
    if (exists $profile_data->{contacts}) {
      my $contacts = $profile_data->{contacts};
      # Check if contact record exists
      my $existing = $db->query('SELECT userid FROM account.contacts WHERE userid = ?', $userid)->hash;

      if ($existing) {
        # Update existing contact
        my @fields = grep { exists $contacts->{$_} } qw(phone mobile address city zip country);
        if (@fields) {
          my @updates = map { "$_ = ?" } @fields;
          my @values = map { $contacts->{$_} } @fields;
          push @values, $userid;
          $db->query(
            "UPDATE account.contacts SET " . join(', ', @updates) . " WHERE userid = ?",
            @values
          );
        }
      } elsif (keys %$contacts) {
        # Insert new contact record
        $contacts->{userid} = $userid;
        my @fields = keys %$contacts;
        my @placeholders = map { '?' } @fields;
        my @values = map { $contacts->{$_} } @fields;
        $db->query(
          "INSERT INTO account.contacts (" . join(', ', @fields) . ") VALUES (" . join(', ', @placeholders) . ")",
          @values
        );
      }
    }

    # Update presentations data (one per language)
    if (exists $profile_data->{presentations}) {
      my $presentations = $profile_data->{presentations};

      for my $lang (keys %$presentations) {
        my $pres_data = $presentations->{$lang};

        # Check if presentation exists for this user and language
        my $existing = $db->query(
          'SELECT presentationid FROM account.presentations WHERE userid = ? AND lang = ?',
          $userid, $lang
        )->hash;

        if ($existing) {
          # Update existing presentation
          my @fields = grep { exists $pres_data->{$_} && $_ ne 'presentationid' && $_ ne 'userid' && $_ ne 'lang' } keys %$pres_data;
          if (@fields) {
            my @updates = map { "$_ = ?" } @fields;
            my @values = map { $pres_data->{$_} } @fields;
            push @values, $userid, $lang;
            $db->query(
              "UPDATE account.presentations SET " . join(', ', @updates) . " WHERE userid = ? AND lang = ?",
              @values
            );
          }
        } elsif (keys %$pres_data) {
          # Insert new presentation
          $pres_data->{userid} = $userid;
          $pres_data->{lang} = $lang;
          my @fields = grep { defined $pres_data->{$_} } keys %$pres_data;
          my @placeholders = map { '?' } @fields;
          my @values = map { $pres_data->{$_} } @fields;
          $db->query(
            "INSERT INTO account.presentations (" . join(', ', @fields) . ") VALUES (" . join(', ', @placeholders) . ")",
            @values
          );
        }
      }
    }

    # TODO: Handle images table when its structure is known
    
    $tx->commit;
  };
  if ($@) {
    $tx->rollback;
    die "Profile update failed: $@";
  }
}

1;