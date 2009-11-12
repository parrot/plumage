#! parrot-nqp

MAIN();

sub MAIN () {
    # Load testing tools
    pir::load_language('parrot');
    pir::compreg__PS('parrot').import('Test::More');

    # Run basic tests of testing
    run_tests();
}

sub run_tests () {
    plan(5);

    test_testing();
}

sub test_testing() {
    ok(   1,          'ok works');
    nok(  0,          'nok works');
    is(   5,     5,   'is works for ints');
    is(  'z',   'z',  'is works for strings');
    like('bar', 'ar', 'like works for simple substrings');
}
