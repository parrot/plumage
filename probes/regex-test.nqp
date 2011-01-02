###
### regex-test.nqp: Test workings of Perl6Regex objects
###

# TO USE:
#   $ parrot-nqp regex-test.nqp


# Load Plumage::NQPUtil module, which includes the regex helper functions
pir::load_bytecode('Plumage/NQPUtil.pbc');

# Load data structure dumper
pir::load_bytecode('dumper.pbc');

# Wheee, probe testing ...
my $regex_object    := /b+c/;
my $string_to_match := 'aaabbbcccddd  aa bb cc dd  abcd';
_dumper(all_matches($regex_object, $string_to_match), 'ALL');
