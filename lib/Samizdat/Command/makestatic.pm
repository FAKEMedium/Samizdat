package Samizdat::Command::makestatic;

use Mojo::Base 'Mojolicious::Command', -signatures;
use Mojo::UserAgent;
use Time::HiRes qw(usleep);
use Mojo::Util qw(decode encode);
use Data::Dumper;

has description => 'Apply templates to markdown files and dump resulting files in the public dir';
has usage => sub ($self) { $self->extract_usage };

my $ua = Mojo::UserAgent->new;

sub run ($self, @args) {
  my $language = $ENV{'LANG'} // $self->app->config->{locale}->{default_language} // 'en_US.UTF-8';
  $language = (split(':', $language))[0];
  $language = (split('_', $language))[0];


  my $uris = $self->app->web->geturis;
  my $again = 1;
  my $siteurl = $self->app->config->{siteurl};
  $siteurl =~ s/\/$//;
  my $server = ${ $self->app->config->{hypnotoad}->{listen} }[0];
  $server =~ s/\?.*//;
  while ($again) {
    $again = 0;
    for my $uri (sort {$a cmp $b} keys %$uris) {
      next if ($uri =~ /^#/);
      next if ($uri =~ /\.(jpg|jpeg|png|ico|pdf|gif|svg|mp4|webp)/);
      next if ($uri =~ /^\/\//);
      next if ($uri =~ /^mailto/);
      next if ($uri =~ /^javascript/);
      next if ($uri =~ /^country/);

#      my $language = $self->app->config->{locale}->{default_language};
      $ua->cookie_jar->empty;
      $ua->cookie_jar->add(
        Mojo::Cookie::Response->new(
          name   => 'language',
          value  => $language,
          domain => $self->app->config->{account}->{cookiedomain},
          path   => '/'
        )
      );
      $uri =~ s/README\.md//;
      $uri =~ s/^\///g;
      $uri =~ s/^\.\///g;
      if (!$uris->{$uri}) {
        my $res = $ua->get(sprintf('%s/%s', $server, $uri))->result;
        say sprintf('%s/%s %3d', $server, $uri, $res->code);

        if (0 && $uri !~ /\.(png|jpg|jpeg|gif|webp|mp3|svg|pdf|css|js)$/) {
          for my $language (keys %{$self->app->config->{locale}->{languages}}) {
            next if ($language eq $self->app->config->{locale}->{default_language});
            $ua->cookie_jar->empty;
            $ua->cookie_jar->add(
              Mojo::Cookie::Response->new(
                name   => 'language',
                value  => $language,
                domain => $self->app->config->{account}->{cookiedomain},
                path   => '/'
              )
            );
            $res = $ua->get(sprintf('%s/%s', $server, $uri))->result;
            say sprintf('    %s/%s %s %3d', $server, $uri, $language, $res->code);
          }
        }
        $uris->{$uri} = 1;
        $res->dom('img, a')->each(sub($dom, $i) {
          my $link = '';
          if ('a' eq $dom->tag) {
            $link = $dom->attr('href') // '';
          } elsif ('img' eq $dom->tag) {
            $link = $dom->attr('src') // '';
          }
          if ('' ne $link) {
            $link =~ s/$siteurl//;
            if ($link !~ /http/) {
              if (!exists($uris->{$link})) {
                $uris->{$link} = 0;
                $again = 1;
              }
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