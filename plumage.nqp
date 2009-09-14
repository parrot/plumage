###
### HACKS
###

# NQP bug XXXX: Fakecutables broken because 'nqp' language is not loaded.
Q:PIR{
    $P0 = get_hll_global 'say'
  unless null $P0 goto got_nqp
    load_language 'nqp'
  got_nqp:
};

# NQP bug XXXX: Must redeclare PIR globals because the NQP parser can't
#               know about variables created at load_bytecode time.
our $PROGRAM_NAME;
our @ARGS;

# NQP doesn't support array or hash literals, so parse main structure
# from JSON and then fix up values that can't be represented in JSON.
#
# NOTE: The data_json parser is very strict!  No extra commas, pedantic
#       quoting, the works.  Whitespace is perhaps your only freedom.
my  $_COMMANDS_JSON := '
{
    "usage"  : "action_usage",
    "version": "action_version"
}
';
our %COMMANDS := fixup_commands(eval($_COMMANDS_JSON, 'data_json'));

# NQP does not automatically call MAIN()
MAIN();


###
### INIT
###

sub load_helper_libraries () {
    # Globals, common functions, system access, etc.
    load_bytecode('Glue.pir');

    # Data structure dumper for PMCs (used for debugging)
    load_bytecode('dumper.pbc');
}

sub fixup_commands ($commands) {
    $commands<usage>   := action_usage;
    $commands<version> := action_version;

    return($commands);
}


###
### MAIN
###

sub MAIN () {
    load_helper_libraries();

    my $command := parse_command_line();

    execute_command($command);
}

sub parse_command_line () {
    my $command := @ARGS ?? @ARGS[0] !! 'usage';

    return $command;
}

sub execute_command ($command) {
    my $action := %COMMANDS{$command};

    if ($action) {
	$action();
    }
    else {
	say("I don't know how to '" ~ $command ~ "'!");
    }
}


###
### COMMANDS
###


sub action_usage () {
    print(usage_info());
}

sub usage_info () {
    return (
'Usage: ' ~ $PROGRAM_NAME ~ ' [<options>] <command> [<arguments>]

Available commands:

    version   Print program version and copyright
    usage     Print this usage info
');
}


sub action_version () {
    print(version_info());
}

sub version_info () {
    my $version := '0';
    return (
'This is Parrot Plumage, version ' ~ $version ~ '.

Copyright (C) 2009, Parrot Foundation.

This code is distributed under the terms of the Artistic License 2.0.
For more details, see the full text of the license in the LICENSE file
included in the Parrot Plumage source tree.
');
}
