package Samizdat::Plugin::Email;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Email;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  # Email management routes
  my $manager = $r->manager('email')->to(controller => 'Email');
  $manager->get('/')->to('#index')->name('email_index');

  # Domain routes
  $manager->get('/domains')->to('#index', type => 'domains');
  $manager->any('/domains/:domain')->to('#domain')->name('email_domain');

  # Mailbox routes (nested under domains)
  $manager->get('/domains/:domain/mailboxes')->to('#index', type => 'mailboxes')->name('email_domain_mailboxes');
  $manager->any('/domains/:domain/mailboxes/:username')->to('#mailbox')->name('email_mailbox');

  # Alias routes
  $manager->get('/aliases')->to('#index', type => 'aliases');
  $manager->any('/aliases/:address')->to('#alias')->name('email_alias');

  # Quota routes
  $manager->get('/quotas')->to('#index', type => 'quotas');
  $manager->any('/quotas/:username')->to('#quota')->name('email_quota');

  # Customer-specific email routes
  my $customers = $r->manager('customers/:customerid/email')->to(controller => 'Email');
  $customers->get('/')->to('#index');
  $customers->get('/domains')->to('#index', type => 'domains');
  $customers->get('/mailboxes')->to('#index', type => 'mailboxes');
  $customers->get('/aliases')->to('#index', type => 'aliases');

  # Helper to access email model
  $app->helper(email => sub ($self) {
    state $email = Samizdat::Model::Email->new({
      config => $self->config->{manager}->{email} || {},
      pg     => $self->pg,
      mysql  => $self->mysql,
    });
    return $email;
  });
}

1;