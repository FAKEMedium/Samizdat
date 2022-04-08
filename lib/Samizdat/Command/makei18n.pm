package Samizdat::Command::makei18n;
use Mojo::Base 'Mojolicious::Command', -signatures;
use Mojo::Home;
use Locale::TextDomain::OO::Extract::Perl;
use Locale::TextDomain::OO::Extract::JavaScript;
use Locale::TextDomain::OO::Extract::Process;

my $lexicon = {};

has description => 'Managing updates of internationalization data.';
has usage => sub ($self) { $self->extract_usage };

sub run ($self, @args) {
  my $path;
  my $app = $self->app;

  my $pot = sprintf("# %s\n", 'Fake News - Samizdat');
  $pot .= sprintf("# %s\n", 'Copyright (C) 2022 Webmaster');
  $pot .= sprintf("# %s\n", 'This file is distributed under the same license as the Samizdat package.');
  $pot .= sprintf("# %s\n", 'Webmaster <webmaster@fakenews.com>, 2022.');
  $pot .= sprintf("#\n");
  $pot .= sprintf("%s\n", 'msgid ""');
  $pot .= sprintf("%s\n", 'msgstr ""');
  for my $header (qw(
    Project-Id-Version Report-Msgid-Bugs-To_name Report-Msgid-Bugs-To_address Last-Translator_name Last-Translator_address
    Language-Team_name Language-Team_address Language MIME-Version Content-Type charset Content-Transfer-Encoding
  )) {
    $pot .= sprintf("\"%s: %s\\n\"\n", $header, $app->{config}->{locale}->{$header});
  }

  my $extractor = Locale::TextDomain::OO::Extract::Perl->new(
    lexicon_ref => $lexicon,
    project     => $app->{config}->{locale}->{project},
    domain      => $app->{config}->{locale}->{textdomain},
    category    => $app->{config}->{locale}->{category},
  );

  # Extract from Perl files
  $path = Mojo::Home->new('lib/');
  $path->list_tree({dir => 0})->each(sub ($file, $num) {
    $extractor->clear;
    $extractor->filename($file->to_string);
    $extractor->content_ref( \( $file->slurp ) );
    $extractor->extract;
  });

  #  Extract from embedded Perl in templates
  $path = Mojo::Home->new('templates/');
  $path->list_tree({dir => 0})->each(sub ($file, $num) {
    $extractor->clear;
    $extractor->filename($file->to_string);
    $extractor->content_ref( \( $file->slurp ) );
    $extractor->extract;
  });

  $extractor = Locale::TextDomain::OO::Extract::JavaScript->new(
    lexicon_ref => $lexicon,
    project     => $app->{config}->{locale}->{project},
    domain      => $app->{config}->{locale}->{textdomain},
    category    => $app->{config}->{locale}->{category},
  );

  #  Extract from javascript files
  $path = Mojo::Home->new('public/js/');
  $path->list_tree({dir => 0})->each(sub ($file, $num) {
    if ('js' eq $file->extname) {
      $extractor->clear;
      $extractor->filename($file->to_string);
      $extractor->content_ref(\($file->slurp));
      $extractor->extract;
    }
  });

  for my $msgid (keys %{ $lexicon->{'i-default::'} } ) {
    if ($msgid) {
      $pot .= sprintf("\nmsgid \"%s\"\nmsgstr \"\"\n", $msgid);
    }
  }

  Mojo::Home->new(sprintf('locale/%s.pot', $app->{config}->{locale}->{textdomain}))->spurt($pot);

  my $skip = { };
  for my $language (@{ $app->{config}->{locale}->{skip_messages} }) {
    $skip->{$language} = 1;
  }
  for my $language (keys %{ $app->{config}->{locale}->{languages} }) {
    next if $skip->{lang};
    my $process = Locale::TextDomain::OO::Extract::Process->new(
      category    => $app->{config}->{locale}->{category},
      domain      => $app->{config}->{locale}->{textdomain},
      language    => $language,
      lexicon_ref => $lexicon,
      plugin_ref  => {
        po => 'PO',
        mo => 'MO',
      },
    );

    # Read existing po file
    $path = Mojo::Home->new(sprintf('locale/%s.po', $language));
    if (-f $path->to_string) {
      $process->language($language);
      $process->slurp(po => $path->to_string);

#      $process->remove_all_reference;
      $process->remove_all_automatic;

      $process->merge_extract({
        lexicon_ref => $lexicon,
      });

      # Write back po files
      $process->spew(po => $path->to_string);

      # Write mo files
      $process->spew(mo => sprintf('locale/%s/%s/%s.mo',
        $language, $app->{config}->{locale}->{category}, $app->{config}->{locale}->{textdomain}));
    }
  }
}

=head1 SYNOPSIS

  Usage: samizdat makei18n


=cut

1;