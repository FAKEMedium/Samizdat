package Samizdat::Command::makestatic;

use Mojo::Base 'Mojolicious::Command', -signatures;
use Data::Dumper;
use Mojo::UserAgent;

has description => 'Apply templates to markdown files and dump resulting files in the public dir';
has usage => sub ($self) { $self->extract_usage };

my $ua = Mojo::UserAgent->new;

sub run ($self, @args) {
  my $language = $ENV{'LANG'};
  $language = (split(':', $language))[0];
  $language = (split('_', $language))[0];

  $ua->cookie_jar->add(
    Mojo::Cookie::Response->new(
      name   => 'language',
      value  => $language,
      domain => $self->app->{config}->{cookiedomain},
      path   => '/'
    )
  );

  my $uris = $self->app->markdown->geturis;
  my $again = 1;
  my $siteurl = $self->app->{config}->{siteurl};
  $siteurl =~ s/\/$//;
  while ($again) {
    $again = 0;
    for my $uri (keys %$uris) {
      say $uri;
      my $language = '';
      if ($uri =~ s/_([^_\.]+)\.md/.md/) {
        $language = $1;
      }
      $uri =~ s/README\.md//;
      if (!$uris->{$uri}) {
        my $res = $ua->get(sprintf('%s/%s', ${$self->app->{config}->{hypnotoad}->{listen}}[0], $uri))->result;
        $uris->{uri} = 1;
        $res->dom('img, a')->each(sub($dom, $i) {
          my $link = '';
          if ('a' eq $dom->tag) {
            $link = $dom->attr('href');
          } elsif ('img' eq $dom->tag) {
            $link = $dom->attr('src');
          }
          $link =~ s/$siteurl//;
          if ($link !~ /http/) {
            if (!exists($uris->{$link})) {
              $uris->{$link} = 0;
              $again = 1;
            }
          }
        });
      }
    }
  };
}

=head1 SYNOPSIS

  Usage: samizdat makestatic


=cut

1;