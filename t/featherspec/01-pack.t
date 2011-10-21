#! perl

use strict;
use warnings;

use Test::More qw(no_plan);

# Test valid featherspec file
{
    my $output = `./installable_plumage-admin pack testlib/valid/FEATHER.spec`;

    # TODO Fill this in when output format has been designed
    my $expected_output = <<OUTPUT;
OUTPUT

    is $output, $expected_output, "Check output of 'pack' command with valid featherspec";

    ok not $?, "Check that 'pack' executed successfully with valid featherspec";
}

# Test invalid featherspec file
{
    my $output = `./installable_plumage-admin pack testlib/invalid/FEATHER.spec`;

    my $expected_output = <<OUTPUT;
[ERROR] File testlib/invalid/FEATHER.spec is not a valid featherspec.
OUTPUT

    like $output, $expected_output, "Check output of 'pack' command with invalid featherspec";

    ok not $?, "Check that 'pack' executed successfully with invalid featherspec";
}

# Test non-featherspec file
{
    my $output = `./installable_plumage-admin pack testlib/foo.bar`;

    my $expected_output = <<OUTPUT;
[ERROR] Featherspec files must be named FEATHER.spec.
OUTPUT

    like $output, $expected_output, "Check output of 'pack' command with non-featherspec";

    ok not $?, "Check that 'pack' executed successfully with non-featherspec";
}

# vim: ft=perl
