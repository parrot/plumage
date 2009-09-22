# Purpose: Use Parrot's config info to configure our Makefile.
#
# Usage:
#     parrot_nqp Configure.nqp [input_makefile [output_makefile]]
#
# input_makefile  defaults to 'Makefile.in';
# output_makefile defaults to 'Makefile'.

our @ARGS;
our %VM;
our $OS;

MAIN();

sub MAIN () {
    # Load Parrot config and glue functions
    load_bytecode('Glue.pir');

    # Slurp in the unconfigured Makefile text
    my $unconfigured := slurp(@ARGS[0] || 'Makefile.in');

    # Replace all of the @foo@ markers
    my $replaced := subst($unconfigured, '\@<ident>\@', replacement);

    # Fix paths on Windows
    if ($OS eq 'MSWin32') {
        $replaced := subst($replaced, '/', '\\');
    }

    # Spew out the final makefile
    spew(@ARGS[1] || 'Makefile', $replaced);

    # Give the user a hint of next action
    say("Configure completed for platform '" ~ $OS ~ "'.");
    say("You probably want to run '" ~ %VM<config><make> ~ "' next.");
}

sub replacement ($match) {
    my $key    := $match<ident>;
    my $config := %VM<config>{$key} || '';

    return $config;
}
