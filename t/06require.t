use strict;
use Test::More tests => 2;
use lib 't';
use onlyTest;

use only '_Foo::Bar' => '0.60';
is($_Foo::Bar::VERSION, '0.60');
require _Foo::Baz;
is($_Foo::Baz::VERSION, '0.60');
