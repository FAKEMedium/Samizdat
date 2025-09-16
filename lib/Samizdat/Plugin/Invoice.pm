package Samizdat::Plugin::Invoice;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Invoice;
use Mojo::Home;
use Mojo::File;
use Data::Dumper;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  # Invoice root routes
  my $manager = $r->manager('invoices')->to(controller => 'Invoice');
  $manager->get('/open')                                             ->to('#open')                 ->name('invoice_open');
  $manager->get('/:invoiceid')                                       ->to('#handle')               ->name('invoice_handle');
  $manager->get('/:invoiceid/:to')                                   ->to('#nav')                  ->name('invoice_nav');
  $manager->get('/')                                                 ->to('#index')                ->name('invoice_index');

  # Customer specific invoice routes
  my $customers = $r->manager('customers/:customerid/invoices')->to(controller => 'Invoice');
  $customers->get('invoices/open')                                   ->to('#edit')                 ->name('invoice_edit');
  $customers->put('open')                                            ->to('#update')               ->name('invoice_uppdate');
  $customers->post('/open')                                          ->to('#create')               ->name('invoice_create');
  $customers->get('/:invoiceid')                                     ->to('#handle')               ->name('invoice_handle');
  $customers->post('/:invoiceid/creditinvoice')                      ->to('#creditinvoice')        ->name('invoice_creditinvoice');
  $customers->get('/:invoiceid/payment')                             ->to('#payment')              ->name('invoice_payment');
  $customers->post('/:invoiceid/payment')                            ->to('#payment')              ->name('invoice_payment');
  $customers->get('/:invoiceid/remind')                              ->to('#remind')               ->name('invoice_remind');
  $customers->post('/:invoiceid/remind')                             ->to('#remind')               ->name('invoice_remind');
  $customers->post('/:invoiceid/resend')                             ->to('#resend')               ->name('invoice_resend');
  $customers->post('/:invoiceid/reprint')                            ->to('#reprint')              ->name('invoice_reprint');
  $customers->get('/:invoiceid/:to')                                 ->to('#nav')                  ->name('invoice_nav');
  $customers->get('/')                                               ->to('#index')                ->name('invoice_index');

  # Customer specific product routes
  my $products = $r->manager('customers/:customerid/products')->to(controller => 'Invoice');
  $products->get('/subscribe')                                       ->to('Customer#products');
  $customers->post('/')                                              ->to('Customer#subscribe');

  $app->helper(invoice => sub ($self) {
    state $invoice = Samizdat::Model::Invoice->new({
      config => $self->config->{manager}->{invoice},
      pg     => $self->app->pg,
      mysql  => $self->app->mysql,
    });
    return $invoice;
  });

  $app->helper(
    printinvoice => sub($self, $tex, $formdata) {
      my $texpath = Mojo::Home->new()->rel_file(sprintf('src/tmp/%s.tex', $formdata->{invoice}->{uuid}));
      my $pdfpath = Mojo::File->new(sprintf('%s/%s.pdf',
        $app->config->{manager}->{invoice}->{invoicedir},
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
