use strict;
use Test::More tests => 4;
use lib 't';
use onlyTest;

use only '_Foo::Bar' => '1.00';
unlike($INC{'_Foo::Bar.pm'}, qr'version');
is($_Foo::Bar::VERSION, '1.00');
require _Foo::Baz;
unlike($INC{'_Foo::Bar.pm'}, qr'version');
is($_Foo::Baz::VERSION, '0.98');
