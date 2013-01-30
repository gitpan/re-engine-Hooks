#!perl -T

use strict;
use warnings;

use Test::More;

use lib 't/lib';
use VPIT::TestHelpers;

load_or_skip_all('Test::Pod::Coverage', '1.08', [ tests => 1 ]);
load_or_skip_all('Pod::Coverage',       '0.18'                );

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
