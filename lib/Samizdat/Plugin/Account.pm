package Samizdat::Plugin::Account;

use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Samizdat::Model::Account;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  my $manager = $r->manager('users')->to(controller => 'Account');
  $manager->get('group')                                                 ->to('#group')      ->name('account_group');
  $manager->get('/')                                                     ->to('#listusers')  ->name('account_index');

  my $users = $r->home('users')->to(controller => 'Account');
  $users->get('/:uuid')                                                ->to('#presentation') ->name('account_presentation');
  $users->get('/')                                                     ->to('#listusers')    ->name('listusers');

  my $account = $r->home('account')->to(controller => 'Account');
  $account->get('register')                                            ->to('#register')     ->name('account_register');
  $account->post('register')                                           ->to('#register');
  $account->any([qw( GET PUT POST)] => 'confirm/:confirmationuuid')    ->to('#confirm')      ->name('account_confirm');
  $account->any([qw( GET POST )] => 'settings')                        ->to('#settings')     ->name('account_settings');
  $account->any([qw( GET POST )] => 'upload-image')                    ->to('#upload_image') ->name('account_upload_image');
  $account->any([qw( GET PUT )] => 'password')                         ->to('#password')     ->name('account_password');
  $account->any([qw( GET POST DELETE )] => 'logout')                   ->to('#logout')       ->name('account_logout');
  $account->get('login')                                               ->to('#login')        ->name('account_login');
  $account->post('login')                                              ->to('#login');
  $account->get('/')                                                   ->to('#index')        ->name('account_panel');


  $app->helper(account => sub ($self) {
    state $account = Samizdat::Model::Account->new({
      config       => $self->app->config->{manager}->{account},
      database     => $self->app->pg,
      redis        => $self->app->redis,
    });
    return $account;
  });


  # Grant access if any of the conditions in $require are met.
  # admins and superadmin are defined in configuration and bypass all other checks.
  # Always renders JSON error on access denial and returns 0
  # Returns 1 if access is granted
  $app->helper(access => sub ($self, $require = {
    userid => [],
    groupid => [],
    'valid-user' => 0,
    admin => 0,
    superadmin => 1
  })  {
    my $authcookie = $self->cookie($self->config->{manager}->{account}->{authcookiename});
    my $has_access = 0;

    if ($authcookie) {
      my $session = $self->app->account->session($authcookie);

      if ($session && %$session) {
        # Check superadmin from configuration
        if ($require->{superadmin}) {
          my $superadmins = $self->config->{manager}->{account}->{superadmins} // {};
          $has_access = 1 if exists $superadmins->{$session->{username}};
        }

        # Check admins from configuration
        if (!$has_access && $require->{admin}) {
          my $admins = $self->config->{manager}->{account}->{admins} // {};
          $has_access = 1 if exists $admins->{$session->{username}};

          # Also check if user is superadmin (superadmin implies admin)
          my $superadmins = $self->config->{manager}->{account}->{superadmins} // {};
          $has_access = 1 if exists $superadmins->{$session->{username}};
        }

        # Check if any valid authenticated user is allowed
        if (!$has_access && $require->{'valid-user'}) {
          $has_access = 1 if defined $session->{userid};
        }

        # Check specific userid requirements
        if (!$has_access && $require->{userid} && ref($require->{userid}) eq 'ARRAY') {
          for my $allowed_userid (@{$require->{userid}}) {
            if (defined $session->{userid} && $session->{userid} == $allowed_userid) {
              $has_access = 1;
              last;
            }
          }
        }

        # Check group membership
        if (!$has_access && $require->{groupid} && ref($require->{groupid}) eq 'ARRAY' && @{$require->{groupid}}) {
          # Groups are stored in session as colon-separated string
          my @user_groups = split(':', $session->{groups} // '');
          for my $allowed_groupid (@{$require->{groupid}}) {
            if (grep { $_ eq $allowed_groupid } @user_groups) {
              $has_access = 1;
              last;
            }
          }
        }
      }
    }

    # If access denied, always render JSON error
    unless ($has_access) {
      # Determine appropriate error message based on requirements
      my $error_msg;
      if ($require->{superadmin}) {
        $error_msg = $self->app->__('Superadmin access required');
      } elsif ($require->{admin}) {
        $error_msg = $self->app->__('Admin access required');
      } elsif ($require->{'valid-user'}) {
        $error_msg = $self->app->__('Authentication required');
      } else {
        $error_msg = $self->app->__('Access denied');
      }

      $self->render(json => { success => 0, error => $error_msg }, status => 401);
    }

    return $has_access;
  });
}


1;