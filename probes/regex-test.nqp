###
### regex-test.nqp: Test workings of Perl6Regex objects
###

# TO USE:
#   $ parrot-nqp regex-test.nqp


# Load Glue module, which includes the regex helper functions
pir::load_bytecode('src/lib/Glue.pir');

# Load data structure dumper
pir::load_bytecode('dumper.pbc');

# Wheee, probe testing ...
my $regex_source    := 'b+c';
my $regex_object    := rx($regex_source);
my $string_to_match := 'aaabbbcccddd  aa bb cc dd  abcd';
my $match_object    := $regex_object($string_to_match);

say($match_object);
say($match_object.to());

# "Go to next match"
$match_object := $regex_object($match_object, :continue($match_object.to()));

say($match_object);

# Let's look at the entire match structure now
_dumper(all_matches($regex_object, $string_to_match), 'ALL');
