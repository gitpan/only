# $File: //depot/cpan/Module-Install/lib/Module/Install/Include.pm $ $Author: autrijus $
# $Revision: #6 $ $Change: 1340 $ $DateTime: 2003/03/09 23:26:56 $ vim: expandtab shiftwidth=4

package Module::Install::Include;
use base 'Module::Install::Base';

sub include {
    my ($self, $pattern) = @_;

    foreach my $rv ( $self->admin->glob_in_inc($pattern) ) {
        $self->admin->copy_package(@$rv);
    }
    return $file;
}

sub include_deps {
    my ($self, $pkg, $perl_version) = @_;
    my $deps = $self->admin->scan_dependencies($pkg, $perl_version) or return;

    foreach my $key (sort keys %$deps) {
        $self->include($key, $deps->{$key});
    }
}

1;
