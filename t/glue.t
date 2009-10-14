#! parrot_nqp
our @ARGS;

MAIN();

sub MAIN () {
    my $num_tests := 2;
    load_bytecode('src/lib/Glue.pbc');
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
    my $exists := exists(%opt, 'foobar');
    ok($exists);
    $exists := exists(%opt, 'zanzibar');
    nok($exists);
}
