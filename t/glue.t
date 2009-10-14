#! parrot_nqp
our @ARGS;

MAIN();

sub MAIN () {
    my $num_tests := 4;
    load_bytecode('src/lib/Glue.pbc');
    Q:PIR{
        .local pmc c
        load_language 'parrot'
        c = compreg 'parrot'
        c.'import'('Test::More')
    };
    plan($num_tests);
    test_exists();
    test_subst();
}
sub test_subst() {
    my $string := 'chewbacca';
    my $subst  := subst($string,rx('a'),'x');
    is($subst,'chewbxccx');
    is($string,'chewbacca'); # does it on a clone
}

sub test_exists() {
    my %opt;
    %opt<foobar> := 42;
    my $exists := exists(%opt, 'foobar');
    ok($exists);
    $exists := exists(%opt, 'zanzibar');
    nok($exists);
}
