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
    action     => 'authorize',
    level      => 'superadmin',
  );

  $manager->get('invoices/open')->to('Invoice#open')->name('invoice_open');
  $manager->get('invoices/:invoiceid')->to('Invoice#handle')->name('invoice_handle');
  $manager->get('invoices/:invoiceid/:to')->to('Invoice#nav')->name('invoice_nav');
  $manager->get('invoices')->to('Invoice#index')->name('invoice_index');

  $manager->get('customers/:customerid/invoices/open')->to('Invoice#edit')->name('invoice_edit');
  $manager->put('customers/:customerid/invoices/open')->to('Invoice#update')->name('invoice_uppdate');
  $manager->post('customers/:customerid/invoices/open')->to('Invoice#create')->name('invoice_create');
  $manager->get('customers/:customerid/invoices/:invoiceid')->to('Invoice#handle')->name('invoice_handle');
  $manager->post('customers/:customerid/invoices/:invoiceid/creditinvoice')->to('Invoice#creditinvoice')->name('invoice_creditinvoice');
  $manager->get('customers/:customerid/invoices/:invoiceid/payment')->to('Invoice#payment')->name('invoice_payment');
  $manager->post('customers/:customerid/invoices/:invoiceid/payment')->to('Invoice#payment')->name('invoice_payment');
  $manager->get('customers/:customerid/invoices/:invoiceid/remind')->to('Invoice#remind')->name('invoice_remind');
  $manager->post('customers/:customerid/invoices/:invoiceid/remind')->to('Invoice#remind')->name('invoice_remind');
  $manager->post('customers/:customerid/invoices/:invoiceid/resend')->to('Invoice#resend')->name('invoice_resend');
  $manager->post('customers/:customerid/invoices/:invoiceid/reprint')->to('Invoice#reprint')->name('invoice_reprint');
  $manager->get('customers/:customerid/invoices/:invoiceid/:to')->to('Invoice#nav')->name('invoice_nav');
  $manager->get('customers/:customerid/invoices')->to('Invoice#index')->name('invoice_index');

  $manager->get('customers/:customerid/products/subscribe')->to('Customer#products');
  $manager->post('customers/:customerid/products')->to('Customer#subscribe');

  $app->helper(invoice => sub ($self) {
    state $invoice = Samizdat::Model::Invoice->new({
      config => $self->config->{roomservice}->{invoice},
      pg     => $self->app->pg,
      mysql  => $self->app->mysql,
    });
    return $invoice;
  });

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
      my $pdf = $pdfpath->slurp || 0;
      if (!$self->app->config->{test}->{invoice}) {
        $texpath->dirname->remove_tree({ keep_root => 1 });
      }
      return $pdf;
    }
  );
}

1;
