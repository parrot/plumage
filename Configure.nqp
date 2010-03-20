# Purpose: Use Parrot's config info to configure our Makefile.
#
# Usage:
#     nqp Configure.nqp [input_makefile [output_makefile]]
#
# input_makefile  defaults to 'src/Makefile.in';
# output_makefile defaults to 'Makefile'.

my $*OSNAME;
my @*ARGS;
my %*VM;

MAIN();

sub MAIN () {
    # Wave to the friendly users
    say("Hello, I'm Configure. My job is to poke and prod\nyour system to figure out how to build Plumage.\n");

    # Load utility functions
    pir::load_bytecode('src/lib/Plumage/NQPUtil.pir');

    # Slurp in the unconfigured Makefile text
    my $unconfigured := slurp(@*ARGS[0] || 'src/Makefile.in');

    # Replace all of the @foo@ markers
    my $replaced := subst($unconfigured, /\@<ident>\@/, replacement);

    # Fix paths on Windows
    if ($*OSNAME eq 'MSWin32') {
        $replaced := subst($replaced, /'\/'/,     '\\'   );
        $replaced := subst($replaced, /'\\\\\*'/, '\\\\*');
    }

    # Spew out the final makefile
    spew(@*ARGS[1] || 'Makefile', $replaced);

    # Give the user a hint of next action
    my $make := %*VM<config><make>;
    say("Configure completed for platform '$*OSNAME'.");
    say("You can now type '$make' to build Plumage.\n");
    say("You may also type '$make test' to run the Plumage test suite.\n");
    say("Happy Hacking,\n\tThe Plumage Team\n");
}

sub replacement ($match) {
    my $key    := $match<ident>;
    my $config := %*VM<config>{$key} || '';

    return $config;
}
