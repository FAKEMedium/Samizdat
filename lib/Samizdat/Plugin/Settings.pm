package Samizdat::Plugin::Settings;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Settings;

sub register ($self, $app, $conf) {
  # Core layered-config resolver. Loaded early so plugins can resolve their own
  # settings at register() time. See Samizdat::Model::Settings.
  $app->helper(settings => sub ($c) {
    state $model = Samizdat::Model::Settings->new(
      config   => $app->config,
      resolver => sub { $app->resource('settings', @_) },
      log      => $app->log,
    );
    return $model;
  });
}

1;
