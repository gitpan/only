use strict;
use Test::More tests => 3;
use lib 't';
use onlyTest;

use _Foo::Bar;
is($_Foo::Bar::VERSION, '1.00');

eval q{use only '_Foo::Bar' => '0.88'};
like($@, qr'already loaded');
is($_Foo::Bar::VERSION, '1.00');
