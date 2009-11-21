#! parrot-nqp

MAIN();

sub MAIN () {
    # Load testing tools
    pir::load_language('parrot');
    pir::compreg__PS('parrot').import('Test::More');

    # Load library to be tested
    pir::load_bytecode('src/lib/Glue.pbc');

    # Run all tests for this library
    run_tests();
}

sub run_tests () {
    plan(20);

    test_subst();
    test_join();
    test_split();
    test_path_exists();
    test_qx();
}

sub test_qx() {
    my $cmd := '/bin/true';
    my $output := qx($cmd);
    nok(qx(''),'qx() on the empty string returns false');

    $output := qx('IHOPETHATTHISPATHDOESNOTEXISTANDISEXECUTABLEANDRETURNSTRUE');
    like($output, ':s command not found','qx() on invalid path returns false');
    ok($output, 'qx() on /bin/true returns a truthy value');
}
sub test_path_exists() {
    ok( path_exists('.'),            'path_exists finds .');
    nok(path_exists('DOESNOTEXIST'), 'path_exists returns false for nonexistent files');
}

sub test_join() {
    is('a,b,c,d,e,f', join(',', ('a','b','c','d','e','f')), 'join works');
}

sub test_split() {
    my @stuff := split('/', '1/5/7');
    is(@stuff,    3, 'split produces the correct result count');
    is(@stuff[0], 1, 'split produces correct result values');
    is(@stuff[1], 5, 'split produces correct result values');
    is(@stuff[2], 7, 'split produces correct result values');

    my @things := split(':', ':a::b:');
    is(@things,    5,   'split produces the correct result count');
    is(@things[0], '',  'split produces correct result values');
    is(@things[1], 'a', 'split produces correct result values');
    is(@things[2], '',  'split produces correct result values');
    is(@things[3], 'b', 'split produces correct result values');
    is(@things[4], '',  'split produces correct result values');
}

sub test_subst() {
    my $string := 'chewbacca';
    my $subst  := subst($string, rx('a'), 'x');
    is($subst,  'chewbxccx', 'subst works with plain string replacement');
    is($string, 'chewbacca', 'plain string subst edits a clone');

    my $text  := 'wookie';
    my $fixed := subst($text, rx('w|k'), replacement);
    is($fixed, 'wwookkie', 'subst works with code replacement');
    is($text,  'wookie',   'code replacement subst edits a clone');
}

sub replacement($match) {
    my $orig := ~$match;

    return $orig ~ $orig;
}
