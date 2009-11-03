#! nqp
our @ARGS;

MAIN();

sub MAIN () {
    my $num_tests := 9;
    pir::load_bytecode('src/lib/Glue.pbc');
    Q:PIR{
        .local pmc c
        load_language 'parrot'
        c = compreg 'parrot'
        c.'import'('Test::More')
    };
    plan($num_tests);
    test_exists();
    test_subst();
    test_join();
    test_split();
    test_path_exists();
}
sub test_path_exists() {
    ok(path_exists('.'),'path_exists finds .');
    nok(path_exists('DOESNOTEXIST'),'path_exists returns false for nonexistent files');
}

sub test_join() {
    is('a,b,c,d,e,f', join(',',('a','b','c','d','e','f')), 'join works');
}

sub test_split() {
    my @stuff := split('/', '1/5');
    is(@stuff[0],1,'split works');
    is(@stuff[1],5,'split works');
}

sub test_subst() {
    my $string := 'chewbacca';
    my $subst  := subst($string,rx('a'),'x');
    is($subst,'chewbxccx','substr works');
    is($string,'chewbacca','subst works on a clone');
}

sub test_exists() {
    my %opt;
    %opt<foobar> := 42;
    my $exists := exists(%opt, 'foobar');
    ok($exists, 'exists works for existing keys');
    $exists := exists(%opt, 'zanzibar');
    nok($exists, 'exists works for non-existent keys');
}
