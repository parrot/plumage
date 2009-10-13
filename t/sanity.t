#! parrot_nqp
our @ARGS;
MAIN();

sub MAIN () {
    my $num_tests := 8;
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
