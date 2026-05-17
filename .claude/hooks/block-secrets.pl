#!/usr/bin/env perl
# PreToolUse hook: block Edit/Write/Read of secret-bearing files.
# Reads the hook JSON on stdin, inspects tool_input.file_path, and exits 2
# (blocking the tool call) when the path matches a sensitive pattern.
use strict;
use warnings;
use JSON::PP;

my $raw = do { local $/; <STDIN> } // '';
my $data = eval { decode_json($raw) } || {};
my $path = $data->{tool_input}{file_path}
        // $data->{tool_input}{path}
        // '';
exit 0 unless length $path;

# Match on the basename and the repo-relative tail so absolute paths still hit.
(my $base = $path) =~ s{.*/}{};

my @deny = (
  qr/\.key$/,                 # private keys (server.key, *.key)
  qr/\.p12$/,                 # PKCS#12 cert bundles (Swish, etc.)
  qr/\bserver\.key$/,
  qr/^samizdat\.yml$/,        # live config with all credentials
  qr/\.rc$/,                  # samizdat.rc, minion.rc (contain secrets)
  qr/_dump\.sql$/,            # DB dumps (samizdat_dump.sql)
  qr/^customerusers\.sql$/,   # customer data dump
  qr/EPP-PRIVATE\.md$/,       # untracked private impl notes
);

for my $re (@deny) {
  if ($base =~ $re || $path =~ $re) {
    print STDERR
      "BLOCKED: '$path' holds credentials or sensitive data and is off-limits "
      . "to Edit/Write/Read.\n"
      . "If you need a value from samizdat.yml (e.g. the pg DSN), extract just "
      . "that line via Bash grep instead of reading the whole file.\n";
    exit 2;
  }
}
exit 0;
