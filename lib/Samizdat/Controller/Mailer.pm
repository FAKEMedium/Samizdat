package Samizdat::Controller::Mailer;

use Mojo::Base 'Mojolicious::Controller', -signatures;

# Mails list
sub index ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0];

  if ($accept !~ /json/) {
    my $title = $self->app->__('Mailer');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'mailer/index', format => 'js');
    return $self->render(
      web      => $web,
      title    => $title,
      template => 'mailer/index',
      headline => 'mailer/chunks/headline',
      status   => 200
    );
  } else {
    return unless $self->access({ admin => 1 });

    my $page = int($self->param('page') // 1);
    my $per_page = int($self->param('per_page') // 25);
    my $status = $self->param('status') // '';

    my $params = {};
    $params->{where} = { status => $status } if $status;

    my $mails = $self->app->mailer->mails($params);
    my $total = scalar @$mails;

    my $offset = ($page - 1) * $per_page;
    my @all = @$mails;
    my @paginated = splice(@all, $offset, $per_page);

    return $self->render(json => {
      mails    => \@paginated,
      page     => $page,
      per_page => $per_page,
      total    => $total,
      pages    => int(($total + $per_page - 1) / $per_page) || 1,
    });
  }
}

# Single mail view
sub show ($self) {
  my $mailid = int($self->param('mailid') // 0);
  my $accept = $self->req->headers->{headers}->{accept}->[0];

  if ($accept !~ /json/) {
    $self->stash(docpath => '/mailer/mail/index.html');
    my $title = $self->app->__('Mail');
    my $web = { title => $title };
    $web->{sidebar} = $self->render_to_string(template => 'mailer/show/sidebar', format => 'html');
    $web->{script} .= $self->render_to_string(template => 'mailer/show/index', format => 'js');
    return $self->render(
      web      => $web,
      title    => $title,
      template => 'mailer/show/index',
      headline => 'mailer/chunks/headline',
      status   => 200
    );
  } else {
    return unless $self->access({ admin => 1 });

    my $mail = $self->app->mailer->mail_get($mailid);
    my $contents = $self->app->mailer->mail_contents($mailid);
    my $stats = $self->app->mailer->delivery_stats($mailid);

    for my $content (@$contents) {
      $content->{attachments} = $self->app->mailer->attachments($content->{contentid});
    }

    return $self->render(json => {
      mail     => $mail,
      contents => $contents,
      stats    => $stats,
    });
  }
}

# Edit mail (modal or full page)
sub edit ($self) {
  my $mailid = int($self->param('mailid') // 0);
  my $accept = $self->req->headers->{headers}->{accept}->[0];

  if ($accept !~ /json/) {
    my $title = $mailid ? $self->app->__('Edit mail') : $self->app->__('New mail');
    my $web = { title => $title };
    $self->stash(mailid => $mailid);
    $web->{script} .= $self->render_to_string(template => 'mailer/edit/index', format => 'js');
    # Use modal layout for AJAX requests, full layout for direct page visits
    my $is_ajax = $self->req->headers->header('X-Requested-With') // '';
    my $layout = ($is_ajax eq 'XMLHttpRequest') ? 'modal' : undef;
    return $self->render(web => $web, title => $title, template => 'mailer/edit/index', layout => $layout, status => 200);
  } else {
    return unless $self->access({ admin => 1 });

    my $mail = $mailid ? $self->app->mailer->mail_get($mailid) : {};
    my $contents = $mailid ? $self->app->mailer->mail_contents($mailid) : [];
    my $languages = $self->app->pg->db->select('public.languages', '*')->hashes;

    return $self->render(json => {
      mail      => $mail,
      contents  => $contents,
      languages => $languages,
    });
  }
}

# Create mail
sub create ($self) {
  return unless $self->access({ admin => 1 });

  my $json = $self->req->json // {};
  my $userid = $self->session('userid');
  my $customerid = $self->session('customerid');

  my $mail = $self->app->mailer->mail_create({
    name       => $json->{name},
    creator    => $userid,
    customerid => $customerid,
  });

  return $self->render(json => {
    success => 1,
    mail    => $mail,
    toast   => $self->app->__('Mail created'),
  }, status => 201);
}

# Update mail
sub update ($self) {
  return unless $self->access({ admin => 1 });

  my $mailid = int($self->param('mailid') // 0);
  my $json = $self->req->json // {};

  my $mail = $self->app->mailer->mail_update($mailid, $json);

  return $self->render(json => {
    success => 1,
    mail    => $mail,
    toast   => $self->app->__('Mail updated'),
  });
}

# Delete mail
sub delete ($self) {
  return unless $self->access({ admin => 1 });

  my $mailid = int($self->param('mailid') // 0);
  $self->app->mailer->mail_delete($mailid);

  return $self->render(json => {
    success => 1,
    toast   => $self->app->__('Mail deleted'),
  });
}

# Copy mail as draft
sub copy ($self) {
  return unless $self->access({ admin => 1 });

  my $mailid = int($self->param('mailid') // 0);
  my $json = $self->req->json // {};
  my $userid = $self->session('userid');

  my $mail = $self->app->mailer->mail_copy($mailid, {
    name    => $json->{name},
    creator => $userid,
  });

  return $self->render(json => {
    success => 1,
    mail    => $mail,
    toast   => $self->app->__('Mail copied as draft'),
  }, status => 201);
}

# Content management (localized content)
sub content_upsert ($self) {
  return unless $self->access({ admin => 1 });

  my $mailid = int($self->param('mailid') // 0);
  my $json = $self->req->json // {};

  my $content = $self->app->mailer->content_upsert({
    mailid     => $mailid,
    languageid => $json->{languageid},
    subject    => $json->{subject},
    body_md    => $json->{body_md},
  });

  return $self->render(json => {
    success => 1,
    content => $content,
    toast   => $self->app->__('Content saved'),
  });
}

# Lists
sub lists ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0];

  if ($accept !~ /json/) {
    my $title = $self->app->__('Lists');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'mailer/lists/index', format => 'js');
    return $self->render(
      web      => $web,
      title    => $title,
      template => 'mailer/lists/index',
      headline => 'mailer/chunks/headline',
      status   => 200
    );
  } else {
    return unless $self->access({ admin => 1 });

    my $lists = $self->app->mailer->lists;

    return $self->render(json => { lists => $lists });
  }
}

# Addresses list
sub addresses ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0];

  if ($accept !~ /json/) {
    my $title = $self->app->__('Addresses');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'mailer/addresses/index', format => 'js');
    return $self->render(
      web      => $web,
      title    => $title,
      template => 'mailer/addresses/index',
      headline => 'mailer/chunks/headline',
      status   => 200
    );
  } else {
    return unless $self->access({ admin => 1 });

    my $source = $self->param('source') // '';
    my $params = {};
    $params->{where} = { source => $source } if $source;

    my $addresses = $self->app->mailer->addresses($params);

    return $self->render(json => { addresses => $addresses });
  }
}

# Import addresses
sub addresses_import ($self) {
  return unless $self->access({ admin => 1 });

  my $json = $self->req->json // {};
  my $list = $json->{addresses} // [];
  my $source = $json->{source} // 'import';

  my $count = $self->app->mailer->address_import($list, $source);

  return $self->render(json => {
    success  => 1,
    imported => $count,
    toast    => sprintf($self->app->__('Imported %d addresses'), $count),
  }, status => 201);
}

# Delete address
sub address_delete ($self) {
  return unless $self->access({ admin => 1 });

  my $addressid = int($self->param('addressid') // 0);
  $self->app->mailer->address_delete($addressid);

  return $self->render(json => {
    success => 1,
    toast   => $self->app->__('Address deleted'),
  });
}

# Unsubscriptions list
sub unsubscriptions ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0];

  if ($accept !~ /json/) {
    my $title = $self->app->__('Unsubscriptions');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'mailer/unsubscriptions/index', format => 'js');
    return $self->render(
      web      => $web,
      title    => $title,
      template => 'mailer/unsubscriptions/index',
      headline => 'mailer/chunks/headline',
      status   => 200
    );
  } else {
    return unless $self->access({ admin => 1 });

    my $unsubscriptions = $self->app->mailer->unsubscriptions;

    return $self->render(json => { unsubscriptions => $unsubscriptions });
  }
}

# Unsubscribe form (enter email)
sub unsubscribe_form ($self) {
  my $customerid = int($self->param('c') // 0);
  my $title = $self->app->__('Unsubscribe');
  my $web = { title => $title };
  $self->stash(customerid => $customerid);
  $web->{script} .= $self->render_to_string(template => 'mailer/unsubscribe/form/index', format => 'js');
  return $self->render(web => $web, title => $title, template => 'mailer/unsubscribe/form/index', status => 200);
}

# Unsubscribe with magic token
sub unsubscribe ($self) {
  my $token = $self->param('token') // '';
  my $accept = $self->req->headers->{headers}->{accept}->[0];

  # Verify magic token
  my $verified = $self->app->mailer->verify_magic_token($token);
  return $self->reply->not_found unless $verified && $verified->{action} eq 'unsubscribe';

  my $private_id = $verified->{private_id};
  my $data = $self->app->mailer->privacy_data($private_id);
  return $self->reply->not_found unless $data->{address};

  if ($accept !~ /json/) {
    my $title = $self->app->__('Unsubscribe');
    my $web = { title => $title };
    $self->stash(token => $token, email => $data->{address}{email});
    $web->{script} .= $self->render_to_string(template => 'mailer/unsubscribe/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'mailer/unsubscribe/index', status => 200);
  } else {
    return $self->render(json => {
      success => 1,
      email   => $data->{address}{email},
    });
  }
}

# Request unsubscribe magic link
sub unsubscribe_request ($self) {
  my $json = $self->req->json // {};
  my $email = lc($json->{email} // '');
  my $customerid = int($json->{customerid} // 0);

  # Always return success to prevent email enumeration
  my $success_msg = $self->app->__('If this email is in our system, you will receive a link shortly.');

  return $self->render(json => { success => 0, error => 'Email required' }, status => 400) unless $email;

  my $address = $self->app->mailer->address_by_email_customer($email, $customerid);
  if ($address && $address->{private_id}) {
    my $token = $self->app->mailer->generate_magic_token($address->{private_id}, 'unsubscribe');
    my $url = $self->url_for('mailer_unsubscribe', token => $token)->to_abs;

    # TODO: Send email with magic link
    # For now, log it (in production, use Minion job to send)
    $self->app->log->info("Unsubscribe link for $email: $url");
  }

  return $self->render(json => {
    success => 1,
    toast   => $success_msg,
  });
}

# Confirm unsubscribe action
sub unsubscribe_confirm ($self) {
  my $json = $self->req->json // {};
  my $token = $json->{token};
  my $reason = $json->{reason} // 'unsubscribe';

  return $self->render(json => { success => 0, error => 'Token required' }, status => 400) unless $token;

  # Verify magic token
  my $verified = $self->app->mailer->verify_magic_token($token);
  return $self->render(json => { success => 0, error => 'Invalid or expired token' }, status => 400)
    unless $verified && $verified->{action} eq 'unsubscribe';

  my $data = $self->app->mailer->privacy_data($verified->{private_id});
  return $self->render(json => { success => 0, error => 'Address not found' }, status => 400)
    unless $data->{address};

  my $email = $data->{address}{email};

  # Check if already unsubscribed
  if ($self->app->mailer->is_unsubscribed($email)) {
    return $self->render(json => {
      success => 1,
      toast   => $self->app->__('You have been unsubscribed'),
    });
  }

  # Complete unsubscription
  $self->app->mailer->unsubscribe($email, $reason);

  return $self->render(json => {
    success => 1,
    toast   => $self->app->__('You have been unsubscribed'),
  });
}

# Privacy form (enter email)
sub privacy_form ($self) {
  my $customerid = int($self->param('c') // 0);
  my $title = $self->app->__('Your Data');
  my $web = { title => $title };
  $self->stash(customerid => $customerid);
  $web->{script} .= $self->render_to_string(template => 'mailer/privacy/form/index', format => 'js');
  return $self->render(web => $web, title => $title, template => 'mailer/privacy/form/index', status => 200);
}

# Request privacy magic link
sub privacy_request ($self) {
  my $json = $self->req->json // {};
  my $email = lc($json->{email} // '');
  my $customerid = int($json->{customerid} // 0);

  # Always return success to prevent email enumeration
  my $success_msg = $self->app->__('If this email is in our system, you will receive a link shortly.');

  return $self->render(json => { success => 0, error => 'Email required' }, status => 400) unless $email;

  my $address = $self->app->mailer->address_by_email_customer($email, $customerid);
  if ($address && $address->{private_id}) {
    my $token = $self->app->mailer->generate_magic_token($address->{private_id}, 'privacy');
    my $url = $self->url_for('mailer_privacy', private_id => $address->{private_id})->to_abs;
    $url .= '?t=' . $token;

    # TODO: Send email with magic link
    # For now, log it (in production, use Minion job to send)
    $self->app->log->info("Privacy link for $email: $url");
  }

  return $self->render(json => {
    success => 1,
    toast   => $success_msg,
  });
}

# Privacy self-service data view
sub privacy ($self) {
  my $private_id = $self->param('private_id') // '';
  my $token = $self->param('t') // '';
  my $accept = $self->req->headers->{headers}->{accept}->[0];

  # Validate UUID format
  return $self->reply->not_found unless $private_id =~ /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

  # Verify magic token if provided
  if ($token) {
    my $verified = $self->app->mailer->verify_magic_token($token);
    return $self->reply->not_found unless $verified && $verified->{action} eq 'privacy';
    return $self->reply->not_found unless $verified->{private_id} eq $private_id;
  }

  my $data = $self->app->mailer->privacy_data($private_id);
  return $self->reply->not_found unless $data->{address};

  if ($accept !~ /json/) {
    my $title = $self->app->__('Your Data');
    my $web = { title => $title };
    $self->stash(private_id => $private_id);
    $web->{script} .= $self->render_to_string(template => 'mailer/privacy/index', format => 'js');
    return $self->render(web => $web, title => $title, template => 'mailer/privacy/index', status => 200);
  } else {
    return $self->render(json => $data);
  }
}

# Privacy data deletion
sub privacy_delete ($self) {
  my $private_id = $self->param('private_id') // '';

  # Validate UUID format
  return $self->render(json => { success => 0, error => 'Invalid ID' }, status => 400)
    unless $private_id =~ /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

  my $result = $self->app->mailer->privacy_delete($private_id);

  return $self->render(json => {
    success => $result ? 1 : 0,
    toast   => $result ? $self->app->__('Your data has been deleted') : $self->app->__('Data not found'),
  }, status => $result ? 200 : 404);
}

# Queue mail for sending
sub queue ($self) {
  return unless $self->access({ admin => 1 });

  my $mailid = int($self->param('mailid') // 0);
  my $json = $self->req->json // {};

  my $result = $self->app->mailer->queue_mail($mailid, $json);

  my $status = $result->{success} ? 200 : 400;
  return $self->render(json => $result, status => $status);
}

# Delivery status
sub deliveries ($self) {
  return unless $self->access({ admin => 1 });

  my $mailid = int($self->param('mailid') // 0);
  my $deliveries = $self->app->mailer->deliveries($mailid);

  return $self->render(json => { deliveries => $deliveries });
}

# Delete unsubscription
sub unsubscription_delete ($self) {
  return unless $self->access({ admin => 1 });

  my $unsubscriptionid = int($self->param('unsubscriptionid') // 0);
  $self->app->mailer->unsubscription_delete($unsubscriptionid);

  return $self->render(json => {
    success => 1,
    toast   => $self->app->__('Unsubscription removed'),
  });
}

# Bounces list
sub bounces ($self) {
  my $accept = $self->req->headers->{headers}->{accept}->[0];

  if ($accept !~ /json/) {
    my $title = $self->app->__('Bounces');
    my $web = { title => $title };
    $web->{script} .= $self->render_to_string(template => 'mailer/bounces/index', format => 'js');
    return $self->render(
      web      => $web,
      title    => $title,
      template => 'mailer/bounces/index',
      headline => 'mailer/chunks/headline',
      status   => 200
    );
  } else {
    return unless $self->access({ admin => 1 });

    my $type = $self->param('type') // '';
    my $params = {};
    $params->{where} = { bounce_type => $type } if $type;

    my $bounces = $self->app->mailer->bounces($params);

    return $self->render(json => { bounces => $bounces });
  }
}

# Get single bounce
sub bounce ($self) {
  return unless $self->access({ admin => 1 });

  my $bounceid = int($self->param('bounceid') // 0);
  my $bounce = $self->app->mailer->bounce_get($bounceid);

  return $self->render(json => { bounce => $bounce });
}

# Delete bounce
sub bounce_delete ($self) {
  return unless $self->access({ admin => 1 });

  my $bounceid = int($self->param('bounceid') // 0);
  $self->app->mailer->bounce_delete($bounceid);

  return $self->render(json => {
    success => 1,
    toast   => $self->app->__('Bounce deleted'),
  });
}

# Search
sub search ($self) {
  return unless $self->access({ admin => 1 });

  my $q = $self->param('q') // '';
  my $type = $self->param('type') // 'mail';

  my $results = $self->app->mailer->search($q, $type);

  return $self->render(json => { results => $results, type => $type });
}

# Get bounces for a mail with removal suggestions
sub mail_bounces ($self) {
  return unless $self->access({ admin => 1 });

  my $mailid = int($self->param('mailid') // 0);
  my $bounces = $self->app->mailer->mail_bounces($mailid);

  return $self->render(json => { bounces => $bounces });
}

# Bulk remove addresses
sub addresses_bulk_delete ($self) {
  return unless $self->access({ admin => 1 });

  my $json = $self->req->json // {};
  my $addressids = $json->{addressids} // [];

  return $self->render(json => { success => 0, error => 'No addresses specified' }, status => 400)
    unless @$addressids;

  my $deleted = $self->app->mailer->addresses_bulk_delete($addressids);

  return $self->render(json => {
    success => 1,
    deleted => $deleted,
    toast   => sprintf($self->app->__('Removed %d addresses'), $deleted),
  });
}

# Get addresses suggested for removal
sub addresses_to_remove ($self) {
  return unless $self->access({ admin => 1 });

  my $addresses = $self->app->mailer->addresses_to_remove();

  return $self->render(json => { addresses => $addresses });
}

# Translate text using Anthropic API
sub translate ($self) {
  return unless $self->access({ admin => 1 });

  my $json = $self->req->json // {};
  my $text = $json->{text} // '';
  my $source_language = $json->{source_language} // '';
  my $target_language = $json->{target_language} // '';

  unless ($text) {
    return $self->render(json => { success => 0, error => 'No content to translate' }, status => 400);
  }

  unless ($target_language) {
    return $self->render(json => { success => 0, error => 'Target language required' }, status => 400);
  }

  # Get Anthropic config
  my $config = $self->config->{anthropic} // {};
  my $api_key = $config->{api_key} // $ENV{ANTHROPIC_API_KEY};
  my $model = $config->{model} // 'claude-sonnet-4-20250514';

  unless ($api_key) {
    return $self->render(json => { success => 0, error => 'Translation service not configured' }, status => 503);
  }

  # Build translation prompt
  my $source_hint = $source_language ? "from $source_language " : '';
  my $prompt = "Translate the following text ${source_hint}to $target_language. " .
               "Preserve any markdown formatting if present. " .
               "Return ONLY the translated text, no explanations.\n\n" .
               "Text to translate:\n$text";

  # Call Anthropic API
  my $ua = Mojo::UserAgent->new;
  $ua->transactor->name('Samizdat (see fakemedium.com)');

  my $tx = $ua->post('https://api.anthropic.com/v1/messages' => {
    'Content-Type' => 'application/json',
    'x-api-key' => $api_key,
    'anthropic-version' => '2023-06-01'
  } => json => {
    model => $model,
    max_tokens => 4096,
    messages => [
      { role => 'user', content => $prompt }
    ]
  });

  if ($tx->result->is_success) {
    my $response = $tx->result->json;
    if ($response->{content} && @{$response->{content}}) {
      my $translated = $response->{content}[0]{text};
      return $self->render(json => {
        success    => 1,
        translated => $translated,
      });
    }
  }

  my $error = $tx->result->json->{error}{message} // 'Translation failed';
  $self->render(json => { success => 0, error => $error }, status => 500);
}

# Config page (HTML)
sub configs_page ($self) {
  my $title = $self->app->__('Settings');
  my $web = { title => $title };
  $web->{script} .= $self->render_to_string(template => 'mailer/configs/index', format => 'js');
  return $self->render(
    web      => $web,
    title    => $title,
    template => 'mailer/configs/index',
    headline => 'mailer/chunks/headline',
    status   => 200
  );
}

# Config management (per-customer settings)
sub configs ($self) {
  return unless $self->access({ admin => 1 });

  my $customerid = int($self->param('customerid') // $self->session('customerid') // 0);
  my $configs = $self->app->mailer->configs($customerid);

  return $self->render(json => { configs => $configs, customerid => $customerid });
}

sub config_upsert ($self) {
  return unless $self->access({ admin => 1 });

  my $json = $self->req->json // {};
  my $customerid = int($json->{customerid} // $self->session('customerid') // 0);
  my $key = $json->{key} // '';
  my $value = $json->{value} // '';

  return $self->render(json => { success => 0, error => 'Key required' }, status => 400) unless $key;

  my $config = $self->app->mailer->config_set($customerid, $key, $value);

  return $self->render(json => {
    success => 1,
    config  => $config,
    toast   => $self->app->__('Setting saved'),
  });
}

sub config_delete ($self) {
  return unless $self->access({ admin => 1 });

  my $customerid = int($self->param('customerid') // $self->session('customerid') // 0);
  my $key = $self->param('key') // '';

  return $self->render(json => { success => 0, error => 'Key required' }, status => 400) unless $key;

  my $deleted = $self->app->mailer->config_delete($customerid, $key);

  return $self->render(json => {
    success => $deleted ? 1 : 0,
    toast   => $self->app->__('Setting deleted'),
  });
}

1;
