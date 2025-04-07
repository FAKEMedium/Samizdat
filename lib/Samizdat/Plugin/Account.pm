package Samizdat::Plugin::Account;

use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Samizdat::Model::Account;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  $r->get('/register')->to(controller => 'Account', action => 'register')->name('register_account');
  $r->post('/register')->to(controller => 'Account', action => 'register')->name('create_account');
  $r->get('/register/:secret')->to(controller => 'Account', action => 'confirm_email')->name('confirm_email');
  $r->put('/register/:secret')->to(controller => 'Account', action => 'confirm_email')->name('confirm_email');

  $r->put('/account')->to(controller => 'Account', action => 'register')->name('update_account');
  $r->get('/account/password')->to(controller => 'Account', action => 'password')->name('password');
  $r->put('/account/password')->to(controller => 'Account', action => 'password')->name('update_password');

  $r->get('/login')->to(controller => 'Account', action => 'login')->name('login_form');
  $r->post('/login')->to(controller => 'Account', action => 'login')->name('login');

  $r->any([qw( GET POST DELETE )] => '/logout')->to(controller => 'Account', action => 'logout')->name('logout');
  $r->get('/users')->to(controller => 'Account', action => 'listusers')->name('listusers');
  $r->get('/user/:uuid')->to(controller => 'Account', action => 'user')->name('user');

  my $panel = $r->under('panel')->to(controller => 'Account', action => 'authorize');
  $panel->get('/panel')->to(controller => 'Account', action => 'panel');

  $app->helper(account => sub ($self) {
    state $account = Samizdat::Model::Account->new({
      config       => $self->app->config->{account},
      database     => $self->app->pg,
      redis        => $self->app->redis
    });
    return $account
  });

}


1;