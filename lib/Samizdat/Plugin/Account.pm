package Samizdat::Plugin::Account;

use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Samizdat::Model::Account;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  $r->get('/users')->name('listusers')->to(
    controller => 'Account',
    action => 'listusers',
  );
  $r->get('/user/:uuid')->name('user')->to(
    controller => 'Account',
    action => 'user',
  );

  my $account = $r->under('/account');
  my $panel = $account->under('/panel');
  $panel->get('/')->name('account_panel')->to(
    controller => 'Account',
    action => 'panel',
    docpath => '/account/panel/index.html'
  );

  $account->get('/register')->name('account_register')->to(
    controller => 'Account',
    action => 'register',
    docpath => '/account/register/index.html',
  );
  $account->post('/register')->to(controller => 'Account', action => 'register');
  $account->any([qw( GET PUT POST)] => '/confirm/:confirmationuuid')->name('account_confirm')->to(
    controller => 'Account',
    action => 'confirm',
    docpath => '/account/confirm/index.html',
  );

  $account->any([qw( GET POST )] => '/settings')->name('account_settings')->to(
    controller => 'Account',
    action => 'settings',
    docpath => '/account/settings/index.html',
  );
  $account->post('/upload-image')->name('account_upload_image')->to(
    controller => 'Account',
    action => 'upload_image'
  );
  $account->any([qw( GET PUT )] => '/password')->name('account_password')->to(
    controller => 'Account',
    action => 'password',
    docpath => '/account/password/index.html',
  );

  $account->get('/login')->name('account_login')->to(
    controller => 'Account',
    action => 'login',
    docpath => => '/account/login/index.html',
  );
  $account->post('/login')->to(controller => 'Account', action => 'login');

  $account->any([qw( GET POST DELETE )] => '/logout')->name('account_logout')->to(
    controller => 'Account',
    action => 'logout'
  );
  $account->get('/')->name('account_index')->to(
    controller => 'Account',
    action => 'index'
  );


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