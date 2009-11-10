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
    plan(26);

    test_hash_exists();
    test_hash_keys();
    test_hash_kv();

    test_set_from_array();
}

sub test_hash_exists() {
    my %opt;
    %opt<foobar> := 42;

    ok( %opt.exists('foobar'),   'exists works for existing keys');
    nok(%opt.exists('zanzibar'), 'exists works for non-existent keys');
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
