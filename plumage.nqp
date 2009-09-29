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
our %VM;

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
    },
    "fetch"      : {
        "action" : "action_fetch",
        "args"   : "project"
    },
    "configure"  : {
        "action" : "action_configure",
        "args"   : "project"
    }
}
';
our %COMMANDS := fixup_commands(eval($_COMMANDS_JSON, 'data_json'));

my  $_ACTIONS_JSON := '
{
    "fetch"     : [ "git", "svn" ],
    "configure" : [ "perl5_configure" ]
}
';
our %ACTION;
load_helper_libraries();
fixup_sub_actions(eval($_ACTIONS_JSON, 'data_json'));

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

sub fixup_sub_actions (%actions) {
    my @stages := keys(%actions);

    for @stages {
        my $stage   := $_;
        my @actions := %actions{$stage};

        for @actions {
            my $sub_name := $stage ~ '_' ~ $_;
            my $sub      := Q:PIR {
                $P0 = find_lex '$sub_name'
                $S0 = $P0
                %r  = get_hll_global $S0
            };

	    if $sub {
	        %ACTION{$stage}{$_} := $sub;
            }
	    else {
	        die("Action sub '" ~ $sub_name ~ "' is missing!\n");
            }
        }
    }
}


###
### MAIN
###

sub MAIN () {
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

    info      <project>  Print info about a particular project
    fetch     <project>  Download source for a project
    configure <project>  Configure source for project (fetches first)

    version              Print program version and copyright
    usage                Print this usage info
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

sub metadata_valid (%info) {
    my %spec          := %info<meta-spec>;
    my $known_uri     := 'https://trac.parrot.org/parrot/wiki/ModuleEcosystem';
    my $known_version := 1;

    unless %spec && %spec<uri> {
        say("I don't understand this project's metadata at all.");
        return 0;
    }

    unless %spec<uri> eq $known_uri {
        say("This project's metadata specifies unknown metadata spec URI '"
            ~ %spec<uri> ~ "'.");
        return 0;
    }

    if    %spec<version> == $known_version {
        return 1;
    }
    elsif %spec<version>  > $known_version {
        say("This project's metadata is too new to parse; it is version "
            ~ %spec<version> ~ " and I only understand version "
            ~ $known_version ~ ".");
    }
    else {
        say("This project's metadata is too old to parse; it is version "
            ~ %spec<version> ~ " and I only understand version "
            ~ $known_version ~ ".");
    }

    return 0;
}


sub fetch_git ($project, $uri) {
    run('git', 'clone', $uri, $project);
}
sub fetch_svn ($project, $uri) {
    run('svn', 'checkout', $uri, $project);
}

sub action_fetch (@projects) {
    unless (@projects) {
        say('Please include the name of the project you wish info for.');
    }

    for @projects {
        my %info := get_project_metadata($_);
        if metadata_valid(%info) {
            my %repo   := %info<resources><repository>;
            my &action := %ACTION<fetch>{%repo<type>};

            &action($_, %repo<checkout_uri>);
        }
    }
}


sub configure_perl5_configure ($project, %conf) {
    my $cwd := cwd();
    chdir($project);

    my $perl5 := %VM<config><perl>;
    run($perl5, 'Configure.pl');

    chdir($cwd);
}

sub action_configure (@projects) {
    action_fetch(@projects);

    for @projects {
        my %info := get_project_metadata($_);
        if metadata_valid(%info) {
            my %conf   := %info<instructions><configure>;
            my &action := %ACTION<configure>{%conf<type>};

            &action($_, %conf);
        }
    }
}
