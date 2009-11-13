#! parrot-nqp

MAIN();

sub MAIN () {
    # Load testing tools
    pir::load_language('parrot');
    pir::compreg__PS('parrot').import('Test::More');

    # Load glue library to get qx()
    pir::load_bytecode('src/lib/Glue.pbc');

    # Run all tests for this library
    run_tests();
}

sub run_tests () {
    plan(18);

    test_invalid();
    test_version();
    test_plumage_invalid();
    test_plumage_usage();
    test_plumage_info();
    test_plumage_info_invalid();
    test_plumage_build_invalid();
    test_plumage_test_invalid();
    test_plumage_configure_invalid();
    test_plumage_install_invalid();
    test_plumage_no_args();
    test_plumage_fetch_no_args();
}

sub test_plumage_no_args() {
    my $output := qx('./plumage');
    like($output, ':s Print program version and copyright',   'no args give usage');
    like($output, ':s Print info about a particular project', 'no args give usage');
}

sub test_plumage_fetch_no_args() {
    my $output := qx('./plumage', 'fetch');
    like($output, ':s Please include the name of the project you wish info for', 'plumage fetch no args');
}

sub test_plumage_info() {
    my $output := qx('./plumage', 'info', 'rakudo');
    like($output, ':s Perl 6 on Parrot', 'info rakudo');
    like($output, 'dependency\-info',    'info rakudo');
}

sub test_plumage_configure_invalid() {
    my $output := qx('./plumage', 'configure', 'coboloncogs');
    like($output, ':s I don.t know anything about project .coboloncogs.');
}

sub test_plumage_install_invalid() {
    my $output := qx('./plumage', 'install', 'coboloncogs');
    like($output, ':s I don.t know anything about project .coboloncogs.');
}

sub test_plumage_info_invalid() {
    my $output := qx('./plumage', 'info', 'coboloncogs');
    like($output, ':s I don.t know anything about project .coboloncogs.');
}

sub test_plumage_build_invalid() {
    my $output := qx('./plumage', 'build', 'coboloncogs');
    like($output, ':s I don.t know anything about project .coboloncogs.');
}

sub test_plumage_test_invalid() {
    my $output := qx('./plumage', 'test', 'coboloncogs');
    like($output, ':s I don.t know anything about project .coboloncogs.');
}

sub test_invalid() {
    my $success := do_run('invalidjunkdoesnotexist');
    nok($success, 'do_run()ing invalidjunk returns false');
}

sub test_version() {
    my $success := do_run('./plumage', 'version');
    ok($success, 'plumage version returns success');

    my $output := qx('./plumage', 'version');
    like($output, ':s Parrot Plumage',    'plumage version knows its name');
    like($output, ':s Parrot Foundation', 'version mentions Parrot Foundation');
    like($output, ':s Artistic License',  'version mentions Artistic License');
}
sub test_plumage_usage() {
    my $output := qx('./plumage', 'usage');
    like($output, ':s Print program version and copyright');
    like($output, ':s Print info about a particular project');
}

sub test_plumage_invalid() {
    my $success := do_run('./plumage', 'asdfversion');
    nok($success, 'plumage returns failure for invalid commands');
}
