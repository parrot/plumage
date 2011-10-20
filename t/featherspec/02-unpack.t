#! perl

use strict;
use warnings;

use Cwd;
use Test::More qw(no_plan);

my $feather = 'foobar-1.2.3';

# Test valid source feather
{
    my $package = "$feather.src.pf";
    my $output  = `./installable_plumage-admin unpack testlib/valid/$package`;

    my $cwd = getcwd;

    my $expected_output = <<OUTPUT;
Archive:  $cwd/$package
  inflating: $feather.featherspec
  inflating: $feather.zip

Done. You may not enter directory
$feather/$feather
and type 'plumage-admin make' to build.
OUTPUT

    is $output, $expected_output, "Check output of 'unpack' command with valid source feather";

    ok not $?, "Check that 'unpack' executed successfully with valid source feather";
}

# Test invalid source feather
{
    my $package = "$feather.src.pf";
    my $output  = `./installable_plumage-admin unpack testlib/invalid/$package`;

    my $expected_output = <<OUTPUT;
[ERROR] File testlib/invalid/$package is not a valid feather
OUTPUT

    is $output, $expected_output, "Check output of 'unpack' command with invalid source feather";

    ok not $?, "Check that 'unpack' executed successfully with invalid featherspec";
}

# Test valid binary feather
{
    my $package = "$feather.all.pf";
    my $output  = `./installable_plumage-admin unpack testlib/valid/$package`;

    my $cwd = getcwd;

    my $expected_output = <<OUTPUT;
Archive:  $cwd/$package
  inflating: $feather.featherspec
  inflating: $feather.zip

Done. You may not enter directory
$feather/$feather
and type 'plumage-admin make' to build.
OUTPUT

    is $output, $expected_output, "Check output of 'unpack' command with valid binary feather";

    ok not $?, "Check that 'unpack' executed successfully with valid binary feather";
}

# Test valid binary feather
{
    my $package = "$feather.all.pf";
    my $output  = `./installable_plumage-admin unpack testlib/invalid/$package`;

    my $cwd = getcwd;

    my $expected_output = <<OUTPUT;
[ERROR] File testlib/invalid/$package is not a valid feather
OUTPUT

    is $output, $expected_output, "Check output of 'unpack' command with invalid binary feather";

    ok not $?, "Check that 'unpack' executed successfully with invalid binary feather";
}

# Test non-feather file
{
    my $output = `./installable_plumage-admin unpack testlib/foo.bar`;

    my $expected_output = <<OUTPUT;
[ERROR] File testlib/foo.bar is not a valid feather
OUTPUT

    is $output, $expected_output, "Check output of 'unpack' command with non-feather";

    ok not $?, "Check that 'unpack' executed successfully with non-feather";
}

# vim: ft=perl
