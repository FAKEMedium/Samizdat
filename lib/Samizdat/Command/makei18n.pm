package Samizdat::Command::makei18n;

use Mojo::Base 'Mojolicious::Command', -signatures;
use Mojo::Home;
use Locale::TextDomain::OO::Extract::Perl;
use Locale::TextDomain::OO::Extract::JavaScript;
use Locale::TextDomain::OO::Extract::Process;

my $plurals = {
  zh => 'nplurals=1; plural=0;',
  ar => 'nplurals=6; plural=(n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 : n%100>=11 && n%100<=99 ? 4 : 5);',
  sv => 'nplurals=2; plural=(n != 1);',
  ru => 'nplurals=3; plural=(n==1 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2);',
  sr => 'nplurals=4; plural=n==1? 3 : n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2',
  be => 'nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2);',
  pl => 'nplurals=3; plural=(n==1 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2);',
};

my $lexicon = {};

has description => 'Managing updates of internationalization data.';
has usage => sub ($self) { $self->extract_usage };

sub run ($self, @args) {
  my $path;
  my $app = $self->app;
  my $year = '2022';

  my $pot = sprintf("# %s - %s\n", $app->{config}->{sitename}, $app->{config}->{locale}->{'Project-Id-Version'});
  $pot .= sprintf("# Copyright (C) %s %s\n", $year, $app->{config}->{locale}->{'Language-Team'});
  $pot .= sprintf("# %s\n",
    $app->__x('This file is distributed under the same license as the {project} package.',
      project => $app->{config}->{locale}->{project}
    )
  );
  $pot .= sprintf("# %s, %s.\n",
    $app->{config}->{locale}->{'Report-Msgid-Bugs-To'},
    $year
  );
  $pot .= sprintf("#\n");
  $pot .= sprintf("%s\n", 'msgid ""');
  $pot .= sprintf("%s\n", 'msgstr ""');
  for my $header (qw(
    Project-Id-Version Report-Msgid-Bugs-To Last-Translator PO-Revision-Date POT-Creation-Date
    Language-Team MIME-Version Content-Type Content-Transfer-Encoding Language
  )) {
    $pot .= sprintf("\"%s: %s\\n\"\n", $header, $app->{config}->{locale}->{$header});
  }

  my $extractor = Locale::TextDomain::OO::Extract::Perl->new(
    lexicon_ref => $lexicon,
    project     => $app->{config}->{locale}->{project},
    domain      => $app->{config}->{locale}->{textdomain},
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

  Mojo::Home->new(sprintf('locale/%s.pot', $app->{config}->{locale}->{textdomain}))->spew($pot);

  my $skip = { };
  for my $language (@{ $app->{config}->{locale}->{skip_messages} }) {
    $skip->{$language} = 1;
  }
  for my $language (sort {$a cmp $b} keys %{ $app->{config}->{locale}->{languages} }) {
    next if ($skip->{$language});
    my $process = Locale::TextDomain::OO::Extract::Process->new(
      domain      => $app->{config}->{locale}->{textdomain},
      language    => $language,
      lexicon_ref => $lexicon,
      plugin_ref  => {
        po => 'PO',
        mo => 'MO',
      },
    );

    # Make sure directory exists
    Mojo::Home->new(sprintf('locale/%s/', $language))->make_path({mode => 0755});

    $path = Mojo::Home->new(sprintf('locale/%s/%s.po',
      $language, $app->{config}->{locale}->{textdomain}));

    # Create initial po file if it dosn't exist
    if (!-f $path->to_string) {
      my $potcopy = $pot;
      my $search = '"Language: en\\n"';
      my $replace = sprintf("\"Language\: %s\\n\"\n", $language);
      $replace .= sprintf("\"Plural-Forms: %s\\n\"",
        exists($plurals->{$language}) ?
          $plurals->{$language} :
          'nplurals=2; plural=(n != 1);'
      );
      $potcopy =~ s /"Language: en\\n"/$replace/sm;
      say sprintf("Created %s", $path->to_string);
      $path->spew($potcopy);
    }

    # Read existing po file for the language
    $process->language($language);
    $process->slurp(po => $path->to_string);

    $process->remove_all_reference;
    $process->remove_all_automatic;

    $process->merge_extract({
      lexicon_ref => $lexicon,
    });

    # Write back po files
    $process->spew(po => $path->to_string);

    # Write mo files
    $process->spew(mo => sprintf('locale/%s/%s.mo',
      $language, $app->{config}->{locale}->{textdomain}));
  }
}

=head1 SYNOPSIS

  Usage: samizdat makei18n


=cut

1;