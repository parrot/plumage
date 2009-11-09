###
### hash-kv.nqp: CAN HAZ 'for %hash.kv -> $k, $v { ... }' ?
###

# TO USE:
#   $ nqp hash-kv.nqp

# Original Hash.kv by pmichaud++ in http://nopaste.snit.ch/18559;
# updated to handle new-style hash iteration semantics
module Hash {
    method kv () {
        my @kv;
        for self { @kv.push($_.key); @kv.push($_.value); }
        @kv;
    }
}

my %hash;

%hash<a> := 1;
%hash<b> := 2;
%hash<c> := 3;

for %hash.kv -> $k, $v {
    say($k ~ "\t" ~ $v);
}
