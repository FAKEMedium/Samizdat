use strict;
use warnings;
use ExtUtils::MakeMaker;
use File::Find;

# Samizdat core distribution. Ships the application modules AND the read-only
# resources tree (templates / settings / locale / migrations / public bundle) under
# lib/, Mojolicious-style, so they install into site_perl where the resolver finds
# them. EUMM only auto-detects .pm/.pod, so we build the PM map ourselves.
my %pm;
find(sub {
  return unless -f;
  return if /\.(bak|orig|rej|swp)$/;
  my $path = $File::Find::name;
  (my $rel = $path) =~ s{^lib/}{};
  $pm{$path} = "\$(INST_LIB)/$rel";
}, 'lib');

WriteMakefile(
  NAME             => 'Samizdat',
  VERSION          => '1.0.0',
  ABSTRACT         => 'A Mojolicious static-content hybrid generator with a hosting panel',
  AUTHOR           => 'Hans Svensson <hans@alipang.se>',
  LICENSE          => 'artistic_2',
  MIN_PERL_VERSION => '5.036',
  PM               => \%pm,
  EXE_FILES        => [ 'bin/samizdat', 'bin/makestatic' ],
  PREREQ_PM        => {
    'Mojolicious'                              => '9.0',
    'Mojo::Pg'                                 => 0,
    'Mojo::mysql'                              => 0,
    'Mojo::Redis'                              => 0,
    'Minion'                                   => 0,
    'Mojolicious::Plugin::OpenAPI'             => 0,
    'Mojolicious::Plugin::Mail'                => 0,
    'Mojolicious::Plugin::OAuth2'              => 0,
    'Mojolicious::Plugin::NotYAMLConfig'       => 0,
    'Mojolicious::Plugin::Util::RandomString'  => 0,
    'Mojolicious::Plugin::LocaleTextDomainOO'  => 0,
    'Locale::TextDomain::OO'                   => 0,
    'MojoX::MIME::Types'                        => 0,
    'JSON::Validator'                          => 0,
    'YAML::XS'                                 => 0,
    'Hash::Merge'                              => 0,
    'CryptX'                                   => 0,
    'Crypt::Argon2'                            => 0,
    'Crypt::PBKDF2'                            => 0,
    'Bytes::Random::Secure::Tiny'              => 0,
    'App::bmkpasswd'                           => 0,
    'Data::UUID'                               => 0,
    'UUID'                                     => 0,
    'DateTime'                                 => 0,
    'DateTime::TimeZone'                       => 0,
    'Date::Calc'                               => 0,
    'GD::SecurityImage'                        => 0,
    'Imager'                                   => 0,
    'IO::Compress::Brotli'                     => 0,
    'MIME::Lite'                               => 0,
    'Text::MultiMarkdown'                      => 0,
    'WWW::YouTube::Download'                   => 0,
  },
  TEST_REQUIRES => { 'Test::More' => 0, 'Test::Mojo' => 0 },
  META_MERGE    => {
    'meta-spec' => { version => 2 },
    no_index    => { directory => ['lib/Samizdat/resources'] },
    resources   => {
      repository => {
        type => 'git',
        url  => 'https://github.com/FAKEMedium/Samizdat.git',
        web  => 'https://github.com/FAKEMedium/Samizdat',
      },
      homepage => 'https://samizdat.foundation',
    },
  },
  dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' },
  clean => { FILES => 'Samizdat-*' },
);
