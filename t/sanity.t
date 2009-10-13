#! parrot_nqp
our @ARGS;
MAIN();

sub MAIN () {
    my $num_tests := 18;
    load_bytecode('src/lib/Glue.pbc');
    Q:PIR{
        .local pmc c
        load_language 'parrot'
        c = compreg 'parrot'
        c.'import'('Test::More')
    };
    plan($num_tests);

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
    like($output,':s Print program version and copyright');
    like($output,':s Print info about a particular project');
}

sub test_plumage_fetch_no_args() {
    my $output := qx('./plumage','fetch');
    like($output,':s Please include the name of the project you wish info for');
}

sub test_plumage_info() {
    my $output := qx('./plumage','info','rakudo');
    like($output,':s Perl 6 on Parrot');
    like($output,'dependency\-info');
}

sub test_plumage_configure_invalid() {
    my $output := qx('./plumage','configure','coboloncogs');
    like($output,':s I don.t know anything about project .coboloncogs.');
}

sub test_plumage_install_invalid() {
    my $output := qx('./plumage','install','coboloncogs');
    like($output,':s I don.t know anything about project .coboloncogs.');
}

sub test_plumage_info_invalid() {
    my $output := qx('./plumage','info','coboloncogs');
    like($output,':s I don.t know anything about project .coboloncogs.');
}

sub test_plumage_build_invalid() {
    my $output := qx('./plumage','build','coboloncogs');
    like($output,':s I don.t know anything about project .coboloncogs.');
}

sub test_plumage_test_invalid() {
    my $output := qx('./plumage','test','coboloncogs');
    like($output,':s I don.t know anything about project .coboloncogs.');
}

sub test_invalid() {
    my $status := run('invalidjunkdoesnotexist');
    ok($status == 255); #,'invalidjunk returns false');
}

sub test_version() {
    my $status := run('./plumage','version');
    ok(!$status); # ,'plumage version returns true');

    my $output := qx('./plumage','version');
    like($output,':s Parrot Plumage');
    like($output,':s Parrot Foundation');
    like($output,':s Artistic License');
}
sub test_plumage_usage() {
    my $output := qx('./plumage','usage');
    like($output,':s Print program version and copyright');
    like($output,':s Print info about a particular project');
}

sub test_plumage_invalid() {
    my $status := run('./plumage','asdfversion');
    ok($status == 1) #,'plumage returns false for invalid stuff');
}
