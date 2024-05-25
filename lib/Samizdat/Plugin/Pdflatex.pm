package Samizdat::Plugin::Pdflatex;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::Home;
use Data::Dumper;

sub register ($self, $app, $conf) {

  $app->helper(
    printinvoice => sub($c, $tex, $formdata) {
      my $texpath = Mojo::Home->new()->rel_file(sprintf('src/tmp/%s.tex', $formdata->{invoice}->{uuid}));
      my $pdfpath = Mojo::Home->new()->rel_file(sprintf('public/invoice/%s.pdf', $formdata->{invoice}->{uuid}));
      $texpath->spurt($tex);

      my $command = [
        'latexmk',
        '-pdf',
        sprintf('-auxdir=%s', $texpath->dirname),
        '-interaction=nonstopmode',
        '-silent',
        sprintf('-outdir=%s', $texpath->dirname),
        $texpath->to_string
      ];
      system(@{$command});

      $texpath->dirname->rel_file(sprintf('%s.pdf', $formdata->{invoice}->{uuid}))->move_to($pdfpath);
      my $pdf = $pdfpath->slurp;
      $texpath->dirname->remove_tree({ keep_root => 1 });
      return $pdf;
    }
  );
}

1;