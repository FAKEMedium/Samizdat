package Samizdat::Model::Settings;

# Layered, schema-validated configuration resolver.
#
# Phase 1 (operator only): effective config for a module is
#   package defaults (from its JSON Schema)  <-  platform (samizdat.yml manager.<module>)
# validated against the schema. The $ctx argument (always operator now) is the seam
# for the Phase 2 customer/site layers and per-key delegation ceilings.

use Mojo::Base -base, -signatures;
use YAML::XS qw(LoadFile);
use Hash::Merge;
use JSON::Validator;

has 'config';     # full app config hashref
has 'resolver';   # coderef: ($module, @rel) -> Mojo::File   (app->resource('settings', ...))
has 'log';        # optional Mojo::Log
has '_merge'    => sub { Hash::Merge->new('RIGHT_PRECEDENT') };  # second arg (platform) wins
has '_schemas'  => sub { {} };
has '_resolved' => sub { {} };

# The module's JSON Schema, or undef if it ships none.
sub schema ($self, $module) {
  return $self->_schemas->{$module} //= do {
    my $file = $self->resolver->($module, 'schema.yml');
    my $out;
    if (-f $file->to_string) {
      $out = eval { LoadFile($file->to_string) }
        // do { $self->_warn("settings($module): cannot load schema: $@"); undef };
    }
    $out // 0;   # 0 = "checked, none" (distinct from undef = not yet checked)
  } || undef;
}

# Effective config for a module.
sub resolve ($self, $module, $ctx = {}) {
  return $self->_resolved->{$module} if exists $self->_resolved->{$module};
  my $platform = $self->config->{manager}{$module} // {};
  my $schema   = $self->schema($module);
  my $merged;
  if ($schema) {
    my $defaults = $self->_defaults($schema) // {};
    $merged = $self->_merge->merge($defaults, $platform);   # platform overrides defaults
    $self->_validate($module, $schema, $merged);
  } else {
    $merged = $platform;   # no schema: pass the raw slice through unchanged
  }
  return $self->_resolved->{$module} = $merged;
}

# Single value; $key may be dotted (e.g. "oauth2.scope").
sub get ($self, $module, $key = undef, $ctx = {}) {
  my $cfg = $self->resolve($module, $ctx);
  return $cfg unless defined $key;
  my $v = $cfg;
  for my $part (split /\./, $key) {
    $v = ref $v eq 'HASH' ? $v->{$part} : undef;
    last unless defined $v;
  }
  return $v;
}

# Recursively collect `default` values from a schema's object properties.
sub _defaults ($self, $schema) {
  return undef unless ref $schema eq 'HASH';
  return $schema->{default} if exists $schema->{default};
  if (($schema->{type} // '') eq 'object' && ref $schema->{properties} eq 'HASH') {
    my %d;
    for my $k (keys %{ $schema->{properties} }) {
      my $v = $self->_defaults($schema->{properties}{$k});
      $d{$k} = $v if defined $v;
    }
    return %d ? \%d : undef;
  }
  return undef;
}

sub _validate ($self, $module, $schema, $data) {
  my @errors = eval { JSON::Validator->new->schema($schema)->validate($data) };
  return $self->_warn("settings($module): schema error: $@") if $@;
  $self->_warn(sprintf 'settings(%s): %s', $module, $_->to_string) for @errors;
}

sub _warn ($self, $msg) {
  $self->log ? $self->log->warn($msg) : warn "$msg\n";
}

1;
