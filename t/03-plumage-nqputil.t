#!/usr/bin/env parrot-nqp

my $*EXECUTABLE_NAME;

MAIN();

sub MAIN() {
    # Load testing tools
    pir::load_language('parrot');
    pir::compreg__PS('parrot').import('Test::More');

    # Load library to be tested
    pir::load_bytecode('Plumage/NQPUtil.pbc');

    # Run all tests for this library
    run_tests();
}

sub run_tests() {
    plan(51);

    test_hash_exists();
    test_hash_keys();
    test_hash_values();
    test_hash_kv();
    test_hash();

    test_all_matches();

    test_set_from_array();

    test_subst();

    test_path_exists();
    test_is_dir();

    test_qx();
}

sub test_all_matches() {
    my @matches;
    @matches := all_matches(/ab?d?x?c/,"abc y adcef x axcfoo twiddle");

    is(@matches[0], 'abc', 'all_matches found abc');
    is(@matches[1], 'adc', 'all_matches found adc');
    is(@matches[2], 'axc', 'all_matches found axc');
}

sub test_hash() {
    my %hash := hash(monkey => 'see');
    my @kv   := %hash.kv;

    is(@kv[0], 'monkey', 'hash() creates the monkey key');
    is(@kv[1], 'see',    'hash() set the value of monkey correctly');

}

sub test_hash_exists() {
    my %opt;
    %opt<foobar> := 42;

    ok(%opt.exists('foobar'),    'exists works for existing keys');
    nok(%opt.exists('zanzibar'), 'exists works for non-existent keys');
}

sub test_hash_values() {
    my %hash;
    my @values := %hash.values;

    is(@values, 0, 'values on empty hash is empty');

    %hash<GreatJob> := 42;
    @values := %hash.values;

    is(@values,     1, 'values on hash with one entry has one element');
    is(@values[0], 42, '... and that element is correct');

    %hash<pigdog> := 99;

    is(%hash.values, 2, 'values on hash with two entries has two elements');
}

sub test_hash_keys() {
    my %hash;

    my @keys := %hash.keys;

    is(@keys, 0, 'keys on empty hash is empty');

    %hash<moof> := 42;
    @keys       := %hash.keys;

    is(@keys,    1,      'keys on hash with one entry has one element');
    is(@keys[0], 'moof', '... and that element is correct');

    %hash<dogcow> := "sloop";
    @keys         := %hash.keys;

    is(@keys,    2,          'keys on hash with two entries has two elements');
    ok(@keys[0] eq 'moof'
    || @keys[1] eq 'moof',   '... and the old key is there');
    ok(@keys[0] eq 'dogcow'
    || @keys[1] eq 'dogcow', '... and the new key is there');

    %hash<foo> := 1;
    %hash<bar> := 2;
    %hash<baz> := 3;
    @keys      := %hash.keys;

    is(@keys, 5, 'keys on hash with five entries has five elements');
}

sub test_hash_kv() {
    my %kv_hash;

    my @kv := %kv_hash.kv;

    is(@kv, 0, 'kv on empty hash is empty');

    %kv_hash<flux> := 13;
    @kv            := %kv_hash.kv;

    is(@kv,    2,      'kv on hash with one entry has two elements');
    is(@kv[0], 'flux', '... and the key is correct');
    is(@kv[1], 13,     '... and the value is correct');

    %kv_hash<romp> := "party";
    @kv            := %kv_hash.kv;

    is(@kv,    4,         'kv on hash with two entries has four elements');
    ok(@kv[0] eq 'flux'
    || @kv[2] eq 'flux',  '... and the old key is there');
    ok(@kv[0] eq 'romp'
    || @kv[2] eq 'romp',  '... and the new key is there');
    ok(@kv[1] eq 13
    || @kv[3] eq 13,      '... and the old value is there');
    ok(@kv[1] eq 'party'
    || @kv[3] eq 'party', '... and the new value is there');
    ok(@kv[0] eq 'flux' && @kv[1] eq '13'
    || @kv[2] eq 'flux' && @kv[3] eq '13',
                          'and the keys and values are matched');

    %kv_hash<uno> := 1;
    %kv_hash<two> := 2;
    %kv_hash<11>  := 3;
    @kv           := %kv_hash.kv;

    is(@kv, 10, 'kv on hash with five entries has ten elements');
}

sub test_set_from_array() {
    my @array;
    my %set  := set_from_array(@array);
    my @keys := %set.keys;

    is(@keys, 0, 'set_from_array on empty array produces empty set');

    @array := (1, "two", "two", 3, '3', 3);
    %set   := set_from_array(@array);
    @keys  := %set.keys;

    is(@keys,     3, 'set_from_array on array with dups has correct number of keys');
    is(%set<1>,   1, '... and first key is in set');
    is(%set<two>, 1, '... and second key is in set');
    is(%set<3>,   1, '... and third key is in set');

    nok(%set.exists('four'), '... and non-existant key is not in set');
}

sub test_subst() {
    my $string := 'chewbacca';
    my $subst  := subst($string, /a/, 'x');

    is($subst,  'chewbxccx', 'subst works with plain string replacement');
    is($string, 'chewbacca', 'plain string subst edits a clone');

    my $text  := 'wookie';
    my $fixed := subst($text, /w|k/, replacement);

    is($fixed, 'wwookkie', 'subst works with code replacement');
    is($text,  'wookie',   'code replacement subst edits a clone');
}

sub replacement($match) {
    my $orig := ~$match;

    return $orig ~ $orig;
}

sub test_path_exists() {
    ok(path_exists('.'),             'path_exists finds .');
    nok(path_exists('DOESNOTEXIST'), 'path_exists returns false for nonexistent files');
}

sub test_is_dir() {
    ok(is_dir('.'),             '. is a directory');
    nok(is_dir('DOESNOTEXIST'), 'is_dir returns false for nonexistent dirs');
    nok(is_dir('harness'),      'is_dir returns false for normal files');
}

sub test_qx() {
    my $output;
    my $!;

    is(qx(''), '', 'qx("") returns an empty string');

    $output := qx('IHOPETHATTHISPATHDOESNOTEXISTANDISEXECUTABLEANDRETURNSTRUE');

    ok($output ~~ /:s not [found|recognized]/, 'qx() on invalid path returns not found error');
    isnt($!, 0, '... and the exit status is non-zero');

    $output := qx($*EXECUTABLE_NAME, '-e', '"say(42); pir::exit(0)"');

    is($output, "42\n", 'qx() captures output of exit(0) program, retaining line endings');
    is($!,      0,      '... and the exit status is correct');

    $output := qx($*EXECUTABLE_NAME, '-e', '"say(21); pir::exit(1)"');

    is($output, "21\n", 'qx() captures output of exit(1) program, retaining line endings');
    is($!,      1,      '... and the exit status is correct');
}

# vim: ft=perl6
