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
        "action" : "command_usage",
        "args"   : "none"
    },
    "version"    : {
        "action" : "command_version",
        "args"   : "none"
    },
    "info"       : {
        "action" : "command_info",
        "args"   : "project"
    },
    "fetch"      : {
        "action" : "command_fetch",
        "args"   : "project"
    },
    "configure"  : {
        "action" : "command_configure",
        "args"   : "project"
    },
    "build"      : {
        "action" : "command_build",
        "args"   : "project"
    },
    "test"       : {
        "action" : "command_test",
        "args"   : "project"
    },
    "install"    : {
        "action" : "command_install",
        "args"   : "project"
    }
}
';
our %COMMANDS := fixup_commands(eval($_COMMANDS_JSON, 'data_json'));

my  $_ACTIONS_JSON := '
{
    "fetch"     : [ "git", "svn" ],
    "configure" : [ "perl5_configure", "parrot_configure" ],
    "build"     : [ "make" ],
    "test"      : [ "make" ],
    "install"   : [ "make" ]
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


our %STAGE_ACTION;
our %STAGES;
our %BIN;

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

sub find_binaries () {
    my %conf       := %VM<config>;
    my $parrot_bin := %conf<bindir>;

    %BIN<parrot_config> := fscat($parrot_bin, 'parrot_config');
}

sub build_stages () {
    my @stages := split(' ', 'install test build configure fetch');

    for @stages {
        my $stage       := $_;

        %STAGES{$stage} := split(' ', '');

        for keys(%STAGES) {
            %STAGES{$_}.unshift($stage);
        }

        my $sub_name := 'action_' ~ $stage;
        my $sub      := Q:PIR {
            $P0 = find_lex '$sub_name'
            $S0 = $P0
            %r  = get_hll_global $S0
        };
        %STAGE_ACTION{$stage} := $sub;
    }
}


###
### MAIN
###


sub MAIN () {
    find_binaries();
    build_stages();

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
    my $args   := %COMMANDS{$command}<args>;

    if ($action) {
        if $args eq 'project' && !@ARGS {
            say('Please include the name of the project you wish info for.');
        }
        else {
            $action(@ARGS);
        }
    }
    else {
        say("I don't know how to '" ~ $command ~ "'!");
    }
}


###
### COMMANDS
###


sub command_usage () {
    print(usage_info());
}

sub usage_info () {
    return
'Usage: ' ~ $PROGRAM_NAME ~ ' [<options>] <command> [<arguments>]

Available commands:

    info      <project>  Print info about a particular project
    fetch     <project>  Download source for a project
    configure <project>  Configure source for project (fetches first)
    build     <project>  Build project from source (configures first)
    test      <project>  Test built project (builds first)
    install   <project>  Installs built project files (tests first)

    version              Print program version and copyright
    usage                Print this usage info
';
}


sub command_version () {
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


sub command_info (@projects) {
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


sub command_fetch (@projects) {
    perform_actions_on_projects(%STAGES<fetch>, @projects);
}

sub command_configure (@projects) {
    perform_actions_on_projects(%STAGES<configure>, @projects);
}

sub command_build (@projects) {
    perform_actions_on_projects(%STAGES<build>, @projects);
}

sub command_test (@projects) {
    perform_actions_on_projects(%STAGES<test>, @projects);
}

sub command_install (@projects) {
    perform_actions_on_projects(%STAGES<install>, @projects);
}


sub perform_actions_on_projects (@actions, @projects) {
    for @projects {
        my %info := get_project_metadata($_);
        if %info {
            if metadata_valid(%info) {
                perform_actions_on_project(@actions, $_, %info);
            }
        }
        else {
            say("I don't know anything about project '" ~ $_ ~ "'.");
        }
    }
}

sub perform_actions_on_project (@actions, $project, %info) {
    for @actions {
        my &action := %STAGE_ACTION{$_};

        if &action {
           my $result := &action($project, %info);
           if $result {
               say('Successful.');
           }
           else {
               say("###\n### FAILED!\n###");
               return 0;
           }
        }
        else {
           say("I don't know how to perfom action '" ~ $_ ~ "'.");
        }
    }

    return 1;
}


###
### ACTIONS
###


# FETCH

sub action_fetch ($project, %info) {
    my %repo := %info<resources><repository>;
    if %repo {
        say("Fetching " ~ $project ~ ' ...');

        my &action := %ACTION<fetch>{%repo<type>};
        return &action($project, %repo<checkout_uri>);
    }
    else {
        say("Don't know how to fetch " ~ project ~ ".");
        return 0;
    }
}

sub fetch_git ($project, $uri) {
    return check_run_success(run('git', 'clone', $uri, $project));
}
sub fetch_svn ($project, $uri) {
    return check_run_success(run('svn', 'checkout', $uri, $project));
}


# CONFIGURE

sub action_configure ($project, %info) {
    my %conf := %info<instructions><configure>;
    if %conf {
        say("\nConfiguring " ~ $project ~ ' ...');

        my &action := %ACTION<configure>{%conf<type>};
        return &action($project, %conf);
    }
    else {
        say("\nConfiguration not required for " ~ $project ~ ".");
        return 1;
    }
}

sub configure_perl5_configure ($project, %conf) {
    my $cwd := cwd();
    chdir($project);

    my $perl5   := %VM<config><perl>;
    my $success := check_run_success(run($perl5, 'Configure.pl'));

    chdir($cwd);

    return $success;
}

sub configure_parrot_configure ($project, %conf) {
    my $cwd := cwd();
    chdir($project);

    my $parrot  := fscat(%VM<config><bindir>, 'parrot');
    my $success := check_run_success(run($parrot, 'Configure.pir'));

    chdir($cwd);

    return $success;
}


# MAKE

sub action_build ($project, %info) {
    my %conf := %info<instructions><build>;
    if %conf {
        say("\nBuilding " ~ $project ~ ' ...');

        my &action := %ACTION<build>{%conf<type>};
        return &action($project);
    }
    else {
        say("\nBuild not required for " ~ $project ~ ".");
        return 1;
    }
}

sub build_make ($project) {
    my $cwd := cwd();
    chdir($project);

    my $make    := %VM<config><make>;
    my $success := check_run_success(run($make));

    chdir($cwd);

    return $success;
}


# TEST

sub action_test ($project, %info) {
    my %conf := %info<instructions><test>;
    if %conf {
        say("\nTesting " ~ $project ~ ' ...');

        my &action := %ACTION<test>{%conf<type>};
        return &action($project);
    }
    else {
        say("\nNo test method found for " ~ $project ~ ".");
        return 1;
    }
}

sub test_make ($project) {
    my $cwd := cwd();
    chdir($project);

    my $make := %VM<config><make>;
    my $success := check_run_success(run($make, 'test'));

    chdir($cwd);

    return $success;
}


# INSTALL

sub action_install ($project, %info) {
    my %conf := %info<instructions><install>;
    if %conf {
        say("\nInstalling " ~ $project ~ ' ...');

        my &action := %ACTION<install>{%conf<type>};
        return &action($project);
    }
    else {
        say("Don't know how to install " ~ project ~ ".");
        return 0;
    }
}

sub install_make ($project) {
    my $cwd := cwd();
    chdir($project);

    my $make := %VM<config><make>;
    my $success := check_run_success(run($make, 'install'));

    chdir($cwd);

    return $success;
}


###
### UTILS
###


sub check_run_success ($exit_val) {
    return $exit_val ?? 0 !! 1;
}


sub replace_config_strings ($original) {
    return subst($original, '\#<ident>\#', config_value);
}

sub config_value ($match) {
    my $key    := $match<ident>;
    my $config := %VM<config>{$key} || %BIN{$key} || '';

    return $config;
}
