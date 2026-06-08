package Samizdat::Command::makei18n;

use Mojo::Base 'Mojolicious::Command', -signatures;
use Mojo::Home;
use Mojo::File qw(tempfile);
use Locale::TextDomain::OO::Extract::Perl;
use Locale::TextDomain::OO::Extract::JavaScript;
use Encode qw(encode);

my $plurals = {
  zh => 'nplurals=1; plural=0;',
  ar => 'nplurals=6; plural=(n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 : n%100>=11 && n%100<=99 ? 4 : 5);',
  sv => 'nplurals=2; plural=(n != 1);',
  ru => 'nplurals=3; plural=(n==1 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2);',
  sr => 'nplurals=4; plural=n==1? 3 : n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2',
  be => 'nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2);',
  pl => 'nplurals=3; plural=(n==1 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2);',
};

# Core dist owns the framework, core plugins, shared layouts/chunks and bundle JS.
# Everything else gets its own per-module textdomain so each plugin dist ships
# its own translations (merged flat at runtime; see lib/Samizdat.pm).
my %CORE = map { $_ => 1 } qw(Account Customer Web Cache Public Icons Manager Captcha Shortbytes);
my %PLUGIN;  # lc plugin names (populated in run); non-plugin template dirs fold into core

has description => 'Rebuild per-module i18n (.pot/.po/.mo) under resources/locale/<module>/.';
has usage => sub ($self) { $self->extract_usage };

sub _po_escape ($s) {
  $s =~ s/\\/\\\\/g;
  $s =~ s/"/\\"/g;
  $s =~ s/\n/\\n/g;
  $s =~ s/\t/\\t/g;
  return $s;
}

# Which module a source file belongs to.
sub _module_of ($file) {
  if ($file =~ m{/Samizdat/(?:Plugin|Controller|Model|Command)/([A-Za-z0-9]+)}) {
    return $CORE{$1} ? 'core' : lc $1;
  }
  if ($file =~ m{/resources/templates/([^/]+)/}) {
    my $d = $1;
    return 'core' if $d eq 'layouts' || $d eq 'chunks' || $CORE{ucfirst $d};
    return $PLUGIN{$d} ? $d : 'core';
  }
  return 'core';  # Samizdat.pm, bundle JS, anything else
}

sub run ($self, @args) {
  my $app = $self->app;
  my $loc = $app->{config}->{locale};
  my $td  = $loc->{textdomain};

  my %skip = map { $_ => 1 } @{ $loc->{skip_messages} // [] };
  my @languages = grep { !$skip{$_} } sort keys %{ $loc->{languages} };

  %PLUGIN = map { lc(($_->basename =~ s/\.pm$//r)) => 1 }
    @{ $app->home->child('lib', 'Samizdat', 'Plugin')->list->to_array };

  my $localebase = $app->resource('locale');     # lib/Samizdat/resources/locale
  my $legacy     = $app->home->child('locale');  # old single-domain tree (first-time seed)

  # 1. Extract msgids per file, bucketed by module.
  my %modmsg;  # module => { msgid => 1 }
  my $extract = sub ($file, $class) {
    my $lex = {};
    my $ex  = $class->new(lexicon_ref => $lex, project => $loc->{project}, domain => $td);
    $ex->clear;
    $ex->filename($file->to_string);
    $ex->content_ref(\($file->slurp));
    eval { $ex->extract; 1 } or do { warn "extract failed for $file: $@"; return };
    my $module = _module_of($file->to_string);
    $modmsg{$module}{$_} = 1 for grep { length } keys %{ $lex->{'i-default::'} // {} };
  };

  # Perl modules
  $app->home->child('lib')->list_tree({dir => 0})->each(sub ($f, $n) {
    $extract->($f, 'Locale::TextDomain::OO::Extract::Perl') if $f =~ /\.(pm|pl)$/;
  });
  # Embedded Perl in templates
  $app->resource('templates')->list_tree({dir => 0})->each(sub ($f, $n) {
    $extract->($f, 'Locale::TextDomain::OO::Extract::Perl');
  });
  # Bundle JavaScript -> core
  my $jsdir = $app->datadir->child('js');
  if (-d $jsdir->to_string) {
    $jsdir->list_tree({dir => 0})->each(sub ($f, $n) {
      $extract->($f, 'Locale::TextDomain::OO::Extract::JavaScript') if 'js' eq $f->extname;
    });
  }

  # 2. Per module: write .pot, seed translations from the merged/legacy .po, compile .mo.
  for my $module (sort keys %modmsg) {
    my $moddir = $localebase->child($module);
    $moddir->make_path;

    my $pot = sprintf("# %s translations for the %s module\n", $app->{config}->{sitename}, $module)
            . "msgid \"\"\nmsgstr \"\"\n"
            . "\"MIME-Version: 1.0\\n\"\n"
            . "\"Content-Type: text/plain; charset=UTF-8\\n\"\n"
            . "\"Content-Transfer-Encoding: 8bit\\n\"\n";
    $pot .= sprintf("\nmsgid \"%s\"\nmsgstr \"\"\n", _po_escape($_))
      for sort keys %{ $modmsg{$module} };
    my $potfile = $moddir->child("$module.pot");
    $potfile->spew(encode('UTF-8', $pot));

    for my $lang (@languages) {
      my $langdir = $moddir->child($lang);
      $langdir->make_path;
      my $pofile = $langdir->child("$module.po");

      # Seed source: this module's existing .po, else the legacy merged .po.
      my $seed = -f $pofile->to_string ? $pofile->to_string
               : $legacy->child($lang, "$td.po")->to_string;

      if (-f $seed) {
        my $tmp = tempfile;
        # Pull translations for this module's msgids from the seed; drop the rest.
        system('msgmerge', '--quiet', '--no-fuzzy-matching', '--no-wrap',
          '-o', $tmp->to_string, $seed, $potfile->to_string) == 0
          or die "msgmerge failed for $module/$lang\n";
        system('msgattrib', '--no-obsolete', '--no-wrap',
          '-o', $pofile->to_string, $tmp->to_string) == 0
          or die "msgattrib failed for $module/$lang\n";
      } else {
        # No seed yet: start from the .pot with a Language header.
        my $hdr = sprintf("\"Language: %s\\n\"\n\"Plural-Forms: %s\\n\"\n",
          $lang, $plurals->{$lang} // 'nplurals=2; plural=(n != 1);');
        (my $po = $pot) =~ s/("Content-Transfer-Encoding: 8bit\\n"\n)/$1$hdr/;
        $pofile->spew(encode('UTF-8', $po));
      }
    }
    say sprintf("%-16s %d strings -> %s", $module, scalar keys %{ $modmsg{$module} }, $moddir->to_string);
  }

  # Merged runtime catalog per language: msgcat every module's .po into one .mo
  # that the app loads flat (LTOO overwrites rather than merges multiple files, so
  # we hand it a single pre-merged file per language). Per-module .po stay the
  # owned source; for multi-dist installs this merge step moves to deploy time.
  for my $lang (@languages) {
    my @pos = grep { -f } map { $localebase->child($_, $lang, "$_.po")->to_string } sort keys %modmsg;
    next unless @pos;
    my $merged = tempfile;
    system('msgcat', '--use-first', '--no-wrap', '-o', $merged->to_string, @pos) == 0
      or die "msgcat failed for $lang\n";
    system('msgfmt', '-o', $localebase->child("$lang.mo")->to_string, $merged->to_string) == 0
      or die "msgfmt(merged) failed for $lang\n";
  }
}

=head1 SYNOPSIS

  Usage: samizdat makei18n

Rebuilds per-module gettext catalogs under
C<lib/Samizdat/resources/locale/E<lt>moduleE<gt>/E<lt>langE<gt>/E<lt>moduleE<gt>.{po,mo}>.
On first run, translations are seeded from the legacy single-domain
C<locale/E<lt>langE<gt>/E<lt>textdomainE<gt>.po> tree; afterwards each module's own
C<.po> is the source of truth.

=cut

1;
