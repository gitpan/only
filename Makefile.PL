# use strict;
use CPAN::MakeMaker;
use Config;
use File::Spec;
use File::Path;

create_config_module();

$PREREQ_PM{'Test::More'} = 0;

$NAME = 'only';
@CLEAN_FILES = qw(
  lib t/site t/version
  t/_Foo-Bar-0.55/blib/arch
  t/_Foo-Bar-0.50/blib/arch
  t/_Foo-Bar-0.60/blib/arch
);

WriteMakefile;

#==============================================================================

my ($versionlib, $versionarch);

sub create_config_module {
    my $a;
    heuristics();
    intro();
    while (1) {
        $a = prompt("Do you want to use the defaults (y/n)?", 'Y');
        last if $a =~ /^[yn]$/i;
    }
    ask() if $a =~ /^n$/i;
    template_config();
}

sub heuristics {
    eval { require only::config };
    if (not $@) {
        $versionlib = $only::config::versionlib;
        $versionarch = $only::config::versionarch;
        return;
    }
    my ($vol1, $dir1) = File::Spec->splitpath( $Config{sitelib} );
    my @dir1 = File::Spec->splitdir($dir1);
    my $path1 = join ',', @dir1;
    my ($vol2, $dir2) = File::Spec->splitpath( $Config{sitearch} );
    my @dir2 = File::Spec->splitdir($dir2);
    my $path2 = join ',', @dir2;

    if ($vol1 eq $vol2 and
        $path1 eq $path2 and
        $path1 =~ /^perl,site,lib$/
       ) {
        $versionlib = $versionarch =
          File::Spec->catpath(
              $vol1, 
              File::Spec->catdir(qw(perl version lib)),
          );
        return;
    }

    if (grep /^site/i, @dir1) {
        s/^site.*/version/i for @dir1;
        $versionlib =
          File::Spec->catpath(
              $vol1, 
              File::Spec->catdir(@dir1),
          );
    }
    else {
        $versionlib = 
          File::Spec->catpath(
              $vol1, 
              File::Spec->catdir(@dir1, 'version-lib'),
          );
    }
        
    if (grep /^site/i, @dir2) {
        s/^site.*/version/i for @dir2;
        $versionarch =
          File::Spec->catpath(
              $vol2, 
              File::Spec->catdir(@dir2),
          );
    }
    else {
        $versionarch = 
          File::Spec->catpath(
              $vol2, 
              File::Spec->catdir(@dir2, 'version-arch'),
          );
    }

}

sub intro {
    print <<END;

"only.pm" has special functionality that allows you to install multiple
versions of any Perl module. In order to do this, it installs the
modules in a separate directory than the rest of your modules.

You need to decide which directories the modules will be installed in.
These values will be stored in only::config so that only.pm will know
where to look in order to load special versions of a module.

According to my heuristics (guesses), the best place to install special
versions of Perl modules is:

  lib:  $versionlib
  arch: $versionarch

END
}

sub ask {
    print <<END;

OK. You need to enter two directories. The first one is where plain Perl
modules will be installed. The second one is where architecture
dependent modules go. They can be the same directory. The directory(s)
must already exist to be accepted.

END

    while (1) {
        $a = prompt("Version lib?", $versionlib);
        last if -d $a and File::Spec->file_name_is_absolute($a);
    }
    $versionlib = $a;

    while (1) {
        $a = prompt("Version arch?", $versionarch);
        last if -d $a and File::Spec->file_name_is_absolute($a);
    }
    $versionarch = $a;
}

sub template_config {
    local $/;
    open TEMPLATE, "config.pm.template"
      or die "Can't open config.pm.template for input:\n$!\n";
    my $template = <TEMPLATE>;
    $template =~ s/<%VERSIONLIB%>/$versionlib/;
    $template =~ s/<%VERSIONARCH%>/$versionarch/;
    close TEMPLATE;

    mkpath('lib/only');
    open CONFIG, ">lib/only/config.pm"
      or die "Can't open lib/only/config.pm for output:\n$!\n";
    print CONFIG $template;
    close CONFIG;
}
