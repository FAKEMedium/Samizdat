package Samizdat::Command::makeimport;

use Mojo::Base 'Mojolicious::Command', -signatures;
use Mojo::Home;

use Data::Dumper;

has description => 'Imports users or documents from MODX.';
has usage => sub ($self) { $self->extract_usage };


sub run ($self, @args) {
  my $dbfrom = $self->app->mysql->db;
  my $dbto = $self->app->pg->db;
  $dbto->dbh->do('SET search_path TO account');
  my $prefix = $self->app->config->{import}->{prefix} // '';
  my $from = $self->app->config->{import}->{from} // '';
  my $users = sprintf("%susers", $prefix);
  my $attributes = sprintf("%suser_attributes", $prefix);
  my $select = '';
  if ($from eq 'modx') {
    $select = sprintf('SELECT u.*, a.* FROM %s u JOIN %s a ON u.id = a.internalKey WHERE active = 1 ORDER BY u.id ASC',
      $users, $attributes);
    $dbfrom->query($select)->hashes->each(sub($user, $num) {
      my $countryid = undef;
      if ($user->{country}) {
        $countryid = $dbto->select('public.countries', ['countryid'], {cc => $user->{country}})->hash->{$countryid} // undef;
      }
      my $stateid = undef;
      if ($user->{state} && $countryid) {
        $stateid = $dbto->select('public.states', ['stateid'], {code => $user->{state}, countryid => $countryid})->hash->{stateid} // undef;
      }
      my $givenname = undef;
      my $commonname = undef;
      if ($user->{fullname} =~ /^([^ ]+)/) {
        $givenname = $1;
      }
      if ($user->{fullname} =~ /^([^ ]+\s+(.+)$)/) {
        $commonname = $2;
      }
      my $passwordpbkdf2 = sprintf('{X-PBKDF2}HMACSHA1:AAAD6A:%s:%s', $user->{salt}, $user->{password});
      eval {
        my $tx = $dbto->begin;
        $dbto->query('INSERT INTO account.contacts (contactid, email, displayname) VALUES (?, ?, ?)',
          $user->{id}, $user->{email}, $user->{fullname}
        );
        $dbto->query('INSERT INTO account."users" (userid, contactid, username, activated, blocked, created) VALUES (?, ?, ?, ?, ?, to_timestamp(?))',
          $user->{id}, $user->{id}, $user->{username}, $user->{active}, $user->{blocked}, $user->{createdon}
        );
        $dbto->query('INSERT INTO account.passwords (userid, passwordpbkdf2) VALUES (?, ?)',
          $user->{id}, $passwordpbkdf2);
        $dbto->query('INSERT INTO account.presentations (userid) VALUES (?)',
          $user->{id});
        $dbto->query('UPDATE account.contacts SET address = ?, pc = ?, city = ?, telephone = ?, mobile = ?, website = ?, dob = to_timestamp(?) WHERE contacts.contactid = ?',
          $user->{address}, $user->{zip}, $user->{city}, $user->{phone}, $user->{mobilephone}, $user->{website},
          $user->{dob} != 0 ? $user->{dob} : undef,
          $user->{id}
        );
        $dbto->query('UPDATE account.contacts SET countryid = ?, stateid = ?, givenname = ?, commonname = ? WHERE contacts.contactid = ?',
          $countryid, $stateid, $givenname, $commonname, $user->{id});
        $tx->commit;
      };
      die $@ if $@;
    });
  }
}

=head1 SYNOPSIS

  Usage: samizdat makeimport [users|documents]


=cut

1;

__DATA__