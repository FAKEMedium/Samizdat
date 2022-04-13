package Samizdat::Model::Web;

use strict;
use warnings FATAL => 'all';
use experimental qw(signatures);

sub new ($class, $path, $options = {}) {
  bless {
    docpath     => $path,
    title       => $options->{title},
    main        => $options->{main},
    description => $options->{description},
    keywords    => $options->{keywords},
    subdocs     => [],
    children    => [],
  },
  $class
}



1;