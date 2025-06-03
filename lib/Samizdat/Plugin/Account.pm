package Samizdat::Plugin::Account;

use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Samizdat::Model::Account;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  $r->get('/users')->to(controller => 'Account', action => 'listusers')->name('listusers');
  $r->get('/user/:uuid')->to(controller => 'Account', action => 'user')->name('user');

  my $account = $r->under('/account');

  $account->get('/register')
    ->to(controller => 'Account', action => 'register', docpath => '/account/register/index.html')
    ->name('account_register');
  $account->post('/register')->to(controller => 'Account', action => 'register');
  $account->any([qw( GET PUT )] => '/confirm/:confirmationuuid')
    ->to(controller => 'Account', action => 'confirm', docpath => '/account/confirm/index.html')
    ->name('account_confirm');

  $account->any([qw( GET PUT )] => '/settings')
    ->to(controller => 'Account', action => 'settings')
    ->name('account_settings');
  $account->any([qw( GET PUT )] => '/password')
    ->to(controller => 'Account', action => 'password')
    ->name('account_password');

  $account->get('/login')
    ->to(controller => 'Account', action => 'login', docpath => => '/account/login/index.html')
    ->name('account_login');
  $account->post('/login')->to(controller => 'Account', action => 'login');

  $account->any([qw( GET POST DELETE )] => '/logout')->to(controller => 'Account', action => 'logout')->name('account_logout');
  $account->get('/')
    ->to(controller => 'Account', action => 'index')
    ->name('account_index');

  my $panel = $account->under('/panel')->to(controller => 'Account', action => 'authorize');
  $panel->get('/')
    ->to(controller => 'Account', action => 'panel', docpath => '/account/panel/index.html')
    ->name('account_panel');

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