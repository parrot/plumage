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
# XXXX: The data_json parser is very strict!  No extra commas, pedantic
#       quoting, the works.  Whitespace is perhaps your only freedom.
my  $_COMMANDS_JSON := '
{
    "usage"      : {
        "action" : "action_usage",
        "args"   : "none"
    },
    "version"    : {
        "action" : "action_version",
        "args"   : "none"
    },
    "info"       : {
        "action" : "action_info",
        "args"   : "project"
    }
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
    # Convert action sub *names* into actual action subs
    Q:PIR{
        $P0 = find_lex '$commands'
        $P1 = iter $P0
      fixup_loop:
        unless $P1 goto fixup_loop_end
        $S0 = shift $P1
        $P2 = $P1[$S0]
        $S1 = $P2['action']
        $P3 = get_hll_global $S1
        $P2['action'] = $P3
        goto fixup_loop
      fixup_loop_end:
    };

    return $commands;
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
    my $command := 'usage';

    if (@ARGS) {
        $command := @ARGS.shift;
    }

    return $command;
}

sub execute_command ($command) {
    my $action := %COMMANDS{$command}<action>;

    if ($action) {
        $action(@ARGS);
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
    return
'Usage: ' ~ $PROGRAM_NAME ~ ' [<options>] <command> [<arguments>]

Available commands:

    info <project>   Print info about a particular project

    version          Print program version and copyright
    usage            Print this usage info
';
}


sub action_version () {
    print(version_info());
}

sub version_info () {
    my $version := '0';
    return
'This is Parrot Plumage, version ' ~ $version ~ '.

Copyright (C) 2009, Parrot Foundation.

This code is distributed under the terms of the Artistic License 2.0.
For more details, see the full text of the license in the LICENSE file
included in the Parrot Plumage source tree.
';
}


sub action_info (@projects) {
    unless (@projects) {
        say('Please include the name of the project you wish info for.');
    }

    for @projects {
        my $info := get_project_metadata($_);

        _dumper($info, 'INFO');
    }
}

sub get_project_metadata ($project) {
    load_bytecode('Config/JSON.pbc');

    return Config::JSON::ReadConfig('metadata/' ~ $project ~ '.json');
}
