package Samizdat::Plugin::Captcha;

# Locale-aware captcha plugin for Samizdat
# Based on Mojolicious::Plugin::Captcha by zar (Copyright 2014)
# Licensed under the same terms as Perl itself (Artistic License / GPL)

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use GD::SecurityImage;
use File::Spec::Functions 'catfile';

sub register ($self, $app, $conf) {
  my $config = $app->config->{captcha};
  my $session_name = $config->{session_name};

  # Add captcha route
  my $r = $app->routes;
  my $captcharoute = $config->{route} // '/captcha.png';
  $r->get($captcharoute)->to(controller => 'Captcha', action => 'index')->name('captcha_index');

  # Helper to create locale-aware captcha
  $app->helper(create_captcha => sub ($c) {
    my $language = $c->language || $c->config->{locale}->{default_language} || 'en';
    my $app_home = $c->app->home->to_string;

    # Get language-specific config, fall back to default
    my $lang_config = $config->{language}->{$language} || $config->{language}->{default};

    # Build font path
    my $font_path = catfile($app_home, $lang_config->{font});

    # Fall back to default if file doesn't exist
    unless (-f $font_path) {
      $lang_config = $config->{language}->{default};
      $font_path = catfile($app_home, $lang_config->{font});
    }

    # Get charset and process character ranges like 'A-Z'
    my $charset = $lang_config->{chars};
    $charset =~ s/([A-Z])-([A-Z])/join '', ($1 .. $2)/ge;

    # Create captcha with locale-specific settings
    my $image = GD::SecurityImage->new(
      rndmax     => $config->{length},
      rnd_data   => [ split //, $charset ],
      width      => $config->{width},
      height     => $config->{height},
      lines      => 20,
      font       => $font_path,
      ptsize     => $lang_config->{ptsize},
      scramble   => 1,
      bgcolor    => '#ffffff',
      frame      => 1,
      send_ctobg => 1,
    );

    $image->random();
    $image->create('ttf', 'ellipse', '#ff0000');
    $image->particle(500, 0);

    my ($image_data, undef, $random_string) = $image->out(force => 'png');

    # Store captcha string in session
    $c->session->{$session_name} = $random_string;

    return $image_data;
  });


  # Helper to validate captcha
  $app->helper(validate_captcha => sub ($c, $string, $case_sens = 0) {
    my $captcha_string = $c->session->{$session_name};
    return 0 unless defined $captcha_string;

    return $case_sens
      ? $string eq $captcha_string
      : uc($string) eq uc($captcha_string);
  });

}

1;

=head1 NAME

Samizdat::Plugin::Captcha - Locale-aware captcha plugin for Samizdat

=head1 DESCRIPTION

This plugin creates and validates locale-aware captcha images using GD::SecurityImage.
Based on Mojolicious::Plugin::Captcha by zar, extended to support multiple languages
with different fonts and character sets.

=head1 HELPERS

=head2 create_captcha

Creates a captcha image using locale-specific fonts and character sets based on
the user's language preference. Returns the image data.

=head2 validate_captcha

Validates a captcha string against the session value.

  $c->validate_captcha($string);           # case insensitive (default)
  $c->validate_captcha($string, 1);        # case sensitive

=head1 CONFIGURATION

Configure in samizdat.yml under the 'captcha' key with language-specific settings.

=head1 SEE ALSO

L<Mojolicious::Plugin::Captcha>, L<GD::SecurityImage>, L<Mojolicious::Plugin>

=head1 COPYRIGHT & LICENSE

Based on Mojolicious::Plugin::Captcha
Copyright 2014 zar. All rights reserved.

Modifications for Samizdat locale support
Copyright 2025 Samizdat contributors.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
