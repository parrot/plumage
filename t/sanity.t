#! parrot_nqp
our @ARGS;
MAIN();

sub MAIN () {
    my $num_tests := 3;
    load_bytecode('src/lib/Glue.pbc');
    load_bytecode('Test/More.pbc');
    plan($num_tests);

    test_invalid();
    test_version();
    test_plumage_invalid();
}

sub test_invalid() {
    my $status := run('invalidjunkdoesnotexist');
    ok($status == 255); #,'invalidjunk returns false');
}

sub test_version() {
    my $status := run('./plumage','version');
    ok(!$status); # ,'plumage version returns true');
}

sub test_plumage_invalid() {
    my $status := run('./plumage','asdfversion');
    ok($status == 1) #,'plumage returns false for invalid stuff');
}
