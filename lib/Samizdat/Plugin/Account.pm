package Samizdat::Plugin::Account;

use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Samizdat::Model::Account;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  $r->get('/users')->to(controller => 'Account', action => 'listusers')->name('listusers');
  $r->get('/user/:uuid')->to(controller => 'Account', action => 'user')->name('user');

  my $account = $r->under('/account');

  $account->get('/register')->to(controller => 'Account', action => 'register')->name('account_register');
  $account->post('/register')->to(controller => 'Account', action => 'register');
  $account->get('/email/:secret')->to(controller => 'Account', action => 'confirm_email')->name('account_confirm_email');
  $account->put('/email/:secret')->to(controller => 'Account', action => 'confirm_email');

  $account->get('/settings')->to(controller => 'Account', action => 'settings')->name('account_settings');
  $account->put('/settings')->to(controller => 'Account', action => 'settings');
  $account->get('/password')->to(controller => 'Account', action => 'password')->name('account_password');
  $account->put('/password')->to(controller => 'Account', action => 'password');

  $account->get('/login')->to(controller => 'Account', action => 'login')->name('account_login');
  $account->post('/login')->to(controller => 'Account', action => 'login');

  $account->any([qw( GET POST DELETE )] => '/logout')->to(controller => 'Account', action => 'logout')->name('account_logout');
  $account->get('/')->to(controller => 'Account', action => 'index')->name('account_index');

  my $panel = $account->under('/panel')->to(controller => 'Account', action => 'authorize');
  $panel->get('/')->to(controller => 'Account', action => 'panel')->name('account_panel');

  $app->helper(account => sub ($self) {
    state $account = Samizdat::Model::Account->new({
      config       => $self->app->config->{account},
      database     => $self->app->pg,
      redis        => $self->app->redis,
    });
    return $account;
  });

}


1;