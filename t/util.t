#! nqp

MAIN();

sub MAIN () {
    # Load testing tools
    pir::load_language('parrot');
    pir::compreg__PS('parrot').import('Test::More');

    # Load library to be tested
    pir::load_bytecode('src/lib/Util.pbc');

    # Run all tests for this library
    run_tests();
}

sub run_tests () {
    plan(2);

    test_exists();
}

sub test_exists() {
    my %opt;
    %opt<foobar> := 42;

    ok( %opt.exists('foobar'),   'exists works for existing keys');
    nok(%opt.exists('zanzibar'), 'exists works for non-existent keys');
}
