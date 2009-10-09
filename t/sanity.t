our @ARGS;
MAIN();

sub MAIN () {
    load_bytecode('src/lib/Glue.pir');
    my $status := run('plumage');
    my $num_tests := 2;
    say("1.." ~ $num_tests);
    if ($status =:= 0) {
        say("ok 1 # running plumage with no args returns success");
    } else {
        say("not ok 1 # got status=" ~ $status);
    }
    say("ok 2");
}
