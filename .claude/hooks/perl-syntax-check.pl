#!/usr/bin/env perl
# PostToolUse hook: run `perl -c` on edited Perl sources.
# Catches syntax/compile errors immediately since the repo has no CI.
# Exits 2 with the compiler output on stderr so Claude can fix it.
use strict;
use warnings;
use JSON::PP;

my $raw = do { local $/; <STDIN> } // '';
my $data = eval { decode_json($raw) } || {};
my $path = $data->{tool_input}{file_path}
        // $data->{tool_input}{path}
        // '';
exit 0 unless length $path;

# Only Perl sources: modules, tests, the app/command entrypoints.
exit 0 unless $path =~ /\.(pm|pl|t)$/ || $path =~ m{/bin/samizdat$};
exit 0 unless -f $path;

my $project = $ENV{CLAUDE_PROJECT_DIR} || '.';
my $lib = "$project/lib";

my $out = qx{perl -c -I"$lib" "$path" 2>&1};
my $rc  = $? >> 8;

if ($rc != 0) {
  print STDERR "perl -c failed for $path:\n$out\n";
  exit 2;
}
exit 0;
