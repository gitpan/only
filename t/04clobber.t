use strict;
use Test::More tests => 7;
use lib 't';
use onlyTest;

use only '_Foo::Bar' => '0.55';
BEGIN {
    like($INC{'_Foo/Bar.pm'}, qr'0.55');
    is($_Foo::Bar::VERSION, '0.50');
}

use only '_Foo::Bar' => '0.55';
like($INC{'_Foo/Bar.pm'}, qr'0.55');
is($_Foo::Bar::VERSION, '0.50');
eval q{ use only '_Foo::Bar' => '0.50' };
ok($@);
like($INC{'_Foo/Bar.pm'}, qr'0.55');
is($_Foo::Bar::VERSION, '0.50');
