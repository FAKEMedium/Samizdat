package Samizdat::Model::Cache;

use strict;
use warnings FATAL => 'all';
use Mojo::Base -base, -signatures;
use Mojo::Promise;
use Mojo::JSON qw(decode_json);

has 'config';

1;