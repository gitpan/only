use strict;
use Test::More tests => 4;
use lib 't';
use onlyTest;
use File::Spec;
no warnings 'once';

create_packages
{
    '_Boom' =>
    {
        '0.77' =>
        {
            '_Boom' => ['0.77', '$_Boom::boom="Bada-Boom";'],
        },
    },
};

my $versionlib = File::Spec->rel2abs(File::Spec->catdir(qw(t alternate)));

version_install('_Boom-0.77', versionlib => $versionlib);
ok(-f File::Spec->catfile(qw(t alternate 0.77 _Boom.pm)));

eval qq{use only {versionlib => '$versionlib'}, _Boom => '0.77'};
is($@, '');
is($_Boom::VERSION, '0.77');
is($_Boom::boom, 'Bada-Boom');
