###
### json-test.nqp: Test behavior of the JSON parsing language (data_json)
###

# TO USE:
#   $ parrot-nqp json-test.nqp


# First, load the Parrot data structure dumper module
pir::load_bytecode('dumper.pbc');

# All of the crazy testing
my @tests := (
              # Basic sanity checks
              '"Hello from JSON"',
              '[1,2,3]',
              '{"a":1,"b":2}',

              # Null becomes undef by itself,
              # but null in an array or object
              'null',
              '[null]',
              '{"a":null}',

              # Booleans get converted to 1/0
              '{"true": true, "false": false}',

              # Duplicate keys silently overwrite!
              '{"a":1, "a":"bar"}',

              # Complex test
              '{"config":{"a":1,"b":2.4e-2,"c":"foo","d":{"1":11,"2":22},"e":[4,5,6],"f":true,"g":false,"h":null}}'
             );

# Iterate over test strings, showing original and roundtripped version
for @tests {
    say("\nOriginal:     " ~ $_);
    print("Roundtripped: ");

    my $rt := eval($_, 'data_json');
    _dumper($rt, 'JSON');
}
