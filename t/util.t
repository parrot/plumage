#! nqp
our @ARGS;

MAIN();

sub MAIN () {
    my $num_tests := 2;
    pir::load_bytecode('src/lib/Util.pbc');
    Q:PIR{
        .local pmc c
        load_language 'parrot'
        c = compreg 'parrot'
        c.'import'('Test::More')
    };
    plan($num_tests);
    test_exists();
}

sub test_exists() {
    my %opt;
    %opt<foobar> := 42;
    my $exists := %opt.exists('foobar');
    ok($exists, 'exists works for existing keys');
    $exists := %opt.exists('zanzibar');
    nok($exists, 'exists works for non-existent keys');
}
