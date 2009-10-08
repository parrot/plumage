our @ARGS;
MAIN();

sub MAIN () {
    load_bytecode('src/lib/Glue.pir');
    my $status := run('plumage');
    say("1..2");
    if ($status == 0) {
        say("ok 1");
    } else {
        say("not ok 1");
    }
    say("ok 2");
}
