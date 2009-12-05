#! parrot-nqp

our $PLUMAGE;

MAIN();

sub MAIN () {
    # Load testing tools
    pir::load_language('parrot');
    pir::compreg__PS('parrot').import('Test::More');

    # Load glue library to get qx()
    pir::load_bytecode('src/lib/Glue.pbc');

    # Set correct path for plumage binary
    $PLUMAGE := fscat(['.'], 'plumage');

    # Run all sanity tests for plumage
    run_tests();
}

sub run_tests () {
    plan(18);

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
}


#
# FUZZ TESTS
#

sub test_invalid() {
    my $success := do_run('invalidjunkdoesnotexist');
    nok($success, 'do_run()ing invalidjunk returns false');
}

sub test_plumage_invalid() {
    my $success := do_run($PLUMAGE, 'asdfversion');
    nok($success, 'plumage returns failure for invalid commands');
}

sub test_plumage_info_invalid() {
    my $output := qx($PLUMAGE, 'info', 'coboloncogs');
    like($output, ':s I don.t know anything about project .coboloncogs.');
}

sub test_plumage_configure_invalid() {
    my $output := qx($PLUMAGE, 'configure', 'coboloncogs');
    like($output, ':s I don.t know anything about project .coboloncogs.');
}

sub test_plumage_build_invalid() {
    my $output := qx($PLUMAGE, 'build', 'coboloncogs');
    like($output, ':s I don.t know anything about project .coboloncogs.');
}

sub test_plumage_test_invalid() {
    my $output := qx($PLUMAGE, 'test', 'coboloncogs');
    like($output, ':s I don.t know anything about project .coboloncogs.');
}

sub test_plumage_install_invalid() {
    my $output := qx($PLUMAGE, 'install', 'coboloncogs');
    like($output, ':s I don.t know anything about project .coboloncogs.');
}


#
# MISSING ARGUMENT TESTS
#

sub test_plumage_no_args() {
    my $output := qx($PLUMAGE);
    like($output, ':s Print program version and copyright',   'no args give usage');
    like($output, ':s Print info about a particular project', 'no args give usage');
}

sub test_plumage_fetch_no_args() {
    my $output := qx($PLUMAGE, 'fetch');
    like($output, ':s Please specify a project to act on.', 'plumage fetch no args');
}


#
# BEHAVIOR TESTS
#

sub test_plumage_usage() {
    my $output := qx($PLUMAGE, 'usage');
    like($output, ':s Print program version and copyright');
    like($output, ':s Print info about a particular project');
}

sub test_plumage_version() {
    my $success := do_run($PLUMAGE, 'version');
    ok($success, 'plumage version returns success');

    my $output := qx($PLUMAGE, 'version');
    like($output, ':s Parrot Plumage',    'plumage version knows its name');
    like($output, ':s Parrot Foundation', 'version mentions Parrot Foundation');
    like($output, ':s Artistic License',  'version mentions Artistic License');
}

sub test_plumage_info() {
    my $output := qx($PLUMAGE, 'info', 'rakudo');
    like($output, ':s Perl 6 on Parrot', 'info rakudo');
    like($output, 'dependency\-info',    'info rakudo');
}
