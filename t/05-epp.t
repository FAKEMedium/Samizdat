use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::Util qw(secure_compare);

# Initialize test application
my $t = Test::Mojo->new('Samizdat');
my $app = $t->app;

# Check if EPP is configured for testing
my $epp_config = $app->config->{manager}->{domain}->{epp}->{test};
unless ($epp_config && ($epp_config->{remote_host} || $epp_config->{host})) {
    plan skip_all => 'EPP test configuration not available';
}

# Check if certificate files exist
if ($epp_config->{ssl_key} && !-f $epp_config->{ssl_key}) {
    plan skip_all => 'EPP SSL certificate files not found';
}
if ($epp_config->{ssl_cert} && !-f $epp_config->{ssl_cert}) {
    plan skip_all => 'EPP SSL certificate files not found';
}
if ($epp_config->{ssl_ca} && !-f $epp_config->{ssl_ca}) {
    plan skip_all => 'EPP SSL CA file not found';
}

# Helper to generate random strings
sub random_string {
    my $length = shift || 8;
    my @chars = ('a'..'z', '0'..'9');
    return join '', map { $chars[rand @chars] } 1..$length;
}

# Generate random test data
my $test_domain = 'test-' . random_string(12) . '.test';
my $test_domain2 = 'test-' . random_string(12) . '.test';
my $test_contact = 'TEST-' . uc(random_string(8));
my $test_contact2 = 'TEST-' . uc(random_string(8));
my $test_host = 'ns1.' . 'test-' . random_string(10) . '.test';
my $authcode;

# Create EPP client for testing
my $epp = $app->epp;
ok($epp, 'EPP helper available');
$epp->tld('TEST');

# Test 1: Configuration
subtest 'Configuration validation' => sub {
    ok($epp_config->{remote_host}, 'Remote host configured');
    ok($epp_config->{ports}, 'Ports configured');
    ok(ref($epp_config->{ports}) eq 'ARRAY', 'Ports is array');
    ok($epp_config->{username}, 'Username configured');
    ok($epp_config->{password}, 'Password configured');
    ok($epp_config->{ssl_key}, 'SSL key configured');
    ok($epp_config->{ssl_cert}, 'SSL cert configured');
    ok($epp_config->{ssl_ca}, 'SSL CA configured');
};

# Test 2: Module methods exist
subtest 'Module methods' => sub {
    can_ok($epp, qw(connect disconnect login logout));
    can_ok($epp, qw(domain_create domain_info domain_update domain_renew));
    can_ok($epp, qw(contact_create contact_info contact_update contact_delete));
    can_ok($epp, qw(host_create host_info host_delete));
    can_ok($epp, qw(add_ds_record remove_ds_record));
    can_ok($epp, qw(poll_message ack_message));
};

done_testing();

__END__

# The tests below are disabled as they perform real operations on the EPP test server
# and can take several minutes to complete. Enable them only when needed for integration testing.

# Test 3: Contact operations
subtest 'Contact operations' => sub {
    my $info = {};

    # Create contact
    my $contact_data = {
        name   => 'Test User ' . random_string(4),
        org    => 'Test Organization AB',
        street => "Test Street 123\nSuite 100",
        city   => 'Stockholm',
        pc     => '11122',
        cc     => 'SE',
        voice  => '+46.8123456',
        fax    => '+46.8123457',
        email  => 'test-' . random_string(8) . '@example.test',
        orgno  => '556677-8899',
        vatno  => 'SE556677889901',
    };

    ok($epp->contact_create($test_contact, $contact_data, $info),
        "Create contact: $test_contact");
    is($info->{result}->{code}, 1000, 'Contact creation successful');

    # Get contact info
    $info = {};
    ok($epp->contact_info($test_contact, $info),
        "Get contact info: $test_contact");
    is($info->{result}->{code}, 1000, 'Contact info successful');
    is($info->{id}, $test_contact, 'Contact ID matches');
    like($info->{email}, qr/\@example\.test/, 'Contact email retrieved');

    # Create second contact for later tests
    $contact_data->{email} = 'test-' . random_string(8) . '@example.test';
    $contact_data->{name} = 'Test User 2 ' . random_string(4);
    $info = {};
    ok($epp->contact_create($test_contact2, $contact_data, $info),
        "Create second contact: $test_contact2");

    # Update contact
    $contact_data->{name} = 'Updated Test User';
    $contact_data->{email} = 'updated-' . random_string(8) . '@example.test';
    $info = {};
    ok($epp->contact_update($test_contact, $contact_data, $info),
        "Update contact: $test_contact");
    is($info->{result}->{code}, 1000, 'Contact update successful');
};

# Test 4: Domain creation
subtest 'Domain creation' => sub {
    my $info = {
        customerid => 1,
        registrant => $test_contact,
        nameservers => ['ns1.example.test', 'ns2.example.test'],
    };

    ok($epp->domain_create($test_domain, 12, $info),
        "Create domain: $test_domain");
    is($info->{result}->{code}, 1000, 'Domain creation successful');
    like($info->{domainname}, qr/\.test$/, 'Domain name returned');
    ok($info->{expiry}, 'Expiry date returned');

    # Try to create duplicate domain (should fail)
    my $info2 = {
        customerid => 1,
        registrant => $test_contact,
    };
    ok(!$epp->domain_create($test_domain, 12, $info2),
        'Duplicate domain creation fails');
    is($info2->{result}->{code}, 2302, 'Object exists error code');
};

# Test 5: Domain info
subtest 'Domain info' => sub {
    my $info = {};

    ok($epp->domain_info($test_domain, $info),
        "Get domain info: $test_domain");
    is($info->{result}->{code}, 1000, 'Domain info successful');
    is($info->{domainname}, $test_domain, 'Domain name matches');
    is($info->{registrant}, $test_contact, 'Registrant matches');
    ok($info->{expiry}, 'Expiry date present');
    ok($info->{created}, 'Creation date present');
    is_deeply($info->{ns}, ['ns1.example.test', 'ns2.example.test'],
        'Nameservers match');

    # Query non-existent domain
    my $info2 = {};
    my $fake_domain = 'nonexistent-' . random_string(16) . '.test';
    ok(!$epp->domain_info($fake_domain, $info2),
        'Non-existent domain query fails');
    is($info2->{result}->{code}, 2303, 'Object does not exist error code');
};

# Test 6: Nameserver operations
subtest 'Nameserver operations' => sub {
    my $info = {};

    # Update nameservers
    my $new_ns = [
        'ns3.example.test',
        'ns4.example.test',
        'ns5.example.test'
    ];

    ok($epp->set_nameservers($test_domain, $new_ns, $info),
        "Update nameservers for: $test_domain");

    # Verify nameservers were updated
    $info = {};
    ok($epp->domain_info($test_domain, $info), 'Get updated domain info');
    is_deeply([sort @{$info->{ns}}], [sort @$new_ns],
        'Nameservers updated correctly');

    # Set back to original nameservers
    my $original_ns = ['ns1.example.test', 'ns2.example.test'];
    ok($epp->set_nameservers($test_domain, $original_ns, $info),
        'Restore original nameservers');
};

# Test 7: Domain update
subtest 'Domain update' => sub {
    my $info = {
        newregistrant => $test_contact2,
    };

    ok($epp->domain_update($test_domain, $info),
        "Update domain registrant: $test_domain");
    is($info->{result}->{code}, 1000, 'Domain update successful');

    # Verify registrant was updated
    $info = {};
    ok($epp->domain_info($test_domain, $info), 'Get updated domain info');
    is($info->{registrant}, $test_contact2, 'Registrant updated');

    # Update back to original registrant
    $info = { newregistrant => $test_contact };
    ok($epp->domain_update($test_domain, $info), 'Restore original registrant');
};

# Test 8: DNSSEC operations
subtest 'DNSSEC operations' => sub {
    my $info = {};

    # Add DS record
    my $keytag = int(rand(65535)) + 1;
    my $alg = 13;  # ECDSAP256SHA256
    my $digesttype = 2;  # SHA-256
    my $digest = sprintf('%064x', int(rand(2**256)));

    ok($epp->add_ds_record($test_domain, $keytag, $alg, $digesttype, $digest, $info),
        "Add DNSSEC DS record to: $test_domain");
    is($info->{result}->{code}, 1000, 'DS record addition successful');

    # Verify DS record exists
    $info = {};
    ok($epp->domain_info($test_domain, $info), 'Get domain info with DNSSEC');
    ok($info->{dsData}, 'DNSSEC data present');

    # Remove DS record
    $info = {};
    ok($epp->remove_ds_record($test_domain, $keytag, $alg, $digesttype, $digest, $info),
        "Remove DNSSEC DS record from: $test_domain");
    is($info->{result}->{code}, 1000, 'DS record removal successful');
};

# Test 9: Authorization code generation
subtest 'Authorization code' => sub {
    my $info = {};

    $authcode = $epp->generate_authcode($test_domain, $info);
    ok($authcode, "Generate authcode for: $test_domain");
    is($info->{result}->{code}, 1000, 'Authcode generation successful');
    like($authcode, qr/^[A-Za-z0-9]+$/, 'Authcode format valid');
};

# Test 10: Host operations
subtest 'Host operations' => sub {
    my $info = {};

    # Create host with glue records
    my $glue = ['192.0.2.1', '2001:db8::1'];

    ok($epp->host_create($test_host, $glue, $info),
        "Create host: $test_host");
    is($info->{result}->{code}, 1000, 'Host creation successful');

    # Get host info
    $info = {};
    ok($epp->host_info($test_host, $info),
        "Get host info: $test_host");
    is($info->{result}->{code}, 1000, 'Host info successful');
    is($info->{name}, $test_host, 'Host name matches');
    ok($info->{addr}, 'IP addresses present');
};

# Test 11: Domain renewal
subtest 'Domain renewal' => sub {
    my $info = {};

    # Get current expiry
    ok($epp->domain_info($test_domain, $info), 'Get current domain info');
    my $curexpiry = $info->{expiry};
    ok($curexpiry, 'Current expiry date available');

    # Renew domain
    $info = {};
    ok($epp->domain_renew($test_domain, $curexpiry, 12, $info),
        "Renew domain: $test_domain");
    is($info->{result}->{code}, 1000, 'Domain renewal successful');
    ok($info->{expiry}, 'New expiry date returned');
    isnt($info->{expiry}, $curexpiry, 'Expiry date extended');
};

# Test 12: Domain transfer (create domain for transfer)
subtest 'Domain transfer' => sub {
    my $info = {
        customerid => 1,
        registrant => $test_contact,
    };

    # Create second domain for transfer test
    ok($epp->domain_create($test_domain2, 12, $info),
        "Create domain for transfer: $test_domain2");

    # Generate authcode for transfer
    my $transfer_authcode = $epp->generate_authcode($test_domain2, $info);
    ok($transfer_authcode, "Generate authcode for transfer");

    # Note: Actual transfer would require different registrar credentials
    # We just test that the transfer command is accepted
    $info = {};
    my $result = $epp->domain_transfer($test_domain2, $transfer_authcode, $info);
    # Transfer might fail in test environment, but should not crash
    ok(defined($result), 'Transfer command executed');
};

# Test 13: Poll queue operations
subtest 'Poll operations' => sub {
    my $info = {};

    # Check poll queue
    my $count = $epp->poll_message($info);
    ok(defined($count), 'Poll message query executed');
    is($info->{result}->{code}, 1300, 'No messages in queue')
        if $count == 0;

    # If there are messages, acknowledge one
    if ($count > 0 && $info->{queue}->{id}) {
        my $msg_id = $info->{queue}->{id};
        $info = {};
        my $remaining = $epp->ack_message($msg_id, $info);
        ok(defined($remaining), 'Message acknowledged');
        is($info->{result}->{code}, 1000, 'Acknowledgment successful');
    }
};

# Test 14: Mark/unmark for deletion
subtest 'Mark for deletion operations' => sub {
    # Mark domain for deletion
    ok($epp->mark_for_deletion($test_domain),
        "Mark domain for deletion: $test_domain");

    # Check domain status
    my $info = {};
    ok($epp->domain_info($test_domain, $info), 'Get domain info after marking');
    ok($info->{clientdelete} || $info->{status} =~ /delete/i,
        'Domain marked for deletion');

    # Unmark domain
    ok($epp->unmark_for_deletion($test_domain),
        "Unmark domain for deletion: $test_domain");

    # Verify unmarked
    $info = {};
    ok($epp->domain_info($test_domain, $info), 'Get domain info after unmarking');
    ok(!$info->{clientdelete} || $info->{status} !~ /delete/i,
        'Domain unmarked for deletion');
};

# Test 15: Cleanup - Delete host
subtest 'Cleanup: Delete host' => sub {
    my $info = {};

    ok($epp->host_delete($test_host, $info),
        "Delete host: $test_host");
    is($info->{result}->{code}, 1000, 'Host deletion successful');
};

# Test 16: Configuration validation
subtest 'Configuration' => sub {
    ok($epp_config->{remote_host}, 'Remote host configured');
    ok($epp_config->{ports}, 'Ports configured');
    ok(ref($epp_config->{ports}) eq 'ARRAY', 'Ports is array');
    ok($epp_config->{host}, 'EPP server host configured');
    ok($epp_config->{username}, 'Username configured');
    ok($epp_config->{password}, 'Password configured');
    ok($epp_config->{ssl_key}, 'SSL key configured');
    ok($epp_config->{ssl_cert}, 'SSL cert configured');
    ok($epp_config->{ssl_ca}, 'SSL CA configured');
};

# Test 17: Round-robin tunnel selection
subtest 'Round-robin tunnel selection' => sub {
    my $ports = $epp_config->{ports};
    my @selected_ports;

    # Get tunnel several times and verify round-robin
    for (1..scalar(@$ports) * 2) {
        my $tunnel = $epp->_get_tunnel_connection();
        push @selected_ports, $tunnel->{port};
    }

    # Verify all ports were used
    my %used_ports = map { $_ => 1 } @selected_ports;
    for my $port (@$ports) {
        ok($used_ports{$port}, "Port $port was selected");
    }

    # Verify cycling pattern
    is($selected_ports[0], $selected_ports[scalar(@$ports)],
        'Round-robin cycles correctly');
};

# Test 18: Error handling
subtest 'Error handling' => sub {
    my $info = {};

    # Try to create domain without registrant
    my $bad_info = { customerid => 1 };
    eval {
        $epp->domain_create('bad-' . random_string(10) . '.test', 12, $bad_info);
    };
    ok($@, 'Missing registrant throws error');
    like($@, qr/registrant required/i, 'Correct error message');

    # Try to create domain without customerid
    $bad_info = { registrant => $test_contact };
    eval {
        $epp->domain_create('bad-' . random_string(10) . '.test', 12, $bad_info);
    };
    ok($@, 'Missing customerid throws error');
    like($@, qr/customerid required/i, 'Correct error message');
};

# Test 19: Logout and disconnect
subtest 'Logout and disconnect' => sub {
    ok($epp->logout(), 'Logout from EPP server');
    ok($epp->disconnect(), 'Disconnect from EPP server');
    ok(!$epp->connected, 'Connection closed');
};

# Test 20: Reconnection
subtest 'Reconnection' => sub {
    ok($epp->connect(), 'Reconnect to EPP server');
    ok($epp->connected, 'Reconnected successfully');
    ok($epp->login(), 'Login after reconnection');
    ok($epp->logout(), 'Logout after reconnection');
    ok($epp->disconnect(), 'Disconnect after reconnection');
};

done_testing();
