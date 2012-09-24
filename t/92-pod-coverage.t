#!perl -T

use strict;
use warnings;

use Test::More;

use lib 't/lib';
use VPIT::TestHelpers;

my $desc = 'required for testing POD coverage';

load_or_skip('Test::Pod::Coverage', '1.08', [ tests => 1 ], $desc);
load_or_skip('Pod::Coverage',       '0.18', undef,          $desc);

eval 'use Test::Pod::Coverage'; # Make Kwalitee test happy

pod_coverage_ok(
 're::engine::Hooks',
 {
  also_private => [
   qr/^_/,
   qr/^CLONE(?:_SKIP)?$/,
   'dl_load_flags',
  ],
 },
 're::engine::Hooks is covered',
);
