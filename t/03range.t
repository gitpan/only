use strict;
use Test::More tests => 4;
use lib 't';
use onlyTest;

use only '_Foo::Bar' => '0.50-0.59 !0.50';
like($INC{'_Foo/Bar.pm'}, qr'0\.55');
is($_Foo::Bar::VERSION, '0.50');
like($INC{'_Foo/Baz.pm'}, qr'0\.55');
is($_Foo::Baz::VERSION, '0.55');
