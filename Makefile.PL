use CPAN::MakeMaker;

create_config_module();

$PREREQ_PM{'Test::More'} = 0;

$NAME = 'only';
$VERSION_FROM = 'lib/only.pm';
@CLEAN_FILES = qw(
  lib/only/config.pm 
  t/lib t/site t/distributions t/version t/alternate
  t/_Foo-Bar-0.55/blib/arch
  t/_Foo-Bar-0.50/blib/arch
  t/_Foo-Bar-0.60/blib/arch
  t/_Foo-Bar-1.00/blib/arch
);

WriteMakefile;

#==============================================================================
use strict;
use lib 't'; 
use onlyTemplate;
use Config;
use File::Spec;

my ($versionlib, $suggested_versionlib, $old_versionlib, $old_differs);
BEGIN {
    $versionlib = '';
    $old_versionlib = '';
    $suggested_versionlib = '';
}

sub create_config_module {
    my $a;
    heuristics();
    $old_differs = 
      ($old_versionlib and $old_versionlib ne $suggested_versionlib);
    intro();

    my $default = $old_differs ? 'n' : 'y';
    while (1) {
        $a = prompt('Do you want to use the "suggested" directory (y/n)?', 
                    $default
                   );
        last if $a =~ /^[yn]$/i;
    }
    if ($a =~ /^y$/) {
        $versionlib = $suggested_versionlib;
    }
    elsif ($old_differs) {
        while (1) {
            $a = prompt('Do you want to use the "old" directory (y/n)?', 
                        'y'
                       );
            last if $a =~ /^[yn]$/i;
        }
        if ($a =~ /^y$/) {
            $versionlib = $old_versionlib;
        }
    }

    ask() if $a =~ /^n$/i;

    write_template('config.pm.template', 
                   'lib/only/config.pm',
                   {VERSIONLIB => $versionlib},
                  );
}

sub heuristics {
    eval q{ require only::config };
    unless ($@ or defined $only::config::versionarch) {
        $old_versionlib = &only::config::versionlib;
    }
    my ($vol, $dir) = File::Spec->splitpath( $Config{sitelib}, 1 );
    my @dir = File::Spec->splitdir($dir);

    if (grep /^site/i, @dir) {
        s/^site.*/version/i for @dir;
        $suggested_versionlib =
          File::Spec->catpath(
              $vol, 
              File::Spec->catdir(@dir),
          );
    }
    else {
        $suggested_versionlib = 
          File::Spec->catpath(
              $vol, 
              File::Spec->catdir(@dir, 'version-lib'),
          );
    }
}

sub intro {
    print <<END;

"only.pm" has special functionality that allows you to install multiple
versions of any Perl module. In order to do this, it installs the
modules in a separate directory than the rest of your modules.

You need to decide which directory the modules will be installed in.
This value will be stored in only::config so that only.pm will know
where to look in order to load special versions of a module.

The suggested place to install special versions of Perl modules is:

  $suggested_versionlib

END

    print <<END if $old_differs;

But in a previous install you choose this directory:

  $old_versionlib

END
}

sub ask {
    print <<END;

OK. Please enter a directory where special versions of Perl modules will
be installed. The directory must be an absolute path and must already
exist to be accepted.

END

    while (1) {
        $a = prompt("Version lib?", $versionlib);
        last if -d $a and File::Spec->file_name_is_absolute($a);
    }
    $versionlib = $a;
}
