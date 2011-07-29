#!/usr/bin/env parrot-nqp

our $PLUMAGE;
my $!;

MAIN();

sub MAIN () {
    # Load testing tools
    pir::load_language('parrot');
    pir::compreg__PS('parrot').import('Test::More');

    # Load NQP utilities library
    pir::load_bytecode('Plumage/NQPUtil.pbc');

    # Set correct path for plumage pbc
    $PLUMAGE := fscat(['.'], 'installable_plumage');

    # Run all sanity tests for plumage
    run_tests();
}

sub run_tests () {
    plan(20);

    # Fuzz tests
    test_invalid();
    test_plumage_invalid();
    test_plumage_info_invalid();
    test_plumage_configure_invalid();
    test_plumage_build_invalid();
    test_plumage_test_invalid();
    test_plumage_install_invalid();

    # Missing argument tests
    test_plumage_no_args();
    test_plumage_fetch_no_args();

    # Behavior tests
    test_plumage_usage();
    test_plumage_version();
    test_plumage_info();
    test_plumage_metadata();
}


#
# FUZZ TESTS
#

sub test_invalid() {
    qx('invalidjunkdoesnotexist');
    nok($! == 0, 'do_run()ing invalidjunk returns false');
}

sub test_plumage_invalid() {
    qx($PLUMAGE, 'asdfversion');
    nok($! == 0, 'plumage returns failure for invalid commands');
}

sub test_plumage_info_invalid() {
    my $output := qx($PLUMAGE, 'info', 'coboloncogs');
    ok($output ~~ /:s I don.t know anything about project .coboloncogs./,
       "command 'info' errors properly for unknown project name");
}

sub test_plumage_configure_invalid() {
    my $output := qx($PLUMAGE, 'configure', 'coboloncogs');
    ok($output ~~ /:s I don.t know anything about project .coboloncogs./,
       "command 'configure' errors properly for unknown project name");
}

sub test_plumage_build_invalid() {
    my $output := qx($PLUMAGE, 'build', 'coboloncogs');
    ok($output ~~ /:s I don.t know anything about project .coboloncogs./,
       "command 'build' errors properly for unknown project name");
}

sub test_plumage_test_invalid() {
    my $output := qx($PLUMAGE, 'test', 'coboloncogs');
    ok($output ~~ /:s I don.t know anything about project .coboloncogs./,
       "command 'test' errors properly for unknown project name");
}

sub test_plumage_install_invalid() {
    my $output := qx($PLUMAGE, 'install', 'coboloncogs');
    ok($output ~~ /:s I don.t know anything about project .coboloncogs./,
       "command 'install' errors properly for unknown project name");
}


#
# MISSING ARGUMENT TESTS
#

sub test_plumage_no_args() {
    my $output := qx($PLUMAGE);
    ok($output ~~ /:s Print program version and copyright/,      'no args give usage');
    ok($output ~~ /:s Print summary about a particular project/, 'no args give usage');
}

sub test_plumage_fetch_no_args() {
    my $output := qx($PLUMAGE, 'fetch');
    ok($output ~~ /:s Please specify a project to act on./, 'fetch without args asks for project name');
}


#
# BEHAVIOR TESTS
#

sub test_plumage_usage() {
    my $output := qx($PLUMAGE, 'usage');
    ok($output ~~ /:s Print program version and copyright/,
        'usage explains how to view version and copyright');
    ok($output ~~ /:s Print summary about a particular project/,
        'usage explains how to get info on a project');
}

sub test_plumage_version() {
    my $output := qx($PLUMAGE, 'version');
    ok($! == 0, 'plumage version returns success');
    ok($output ~~ /:s Parrot Plumage/,    'plumage version knows its name');
    ok($output ~~ /:s Parrot Foundation/, 'version mentions Parrot Foundation');
    ok($output ~~ /:s Artistic License/,  'version mentions Artistic License');
}

sub test_plumage_info() {
    my $output := qx($PLUMAGE, 'info', 'rakudo');
    ok($output ~~ /:s Perl 6 on Parrot/,     'info rakudo');
    ok($output ~~ /:s Name\s+\:\s+Rakudo/,   'info rakudo');
}

sub test_plumage_metadata() {
    my $output := qx($PLUMAGE, 'metadata', 'nqp-rx');
    ok($output ~~ /:s Not Quite Perl 6/, 'metadata nqp-rx');
    ok($output ~~ /dependency\-info/,    'metadata nqp-rx');
}
