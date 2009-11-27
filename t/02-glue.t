#! parrot-nqp

my $*EXECUTABLE_NAME;

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
    plan(13);

    test_subst();
    test_path_exists();
    test_qx();
}

sub test_path_exists() {
    ok( path_exists('.'),            'path_exists finds .');
    nok(path_exists('DOESNOTEXIST'), 'path_exists returns false for nonexistent files');
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

sub test_qx() {
    my $output;
    my $!;

    is(qx(''), '', 'qx("") returns an empty string');

    $output := qx('IHOPETHATTHISPATHDOESNOTEXISTANDISEXECUTABLEANDRETURNSTRUE');
    like($output, ':s not (found|recognized)','qx() on invalid path returns not found error');
    isnt($!, 0, '... and the exit status is non-zero');

    $output := qx($*EXECUTABLE_NAME, '-e', '"say(42); pir::exit(0)"');
    is($output, "42\n", 'qx() captures output of exit(0) program, retaining line endings');
    is($!,      0,      '... and the exit status is correct');

    $output := qx($*EXECUTABLE_NAME, '-e', '"say(21); pir::exit(1)"');
    is($output, "21\n", 'qx() captures output of exit(1) program, retaining line endings');
    is($!,      1,      '... and the exit status is correct');
}
