package Samizdat::Plugin::EPP;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::EPP;

sub register ($self, $app, $conf) {
  $app->helper(epp => sub ($self) {
    state $epp = Samizdat::Model::EPP->new({
      config  => $self->config->{domain}->{epp},
      pg      => $self->pg,
      mysql   => $self->mysql,
    });
    return $epp;
  });
}

1;