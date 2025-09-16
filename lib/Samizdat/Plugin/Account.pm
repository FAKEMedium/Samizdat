package Samizdat::Plugin::Account;

use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Samizdat::Model::Account;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  my $users = $r->home('users')->to(controller => 'Account');
  $users->get('/:uuid')                                                ->to('#user')         ->name('user');
  $users->get('/')                                                     ->to('#listusers')    ->name('listusers');

  my $account = $r->home('account')->to(controller => 'Account');
  $account->get('panel')                                               ->to('#panel')        ->name('account_panel');
  $account->get('register')                                            ->to('#register')     ->name('account_register');
  $account->post('register')                                           ->to('#register');
  $account->any([qw( GET PUT POST)] => 'confirm/:confirmationuuid')    ->to('#confirm')      ->name('account_confirm');
  $account->any([qw( GET POST )] => 'settings')                        ->to('#settings')     ->name('account_settings');
  $account->any([qw( GET POST )] => 'upload-image')                    ->to('#upload_image') ->name('account_upload_image');
  $account->any([qw( GET PUT )] => 'password')                         ->to('#password')     ->name('account_password');
  $account->any([qw( GET POST DELETE )] => 'logout')                   ->to('#logout')       ->name('account_logout');
  $account->get('login')                                               ->to('#login')        ->name('account_login');
  $account->post('login')                                              ->to('#login');
  $account->get('/')                                                   ->to('#index')        ->name('account_index');

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