use strict;
use Test::More tests => 1;
use lib 't';
use onlyTest;

use only '_Foo::Bar' => '0.50';
is($_Foo::Bar::VERSION, '0.50');
