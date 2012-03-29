#!perl -T

use strict;
use warnings;

use blib 't/re-engine-Hooks-TestDist';

use Test::More tests => 6;

my $res;

my $ops;
BEGIN { $ops = [ ] }

{
 use re::engine::Hooks::TestDist 'foo' => $ops;

 BEGIN { @$ops = () }
 @$ops = ();

 $res = "lettuce" =~ /t{2,3}/;

 BEGIN {
  is "@$ops", 'c:EXACT c:CURLY c:END',  'match compilation';
 }
 is "@$ops", 'e:CURLY e:END', 'match execution';
}

ok $res, 'regexp match result';

my @captures;

{
 use re::engine::Hooks::TestDist 'foo';

 BEGIN { @$ops = () }
 @$ops = ();

 @captures = "babaorum" =~ /([aeiou])/g;

 BEGIN {
  is "@$ops", 'c:OPEN c:ANYOF c:CLOSE c:END', 'capture compilation';
 }
 my $expect = join ' ', ('e:OPEN e:ANYOF e:CLOSE e:END') x 4;
 is "@$ops", $expect, 'capture execution';
}

is "@captures", 'a a o u', 'regexp capture result';
