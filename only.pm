package only;
$VERSION = '0.10';
use strict;
use 5.006001;
use only::config;
use File::Spec;
use Config;
use Carp;
use overload '""' => \&stringify;

# sub XXX { require Data::Dumper; croak Data::Dumper::Dumper(@_) }

sub import {
    $DB::single = 1;
    goto &_install if @_ == 2 and $_[1] eq 'install';
    my ($class, $package) = splice(@_, 0, 2);
    return unless defined $package and $package;
    
    my (@sets, $s, $loaded);
    if (not @_) {
        @sets = (['']);
    }
    elsif (ref($_[0]) eq 'ARRAY') {
        @sets = @_;
    }
    else {
        @sets = ([@_]);
    }

    for my $set (@sets) {
        $s = $class->new($package, $set);
        $loaded = $s->module_require and last;
    }

    if (not defined $INC{$s->pkg_path}) {
        eval "require " . $s->package;
        $loaded = not($@) && $s->check_version($s->package->VERSION);
    }

    if (not $loaded) {
        $s->module_not_found;
    }

    my $import = $s->export
      or return;

    @_ = ($s->package, @{$s->arguments});
    goto &$import;
}

sub new {
    my ($class, $package, $set) = @_;
    my ($condition, @arguments) = @$set;
    my $s = bless {}, $class;
    $s->package($package || '');
    $s->condition($condition || '');
    $s->no_export(@arguments == 1 and
                  ref($arguments[0]) eq 'ARRAY' and
                  @{$arguments[0]} == 0
                 );
    $s->arguments(\@arguments);

    $s->parse_condition;

    $s->lib($only::config::versionlib);
    $s->arch($only::config::versionarch);

    $s->pkg_path(File::Spec->catdir(split '::', $s->package) . '.pm');
    $s->canon_path(join('/',split('::', $s->package)).'.pm');
    $s->prev_inc_path('');
    $s->prev_canon_path('');
    $s
}

sub module_require {
    my ($s) = @_;
    if (defined $INC{$s->canon_path}) {
        return $s->check_version($s->get_loaded_version);
    }
        
    my @versions;
    if ($s->fancy) {
        @versions = grep $s->check_version($_), $s->all_versions();
    }
    else {
        @versions = map { $_->[0] } @{$s->condition_spec};
    }
    $s->version_require(@versions)
}

sub version_require {
    my $s = shift;
    for my $version (sort { $b <=> $a } @_) {
        my $path_lib  = File::Spec->catfile($s->lib,  $version, $s->pkg_path);
        my $path_arch = File::Spec->catfile($s->arch, $version, $s->pkg_path);
        for my $path ($path_lib, $path_arch) {
            if (-f $path) {
                $s->require_version($version);
                $s->other_modules($path);
                unshift @INC, $s;
                local $^W = 0;
                eval "require " . $s->package;
                croak "Trouble loading $path\n$@" if $@;
                $s->correct_inc;
                return 1;
            }
        }
    }
    return 0;
}

sub only::INC {
    my ($s, $pkg_path) = @_;
    $s->correct_inc;
        
    return unless defined $s->other_modules->{$pkg_path};

    my $version = $s->require_version;

    my $path_lib  = File::Spec->catfile($s->lib,  $version, $pkg_path);
    my $path_arch = File::Spec->catfile($s->arch, $version, $pkg_path);
    for my $path ($path_lib, $path_arch) {
        if (-f $path) {
            $s->prev_inc_path($path);
            $s->prev_canon_path(join('/', File::Spec->splitdir($pkg_path)));
            $INC{$s->prev_canon_path} = 1;
            open my $fh, $path
              or die "Can't open $path for input\n";
            return $fh;
        }
    }
    croak "Can't load versioned $pkg_path\n";
}

sub stringify {
    my ($s) = @_;
    'only:' . $s->package . ':' . 
      File::Spec->catdir($s->lib, $s->require_version)
}

sub correct_inc {
    my ($s) = @_;
    if ($s->prev_inc_path) {
        $INC{$s->prev_canon_path} = $s->prev_inc_path;
        $s->prev_inc_path('');
        $s->prev_canon_path('');
    }
}

sub get_loaded_version {
    my ($s) = @_;
    my $path = $INC{$s->canon_path};
    my $version = $s->package->VERSION;
    if ($path =~ s/\.pm$/\.yaml/ and -f $path) {
        open META, $path
          or croak "Can't open $path for input:\n$!";
        my $meta = do {local $/;<META>};
        close META;
        if ($meta =~ /^install_version\s*:\s*(\S+)$/m) {
            $version = $1;
        }
    }
    $version
}

sub parse_condition {
    my ($s) = @_;
    my @condition = split /\s+/, $s->condition;
    $s->fancy(@condition ? 0 : 1);
    @condition = map {
        my $v;
        if (/^(!)?(\d[\d\.]*)?(?:(-)(\d[\d\.]*)?)?$/) {
            $s->fancy(1)
              if defined($1) or defined($3);
            my $lower = $2 || '0.00';
            my $upper = defined($4) ? $4 : 
                        defined($3) ? '999999999999' : 
                        $lower;
            my $negate = defined($1) ? 1 : 0;
            croak "Lower bound > upper bound in '$_'\n"
              if $lower > $upper;
            $v = [$lower, $upper, $negate];
        }
        else {
            croak "Invalid condition '$_' specified for 'only'\n";
        }
        $v;
    } @condition;
    $s->condition_spec(\@condition)
}

sub all_versions {
    my ($s) = @_;
    my %versions;
    for my $lib ($s->lib, $s->arch) {
        opendir LIB, $s->lib;
        while (my $dir = readdir(LIB)) {
            next unless $dir =~ /^\d[\d\.]*$/;
            next if $dir eq $Config{version};
            $versions{$dir} = 1;
        }
        closedir(LIB);
    }
    keys %versions
}

sub check_version {
    my ($s, $version) = @_;
    my @specs = @{$s->condition_spec};
    return 1 unless @specs;
    my $match = 0;
    for my $spec (@specs) {
        my ($lower, $upper, $negate) = @$spec;
        next if $match and not $negate;
        if ($version >= $lower and $version <= $upper) {
            return 0 if $negate;
            $match = 1;
        }
    }
    $match
}

sub export {
    my ($s) = @_;
    return if $s->no_export;
    $s->package->can('import')
}

# Generic getter/setter
sub AUTOLOAD {
    my $s = shift;
    (my $attr = $only::AUTOLOAD) =~ s/.*:://;
    $s->{$attr} = shift if @_;
    $s->{$attr}
}

sub other_modules {
    my ($s, $path) = (@_, '');
    $s->{other_modules} ||= {};
    return $s->{other_modules}
      unless $path;
    $path =~ s/\.pm$/\.yaml/
      or return {};
    open META, $path
      or return {};
    $s->{other_modules} = {};
    my $meta = do {local $/; <META>};
    close META;
    $s->{other_modules}{$_} = 1 for ($meta =~ /^  - (\S+)/gm);
    $s->{other_modules}
}

sub module_not_found {
    use Data::Dumper;
    my ($s) = @_;
    my $p = $s->package;
    if (defined $INC{$s->canon_path}) {
        my $v = $s->get_loaded_version;
    croak <<END;
Module '$p', version '$v' already loaded, 
but it does not meet the requirements of this 'use only ...'.
END
    }
    my $inc = join "\n", map "  - $_", @INC;
    croak <<END;
Can't locate desired version of $p in \@INC:
$inc
END
}

#==============================================================================

sub _install {
    install(@_);
    exit 0;
}
    
sub install {
    {
        local $^W = 0;
        require ExtUtils::Install;
    }

    check_env();
    my $version = get_version();
    
    my $lib  = File::Spec->catdir(qw(blib lib));
    mkdir($lib, 0777) unless -d $lib;
    my $arch = File::Spec->catdir(qw(blib arch));
    mkdir($arch, 0777) unless -d $arch;

    my $install_lib  = File::Spec->catdir(
        $only::config::versionlib, 
        $version,
    );
    my $install_arch = File::Spec->catdir(
        $only::config::versionarch, 
        $version,
    );
    my $install_map = {
        $lib  => $install_lib,
        $arch => $install_arch,
        read  => '',
    };
    ExtUtils::Install::install($install_map, 1, 0);

    my @lib_pm_files = map trim_dir($_), find_pm($lib);
    my @arch_pm_files = map trim_dir($_), find_pm($arch);
    my $meta = <<END;
# This meta file created by/for only.pm
only_version: $only::VERSION
install_version: $version
install_modules:
END
    for my $pm_file (sort(@lib_pm_files, @arch_pm_files)) {
        $meta .= "  - $pm_file\n";
    }
    install_meta($meta, $install_lib, $_) for @lib_pm_files;
    install_meta($meta, $install_arch, $_) for @arch_pm_files;
}

sub install_meta {
    my ($meta, $base, $module) = @_;
    my $meta_file = File::Spec->catfile($base, $module);
    $meta_file =~ s/\.pm$/\.yaml/
      or croak;
    my $old_meta = '';
    if (-f $meta_file) {
        open META, $meta_file
          or croak "Can't open $meta_file for input\n";
        $old_meta = do {local $/; <META>};
        close META;
    }
    if ($meta eq $old_meta) {
        print "Skipping $meta_file (unchanged)\n";
    }
    else {
        print "Installing $meta_file\n";
        open META, '>', $meta_file
          or croak "Can't open $meta_file for output\n";
        print META $meta;
        close META;
    }
}

sub trim_dir {
    my ($path) = @_;
    my ($vol, $dir, $file) = File::Spec->splitpath($path);
    my @dirs = File::Spec->splitdir($dir);
    pop @dirs unless $dirs[-1];
    splice(@dirs, 0, 2);
    $dir = scalar(@dirs) ? File::Spec->catdir(@dirs) : '';
    $dir ? File::Spec->catfile($dir, $file) : $file
}

sub find_pm {
    my ($path, $base) = (@_, '');
    croak unless $path;
    my (@pm_files);
    $path = File::Spec->catdir($base, $path) if $base;
    local *DIR;
    opendir(DIR, $path) 
      or croak "Can't open directory '$path':\n$!";
    while (my $file = readdir(DIR)) {
        next if $file =~ /^\./;
        my $file_path = File::Spec->catfile($path, $file);
        my $dir_path = File::Spec->catdir($path, $file);
        if ($file =~ /^\w+\.pm$/) {
            push @pm_files, $file_path;
        }
        elsif (-d $dir_path) {
            push @pm_files, find_pm($file, $path);
        }
    }
    return @pm_files;
}

sub check_env {
    my $lib  = File::Spec->catdir(qw(blib lib));
    my $arch = File::Spec->catdir(qw(blib arch));
    return 1 if -d 'blib' and (-d $lib or -d $arch);
    if (-f 'Build.PL') {
        croak <<END;
First you need to run:
  
  perl Build.PL
  ./Build
  ./Build test    # (optional)

END
    }
    elsif (-f 'Makefile.PL') {
        croak <<END;
First you need to run:
  
  perl Makefile.PL
  make
  make test       # (optional)

END
    }
    else {
        croak <<END;
You don't appear to be inside a directory fit to install a Perl module.
See 'perldoc only' for more information.
END
    }
}

sub get_version {
    my $version = '';
    if (@ARGV and length($ARGV[0])) {
        $version = $ARGV[0];
    }
    else {
        if (-f 'Build.PL') {
            if (-f 'META.yml') {
                open META, "META.yml"
                  or croak "Can't open META.yml for input:\n$!\n";
                local $/;
                my $meta = <META>;
                close META;
                if ($meta =~ /^version\s*:\s+(\S+)$/m) {
                    $version = $1;
                }
            }
        }
        else {
            if (-f 'Makefile') {
                open MAKEFILE, "Makefile"
                  or croak "Can't open Makefile for input:\n$!\n";
                local $/;
                my $makefile = <MAKEFILE>;
                close MAKEFILE;
                if ($makefile =~ /^VERSION\s*=\s*(\S+)$/m) {
                    $version = $1;
                }
            }
        }
        croak <<END unless $version;
Can't determine the version for this install. Please specify manually:

    perl -Monly=install - 1.23

END
    }
    if ($version !~ /^\d[\d\.]*$/) {
        croak <<END;

Operation failed. 
'$version' is an invalid version string.  
Must be numeric.

END
    }
    return $version;
}

1;

__END__

=head1 NAME

only - Load specific module versions; Install many

=head1 SYNOPSIS

    # Install version 0.30 of MyModule
    cd MyModule-0.30
    perl Makefile.PL
    make test
    perl -Monly=install    # substitute for 'make install' 
    
    # Only use MyModule version 0.30
    use only MyModule => '0.30';

    # Only use MyModule if version is between 0.30 and 0.50
    # but not 0.36; or if version is >= to 0.55.
    use only MyModule => '0.30-0.50 !0.36 0.55-', qw(:all);

    # Don't export anything!
    use only MyModule => '0.30', [];

    # Version dependent arguments
    use only MyModule =>
        [ '0.20-0.27', qw(f1 f2 f3 f4) ],
        [ '0.30-',     qw(:all) ];

=head1 USAGE

    # Note: <angle brackets> mean "optional".

    # To load a specific module
    use only MODULE => 'CONDITION SPEC' <, ARGUMENTS>;

    # For multiple argument sets
    use only MODULE => 
        ['CONDITION SPEC 1' <, ARGUMENTS1>],
        ['CONDITION SPEC 2' <, ARGUMENTS2>],
        ...
        ;

    # To install an alternate version of a module
    perl -Monly=install <- VERSION>        # instead of 'make install'

=head1 DESCRIPTION

The C<only.pm> facility allows you to load a MODULE only if it satisfies
a given CONDITION. Normally that condition is a version. If you just
specify a single version, C<'only'> will only load the module matching
that version. If you specify multiple versions, the module can be any of
those versions. See below for all the different conditions you can use
with C<only>.

C<only.pm> will also allow you to load a particular version of a module,
when many versions of the same module are installed. See below for
instructions on how to easily install many different versions of the
same module.

=head1 CONDITION SPECS

A condition specification is a single string containing a list of zero
or more conditions. The list of conditions is separated by spaces. Each
condition can take one of the following forms:

=over 4

=item * plain version

This is the most basic form. The loaded module must match this
version string or be loaded from a B<version directory> that uses the
version string. Mulitiple versions means one B<or> the other.

    use only MyModule => '0.11';
    use only MyModule => '0.11 0.15';

=item * version range

This is two single versions separated by a dash. The end points are
inclusive in the range. If either end of the range is ommitted, then the
range is open ended on that side.

    use only MyModule => '0.11-0.12';
    use only MyModule => '0.13-';
    use only MyModule => '-0.10';
    use only MyModule => '-';       # Means any version

Note that a completely open range (any version) is not the same as
just saying:

    use MyModule;

because the C<only> module will search all the various version libs
before searhing in the regular @INC paths.

Also note that an empty string or no string means the same thing as '-'.

    # All of these mean "use any version"
    use only MyModule => '-';
    use only MyModule => '';
    use only 'MyModule';

=item * complement version or range

Any version or range beginning with a C<'!'> is considered to mean the
inverse of that specification. A complement takes precedence over all
other specifications. If a module version matches a complement, that
version is immediately rejected without further inspection.

    use only MyModule => '!0.31';
    use only MyModule => '0.30-0.40 !0.31-0.33';

=back

The search works by searching the version-lib directories (found in
C<only::config>) for a module that meets the condition specification. If
more than one version is found, the highest version is used. If no
module meets the specification, then a normal @INC style C<require> is
performed.

If the condition is a subroutine reference, that subroutine will be
called and passed an C<only> object. If the subroutine returns a false
value, the program will die. See below for a list of public methods that
may be used upon the C<only> object.

=head1 ARGUMENTS

All of the arguments following the CONDITION specification, will be
passed to the module being loaded. 

Normally you can pass an empty list to C<use> to turn off Exporting. To do this with C<only>, use an empty array ref.

    use only MyModule => '0.30';       # Default exporting
    use only MyModule => '0.30', [];   # No exporting
    use only MyModule => '0.30', qw(export list);  # Specific export

If you need pass different arguments depending on which version is used,
simply wrap each condition spec and arguments with an array ref.

    use only MyModule =>
        [ '0.20-0.27', qw(f1 f2 f3 f4) ],
        [ '0.30-',     qw(:all) ];

=head1 INSTALLING MULTIPLE MODULE VERSIONS

The C<only.pm> module also has a facility for installing more than one
version of a particular module. Using this facility you can install an
older version of a module and use it with the C<'use only'> syntax.

It works like this; when installing a module, do the familiar:

    perl Makefile.PL
    make
    make test

But instead of C<make install>, do this:

    perl -Monly=install

This will attempt to determine what version the module should be
installed under. In some cases you may need to specify the version
yourself. Do the following:

    perl -Monly=install - 0.55

NOTE:
Also works with C<Module::Build> style modules.

NOTE: 
The C<perl> you use for this must be the same C<perl> as the one used to
do C<perl Makefile.PL> or C<perl Build.PL>. While this seems obvious,
you may run into problems with C<sudo perl -Monly=install>, since the
C<root> account may have a different C<perl> in its path. If this
happens, just use the full path to your C<perl>.

=head1 INSTALLATION LOCATION

When you install the C<only> module, you can tell it where to install
alternate versions of modules. These paths get stored into
C<only::config>. The default location to install things is parallel to
your sitelib. For instance if your sitelib was:

    /usr/lib/perl5/site_perl

C<only> would default to:

    /usr/lib/perl5/version

This keeps your normal install trees free from any potential
complication with version modules.

If you install version 0.24 and 0.26 of MyModule and version 0.26 of
Your::Module, they will end up here:

    /usr/lib/perl5/version/0.24/My/Module.pm
    /usr/lib/perl5/version/0.26/My/Module.pm
    /usr/lib/perl5/version/0.26/Your/Module.pm

=head1 HOW IT WORKS

C<only.pm> is kind of like C<lib.pm> on Koolaid! Instead of adding a
search path to C<@INC>, it adds a B<search object> to C<@INC>. This
object is actually the C<only.pm> object itself. The object keeps track
of all of the modules related to a given package installation, and takes
responsibility for loading those modules. This is very important because
if you say:

    use only Goodness => '0.23';

and then later:

    require Goodness::Gracious;

you want to be sure that the correct version of the second module
gets loaded. Especially when another module is doing the loading.

=head1 THE FINE PRINT ON VERSIONING

The C<only.pm> module loads a module by the following process:

 1) Look for the highest suitable version of the module in the version
    libraries specified in only::config.
 
 else:
 
 2) Do a normal require() of the module, and check to make sure the 
    version is in the range specified.

It is important to understand that the versions used in these two
different steps come from different places and might not be the same.
    
In the first step the version used is the version of the C<distribution>
that the module was installed from. This is grepped out of the Makefile
and saved as metadata for that module.

In the second step, the version is taken from $VERSION of that module.
This is the same process used when you do something like:

     use MyModule '0.50';

Unfortunately, there is no way to know what the distribution version is
for a normally installed module.

Fortunately, $VERSION is usually the same as the distribution version.
That's because the popular C<VERSION_FROM> Makefile.PL option makes it
happen. Authors are encouraged to use this option.

The conclusion here is that C<only.pm> usually gets things right. Always
check %INC, if you suspect that the wrong versions are being pulled in.
If this happens, use more C<'use only'> statements to pull in the right
versions. 

One failsafe solution is to make sure that all module versions in
question are installed into the version libraries.

=head1 LOADING MULTIPLE MODULE VERSIONS (at the same time)

You can't do that! Are you crazy? Well B<I> am. I can't do this yet but
I'd really like to. I'm working on it. If you have ideas on how this
might be accomplished, send me an email. If you don't have a good idea,
send me some coffee.

=head1 BUGS AND CAVEATS

=over 4

=item *

There is currently no way to install documentation for multiple modules.

=item *

This module only works with Perl 5.6.1 and higher. That's because earlier
versions of Perl don't support putting objects in @INC.

=back

=head1 AUTHOR

Brian Ingerson <INGY@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2003. Brian Ingerson. All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
