# $File: //depot/cpan/Module-Install/lib/Module/Install/Can.pm $ $Author: ingy $
# $Revision: #3 $ $Change: 1364 $ $DateTime: 2003/03/11 22:44:50 $ vim: expandtab shiftwidth=4

package Module::Install::Can;
$VERSION = '0.01';
use strict;
use base 'Module::Install::Base';

# check if we can run some command
sub can_run {
    my ($self, $cmd) = @_;

    require Config;
    require File::Spec;
    require ExtUtils::MakeMaker;

    my $_cmd = $cmd;
    return $_cmd if (-x $_cmd or $_cmd = MM->maybe_command($_cmd));

    for my $dir ((split /$Config::Config{path_sep}/, $ENV{PATH}), '.') {
        my $abs = File::Spec->catfile($dir, $cmd);
        return $abs if (-x $abs or $abs = MM->maybe_command($abs));
    }

    return;
}

sub can_cc {
    my $self = shift;
    require Config;
    my $cc = $Config::Config{cc} or return;
    $self->can_run($cc);
}

1;
