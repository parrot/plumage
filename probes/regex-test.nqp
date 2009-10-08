###
### regex-test.nqp: Test workings of Perl6Regex objects
###

# TO USE:
#   $ parrot_nqp regex-test.nqp


# Load Glue module, which includes the regex compiler function rx()
load_bytecode('src/lib/Glue.pir');

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
