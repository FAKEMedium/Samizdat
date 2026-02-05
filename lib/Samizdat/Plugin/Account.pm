package Samizdat::Plugin::Account;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::Loader qw(data_section);

use Samizdat::Model::Account;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  # Store OpenAPI fragment (parsed centrally in _load_openapi)
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Account} = $openapi_yaml if $openapi_yaml;

  # Manager routes (HTML pages only - GET)
  my $manager = $r->manager('users')->to(controller => 'Account', admin_mode => 1);
  $manager->get('group/new')                                           ->to('#groupedit')    ->name('account_group_new');
  $manager->get('group/:groupid')                                      ->to('#groupedit')    ->name('account_group_edit');
  $manager->get('group')                                               ->to('#group')        ->name('account_group');
  $manager->get('new')                                                 ->to('#register')     ->name('account_new');
  $manager->get('/')                                                   ->to('#listusers')    ->name('account_index');

  # Public routes for user presentation and listing (HTML)
  my $users = $r->home('users')->to(controller => 'Account');
  $users->get('/:uuid')                                                ->to('#presentation') ->name('account_presentation');
  $users->get('/')                                                     ->to('#listusers')    ->name('listusers');

  # Registration and private account management routes (HTML pages - GET)
  my $account = $r->home('account')->to(controller => 'Account');
  $account->get('register')                                            ->to('#register')     ->name('account_register');
  $account->get('confirm/:confirmationuuid')                           ->to('#confirm')      ->name('account_confirm');
  $account->get('settings')                                            ->to('#settings')     ->name('account_settings');
  $account->get('upload-image')                                        ->to('#upload_image') ->name('account_upload_image');
  $account->get('password')                                            ->to('#password')     ->name('account_password');
  $account->get('logout')                                              ->to('#logout')       ->name('account_logout');
  $account->get('login')                                               ->to('#login')        ->name('account_login');
  $account->get('/')                                                   ->to('#index')        ->name('account_panel');

  # API routes are defined in OpenAPI spec (__DATA__ section)


  $app->helper(account => sub ($self) {
    state $model = Samizdat::Model::Account->new({
      config       => $self->app->config->{manager}->{account},
      database     => $self->app->pg,
      redis        => $self->app->redis,
    });
    return $model;
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

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for Account API
paths:
  /account/register:
    get:
      operationId: Account.register.get
      x-mojo-to: Account#register
      summary: Get registration form data
      tags: [Account]
      responses:
        '200':
          description: Form data including IP and admin mode
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Account_Result'
    post:
      operationId: Account.register
      x-mojo-to: Account#register
      summary: Register new user account
      tags: [Account]
      requestBody:
        content:
          application/x-www-form-urlencoded:
            schema:
              $ref: '#/components/schemas/Account_RegisterInput'
      responses:
        '200':
          description: Registration result
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Account_Result'

  /account/login:
    post:
      operationId: Account.login
      x-mojo-to: Account#login
      summary: Authenticate user
      tags: [Account]
      requestBody:
        content:
          application/x-www-form-urlencoded:
            schema:
              type: object
              properties:
                username:
                  type: string
                password:
                  type: string
      responses:
        '200':
          description: Login result
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Account_LoginResult'

  /account/logout:
    post:
      operationId: Account.logout
      x-mojo-to: Account#logout
      summary: End user session
      tags: [Account]
      responses:
        '200':
          description: Logout result
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Account_Result'
    delete:
      operationId: Account.logout.delete
      x-mojo-to: Account#logout
      summary: End user session
      tags: [Account]
      responses:
        '200':
          description: Logout result
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Account_Result'

  /account/confirm/{confirmationuuid}:
    post:
      operationId: Account.confirm
      x-mojo-to: Account#confirm
      summary: Confirm account registration
      tags: [Account]
      parameters:
        - name: confirmationuuid
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Confirmation result
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Account_Result'
    put:
      operationId: Account.confirm.put
      x-mojo-to: Account#confirm
      summary: Confirm account registration
      tags: [Account]
      parameters:
        - name: confirmationuuid
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Confirmation result
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Account_Result'

  /account/settings:
    get:
      operationId: Account.settings.get
      x-mojo-to: Account#settings
      summary: Get account settings
      tags: [Account]
      responses:
        '200':
          description: Settings data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Account_Result'
    post:
      operationId: Account.settings.update
      x-mojo-to: Account#settings
      summary: Update account settings
      tags: [Account]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Account_SettingsInput'
      responses:
        '200':
          description: Settings updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Account_Result'

  /account/password:
    put:
      operationId: Account.password.update
      x-mojo-to: Account#password
      summary: Change password
      tags: [Account]
      requestBody:
        content:
          application/x-www-form-urlencoded:
            schema:
              type: object
              properties:
                current_password:
                  type: string
                new_password:
                  type: string
                confirm_password:
                  type: string
      responses:
        '200':
          description: Password changed
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Account_Result'

  /account/upload-image:
    post:
      operationId: Account.uploadImage
      x-mojo-to: Account#upload_image
      summary: Upload profile image
      tags: [Account]
      requestBody:
        content:
          multipart/form-data:
            schema:
              type: object
              properties:
                image:
                  type: string
                  format: binary
      responses:
        '200':
          description: Image uploaded
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Account_Result'

  /users:
    get:
      operationId: Account.users.index
      x-mojo-to: Account#listusers
      summary: List users
      tags: [Account Admin]
      parameters:
        - name: searchterm
          in: query
          schema:
            type: string
      responses:
        '200':
          description: List of users
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Account_UserListResponse'
    post:
      operationId: Account.users.create
      x-mojo-to: Account#register
      summary: Create new user (admin)
      tags: [Account Admin]
      requestBody:
        content:
          application/x-www-form-urlencoded:
            schema:
              $ref: '#/components/schemas/Account_RegisterInput'
      responses:
        '200':
          description: User created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Account_Result'

  /users/group:
    get:
      operationId: Account.groups.index
      x-mojo-to: Account#group
      summary: List groups
      tags: [Account Admin]
      responses:
        '200':
          description: List of groups
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Account_GroupListResponse'
    post:
      operationId: Account.groups.create
      x-mojo-to: Account#groupedit
      summary: Create new group
      tags: [Account Admin]
      requestBody:
        content:
          application/x-www-form-urlencoded:
            schema:
              $ref: '#/components/schemas/Account_GroupInput'
      responses:
        '200':
          description: Group created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Account_Result'

  /users/group/{groupid}:
    get:
      operationId: Account.groups.get
      x-mojo-to: Account#groupedit
      summary: Get group details
      tags: [Account Admin]
      parameters:
        - name: groupid
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Group data
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Account_Group'
    put:
      operationId: Account.groups.update
      x-mojo-to: Account#groupedit
      summary: Update group
      tags: [Account Admin]
      parameters:
        - name: groupid
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/x-www-form-urlencoded:
            schema:
              $ref: '#/components/schemas/Account_GroupInput'
      responses:
        '200':
          description: Group updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Account_Result'

components:
  schemas:
    Account_User:
      type: object
      properties:
        userid:
          type: integer
        username:
          type: string
        email:
          type: string
        uuid:
          type: string
        givenname:
          type: string
        commonname:
          type: string
        displayname:
          type: string
        activated:
          type: boolean
        blocked:
          type: boolean
        created:
          type: string
          format: date-time
    Account_RegisterInput:
      type: object
      properties:
        username:
          type: string
        email:
          type: string
        password:
          type: string
        givenname:
          type: string
        commonname:
          type: string
    Account_SettingsInput:
      type: object
      properties:
        givenname:
          type: string
        commonname:
          type: string
        displayname:
          type: string
        email:
          type: string
    Account_Group:
      type: object
      properties:
        groupid:
          type: integer
        groupname:
          type: string
        description:
          type: string
    Account_GroupInput:
      type: object
      properties:
        groupname:
          type: string
        description:
          type: string
    Account_Result:
      type: object
      properties:
        success:
          type: boolean
        error:
          type: string
        message:
          type: string
    Account_LoginResult:
      type: object
      properties:
        success:
          type: boolean
        error:
          type: string
        user:
          $ref: '#/components/schemas/Account_User'
    Account_UserListResponse:
      type: object
      properties:
        users:
          type: array
          items:
            $ref: '#/components/schemas/Account_User'
    Account_GroupListResponse:
      type: object
      properties:
        groups:
          type: array
          items:
            $ref: '#/components/schemas/Account_Group'