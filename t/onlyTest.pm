package onlyTest;
BEGIN { $^W = 1 }
@EXPORT = qw(version_install site_install);

use strict;
use base 'Exporter';
use Test::More;
use File::Spec;
use Cwd;
use lib File::Spec->catdir(qw(t site));

use only;
$only::config::versionlib = 
  File::Spec->rel2abs(File::Spec->catdir(qw(t version)));
$only::config::versionarch = 
  File::Spec->rel2abs(File::Spec->catdir(qw(t version arch)));
$only::config::site = 
  File::Spec->rel2abs(File::Spec->catdir(qw(t site)));

sub version_install {
    my ($dist) = @_;
    my $home = Cwd::cwd();
    chdir(File::Spec->catdir(t => $dist)) or die $!;
    only::install();
    chdir($home) or die $!;
}

sub site_install {
    my ($dist) = @_;
    my $home = Cwd::cwd();
    chdir(File::Spec->catdir(t => $dist)) or die $!;
    my $lib = File::Spec->catdir(qw(blib lib));
    my $install_map = {
        $lib  => $only::config::site,
        read  => '',
    };
    ExtUtils::Install::install($install_map, 1, 0);
    chdir($home) or die $!;
}

1;
