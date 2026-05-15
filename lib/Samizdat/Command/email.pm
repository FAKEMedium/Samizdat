package Samizdat::Command::email;

use Mojo::Base 'Mojolicious::Command', -signatures;
use Samizdat::Model::Email;

has description => 'Email management (domains, mailboxes, aliases)';
has usage => sub ($self) { $self->extract_usage };

sub run ($self, @args) {
  my $cmd = shift @args || '';
  my $action = shift @args || '';

  # Show help if no command
  unless ($cmd && $action) {
    print $self->usage;
    return;
  }

  # Initialize email model with 'system' user for CLI.
  # The Email model owns the postfixadmin DB connection via its `postfix` attr.
  my $email = Samizdat::Model::Email->new({
    config       => $self->app->config->{manager}->{email} || {},
    fallback_dsn => $self->app->config->{dsn}{pg},
  });
  $email->current_user('system');

  my $dispatch = {
    domain => {
      add    => sub { $self->domain_add($email, @args) },
      delete => sub { $self->domain_delete($email, @args) },
    },
    aliasdomain => {
      add    => sub { $self->aliasdomain_add($email, @args) },
      delete => sub { $self->aliasdomain_delete($email, @args) },
    },
    mailbox => {
      add    => sub { $self->mailbox_add($email, @args) },
      delete => sub { $self->mailbox_delete($email, @args) },
    },
    alias => {
      add    => sub { $self->alias_add($email, @args) },
      delete => sub { $self->alias_delete($email, @args) },
    },
  };

  if (exists $dispatch->{$cmd} && exists $dispatch->{$cmd}{$action}) {
    $dispatch->{$cmd}{$action}->();
  } else {
    print "Unknown command: $cmd $action\n\n";
    print $self->usage;
    exit 1;
  }
}

sub domain_add ($self, $email, @args) {
  my ($domain, $customerid) = @args;
  unless ($domain && defined $customerid) {
    print "Usage: samizdat email domain add <domain> <customerid>\n";
    exit 1;
  }

  eval {
    my $result = $email->create_domain({
      domain     => $domain,
      customerid => $customerid,
    });
    print "Domain '$domain' created (customer: $customerid)\n";
  };
  if ($@) {
    print "Error creating domain: $@\n";
    exit 1;
  }
}

sub domain_delete ($self, $email, @args) {
  my ($domain) = @args;
  unless ($domain) {
    print "Usage: samizdat email domain delete <domain>\n";
    exit 1;
  }

  eval {
    my $result = $email->delete_domain($domain);
    if ($result) {
      print "Domain '$domain' deleted\n";
    } else {
      print "Domain '$domain' not found\n";
      exit 1;
    }
  };
  if ($@) {
    print "Error deleting domain: $@\n";
    exit 1;
  }
}

sub aliasdomain_add ($self, $email, @args) {
  my ($alias_domain, $target_domain) = @args;
  unless ($alias_domain && $target_domain) {
    print "Usage: samizdat email aliasdomain add <alias_domain> <target_domain>\n";
    exit 1;
  }

  eval {
    # First ensure the alias domain exists in domain table
    my $existing = $email->find_domain($alias_domain);
    unless ($existing) {
      # Get customerid from target domain
      my $target = $email->find_domain($target_domain);
      unless ($target) {
        print "Target domain '$target_domain' not found\n";
        exit 1;
      }
      $email->create_domain({
        domain     => $alias_domain,
        customerid => $target->{customerid},
      });
    }

    # Create alias domain mapping
    my $result = $email->create_alias_domain({
      alias_domain  => $alias_domain,
      target_domain => $target_domain,
      active        => 1,
    });
    print "Alias domain '$alias_domain' -> '$target_domain' created\n";
  };
  if ($@) {
    print "Error creating alias domain: $@\n";
    exit 1;
  }
}

sub aliasdomain_delete ($self, $email, @args) {
  my ($alias_domain) = @args;
  unless ($alias_domain) {
    print "Usage: samizdat email aliasdomain delete <alias_domain>\n";
    exit 1;
  }

  eval {
    my $result = $email->delete_alias_domain($alias_domain);
    if ($result) {
      print "Alias domain '$alias_domain' deleted\n";
    } else {
      print "Alias domain '$alias_domain' not found\n";
      exit 1;
    }
  };
  if ($@) {
    print "Error deleting alias domain: $@\n";
    exit 1;
  }
}

sub mailbox_add ($self, $email, @args) {
  my ($address, $password, $name) = @args;
  unless ($address && $password) {
    print "Usage: samizdat email mailbox add <email> <password> [name]\n";
    exit 1;
  }

  eval {
    my $data = {
      username => $address,
      password => $password,
      active   => 1,
    };
    $data->{name} = $name if $name;

    my $result = $email->create_mailbox($data);

    # Also create alias for mailbox
    $email->create_alias({
      address => $address,
      goto    => $address,
      active  => 1,
    });

    print "Mailbox '$address' created\n";
  };
  if ($@) {
    print "Error creating mailbox: $@\n";
    exit 1;
  }
}

sub mailbox_delete ($self, $email, @args) {
  my ($address) = @args;
  unless ($address) {
    print "Usage: samizdat email mailbox delete <email>\n";
    exit 1;
  }

  eval {
    my $result = $email->delete_mailbox($address);
    if ($result) {
      print "Mailbox '$address' deleted\n";
    } else {
      print "Mailbox '$address' not found\n";
      exit 1;
    }
  };
  if ($@) {
    print "Error deleting mailbox: $@\n";
    exit 1;
  }
}

sub alias_add ($self, $email, @args) {
  my ($address, $goto) = @args;
  unless ($address && $goto) {
    print "Usage: samizdat email alias add <address> <goto>\n";
    exit 1;
  }

  eval {
    my $result = $email->create_alias({
      address => $address,
      goto    => $goto,
      active  => 1,
    });
    print "Alias '$address' -> '$goto' created\n";
  };
  if ($@) {
    print "Error creating alias: $@\n";
    exit 1;
  }
}

sub alias_delete ($self, $email, @args) {
  my ($address, $goto) = @args;
  unless ($address) {
    print "Usage: samizdat email alias delete <address> [goto]\n";
    print "       If goto is specified, only that target is removed.\n";
    print "       If goto is omitted, the entire alias is deleted.\n";
    exit 1;
  }

  eval {
    if ($goto) {
      # Remove specific goto from alias
      my $alias = $email->find_alias($address);
      unless ($alias) {
        print "Alias '$address' not found\n";
        exit 1;
      }

      my @gotos = split /,/, $alias->{goto};
      my @new_gotos = grep { $_ ne $goto } @gotos;

      if (@new_gotos == @gotos) {
        print "Target '$goto' not found in alias '$address'\n";
        exit 1;
      }

      if (@new_gotos == 0) {
        # No targets left, delete the alias
        $email->delete_alias($address);
        print "Alias '$address' deleted (no targets remaining)\n";
      } else {
        # Update with remaining targets
        $email->update_alias($address, { goto => join(',', @new_gotos) });
        print "Removed '$goto' from alias '$address'\n";
      }
    } else {
      # Delete entire alias
      my $result = $email->delete_alias($address);
      if ($result) {
        print "Alias '$address' deleted\n";
      } else {
        print "Alias '$address' not found\n";
        exit 1;
      }
    }
  };
  if ($@) {
    print "Error deleting alias: $@\n";
    exit 1;
  }
}

1;

=head1 SYNOPSIS

  Usage: samizdat email <command> <action> [arguments]

  Commands:

  Domain management:
    samizdat email domain add <domain> <customerid>
    samizdat email domain delete <domain>

  Alias domain management:
    samizdat email aliasdomain add <alias_domain> <target_domain>
    samizdat email aliasdomain delete <alias_domain>

  Mailbox management:
    samizdat email mailbox add <email> <password> [name]
    samizdat email mailbox delete <email>

  Alias management:
    samizdat email alias add <address> <goto>
    samizdat email alias delete <address> [goto]

  Examples:
    samizdat email domain add example.com 1234
    samizdat email aliasdomain add example.net example.com
    samizdat email mailbox add user@example.com secret123 'John Doe'
    samizdat email alias add info@example.com user@example.com
    samizdat email mailbox delete user@example.com
    samizdat email domain delete example.com

=cut
