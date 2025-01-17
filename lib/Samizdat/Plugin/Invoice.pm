package Samizdat::Plugin::Invoice;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Invoice;
use Mojo::Home;
use Mojo::File;
use Data::Dumper;

sub register ($self, $app, $conf) {
  my $r = $app->routes;
  my $manager = $r->under($app->config->{managerurl})->to(
    controller => 'Account',
#    action     => 'authorize',
    action => 'user',
    require    => {
#      users => $app->config->{account}->{admins}
    }
  );

  #  $manager->post(sprintf('%s%s', $app->config->{managerurl}, 'invoices'))->to('Invoice#create');
  #  $manager->put(sprintf('%s%s', $app->config->{managerurl}, 'invoices'))->to('Invoice#update');
  $manager->get('customers/:customerid/invoices/open')->to('Invoice#edit');
  $manager->put('customers/:customerid/invoices/open')->to('Invoice#update');
  $manager->post('customers/:customerid/invoices/open')->to('Invoice#create');
  $manager->get('customers/:customerid/invoices/:invoiceid')->to('Invoice#handle');
  $manager->get('customers/:customerid/invoices')->to('Invoice#index');
  $manager->get('customers/:customerid/products/subscribe')->to('Customer#products');
  $manager->post('customers/:customerid/products')->to('Customer#subscribe');
  $manager->get('invoices/open')->to('Invoice#open');
  $manager->get('invoices')->to('Invoice#index');

  $app->helper(invoice => sub { state $invoice = Samizdat::Model::Invoice->new({app => shift}) });
  $app->helper(
    printinvoice => sub($c, $tex, $formdata) {
      my $texpath = Mojo::Home->new()->rel_file(sprintf('src/tmp/%s.tex', $formdata->{invoice}->{uuid}));
      my $pdfpath = Mojo::File->new(sprintf('%s/%s.pdf',
        $app->config->{roomservice}->{invoice}->{invoicedir},
        $formdata->{invoice}->{uuid})
      );
      $texpath->spew($tex);

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
