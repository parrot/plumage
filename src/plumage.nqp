###
### HACKS
###


# NQP bug XXXX: Must redeclare PIR globals because the NQP parser can't
#               know about variables created at load_bytecode time.
our $PROGRAM_NAME;
our @ARGS;
our %ENV;
our %VM;
our $OS;

# Need to load helper libraries before even eval() is available
load_helper_libraries();

# NQP doesn't support array or hash literals, so parse main structure
# from JSON and then fix up values that can't be represented in JSON.
#
# NOTE: The data_json parser is very strict!  No extra commas, pedantic
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
    "projects"   : {
        "action" : "command_projects",
        "args"   : "none"
    },
    "status"   : {
        "action" : "command_status",
        "args"   : "opt_project"
    },
    "info"       : {
        "action" : "command_info",
        "args"   : "project"
    },
    "showdeps"   : {
        "action" : "command_showdeps",
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
    "fetch"     : [ "repository", "git", "svn" ],
    "configure" : [ "perl5_configure", "parrot_configure", "nqp_configure" ],
    "build"     : [ "make", "parrot_setup" ],
    "test"      : [ "make", "parrot_setup" ],
    "install"   : [ "make", "parrot_setup" ]
}
';
our %ACTION;
fixup_sub_actions(eval($_ACTIONS_JSON, 'data_json'));

my $_DEFAULT_CONF_JSON := '
{
    "parrot_user_root"     : "#user_home_dir#/.parrot",
    "plumage_user_root"    : "#parrot_user_root#/plumage",
    "plumage_build_root"   : "#plumage_user_root#/build",
    "plumage_metadata_dir" : "metadata",
    "installed_list_file"  : "#plumage_user_root#/installed_projects.list",
    "root_command"         : "sudo"
}
';

# NQP does not automatically call MAIN()
MAIN();


###
### INIT
###


our %STAGE_ACTION;
our %STAGES;
our %BIN;
our %OPT;
our %CONF;

sub load_helper_libraries () {
    # Globals, common functions, system access, etc.
    pir::load_bytecode('src/lib/Glue.pbc');

    # Utility functions written in NQP
    pir::load_bytecode('src/lib/Util.pbc');

    # Process command line options
    pir::load_bytecode('Getopt/Obj.pbc');

    # Parse files in JSON format
    pir::load_bytecode('Config/JSON.pbc');

    # Data structure dumper for PMCs (used for debugging)
    pir::load_bytecode('dumper.pbc');

    # Plumage metadata functions
    pir::load_bytecode('src/lib/Metadata.pbc');
}

sub fixup_commands ($commands) {
    # Convert action sub *names* into actual action subs
    for $commands.kv -> $cmd, $opts {
        $opts<action> := pir::get_hll_global__Ps($opts<action>);
    }

    return $commands;
}

sub fixup_sub_actions (%actions) {
    my @stages := %actions.keys;

    for @stages -> $stage {
        my @actions := %actions{$stage};

        for @actions -> $action {
            my $sub_name := $stage ~ '_' ~ $action;
            my $sub      := pir::get_hll_global__Ps($sub_name);

            if $sub {
                %ACTION{$stage}{$action} := $sub;
            }
            else {
                die("Action sub '$sub_name' is missing!\n");
            }
        }
    }
}

sub parse_command_line_options () {
    my $getopts := Q:PIR{ %r = root_new ['parrot';'Getopt::Obj'] };

    $getopts.push_string('config-file=s');
    $getopts.push_string('ignore-fail:%');

    %OPT := $getopts.get_options(@ARGS);
}

sub read_config_files () {
    # Find config files for this system and user (ignored if missing).
    my $etc      := %VM<conf><sysconfdir>;
    my $home     := user_home_dir();
    my $base     := 'plumage.json';
    my $sysconf  := fscat([$etc,  'parrot', 'plumage'], $base);
    my $userconf := fscat([$home, 'parrot', 'plumage'], $base);
    my @configs  := ($sysconf, $userconf);

    # Remember home dir, we'll need that later
    %CONF<user_home_dir> := $home;

    # If another config specified via command line option, add it.  Because
    # this was manually set by the user, it is a fatal error if missing.
    my $optconf  := %OPT<config-file>;
    if $optconf {
        if path_exists($optconf) {
            @configs.push($optconf);
        }
        else {
            die("Could not find config file '$optconf'.\n");
        }
    }

    # Merge together default, system, user, and option configs
    my %default := eval($_DEFAULT_CONF_JSON, 'data_json');
    %CONF := merge_tree_structures(%CONF, %default);

    for @configs -> $config {
        if path_exists($config) {
            my %conf := try(Config::JSON::ReadConfig, [$config]);
            if %conf {
                %CONF := merge_tree_structures(%CONF, %conf);
            }
            else {
                say("Could not parse JSON file '$config'.");
            }
        }
    }

    # _dumper(%CONF, 'CONF');
}

sub merge_tree_structures ($dst, $src) {
    for $src.keys -> $k {
        my $d := $dst{$k};
        my $s := $src{$k};

        if  $d && does($d, 'hash')
        &&  $s && does($s, 'hash') {
            $dst{$k} := merge_tree_structures($d, $s);
        }
        else {
            $dst{$k} := $s;
        }
    }

    return $dst;
}

sub find_binaries () {
    my %conf       := %VM<config>;
    my $parrot_bin := %conf<bindir>;

    %BIN<parrot_config> := fscat([$parrot_bin], 'parrot_config');

    %BIN<perl5> := %conf<perl>;
    %BIN<make>  := %conf<make>;

    %BIN<svn>   := find_program('svn');
    %BIN<git>   := find_program('git');
}

sub build_stages () {
    my @stages := split(' ', 'install test build configure fetch');

    for @stages -> $stage {
        %STAGES{$stage} := [];

        for %STAGES {
            $_.value.unshift($stage);
        }

        my $sub_name := "action_$stage";
        my $sub      := pir::get_hll_global__Ps($sub_name);

        %STAGE_ACTION{$stage} := $sub;
    }
}


###
### MAIN
###


sub MAIN () {
    parse_command_line_options();
    read_config_files();
    find_binaries();
    build_stages();

    my $command := parse_command_line();

    execute_command($command);
}

sub parse_command_line () {
    my $command := @ARGS ?? @ARGS.shift !! 'usage';

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
        say("I don't know how to '$command'!");
        pir::exit(1);
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
"Usage: $PROGRAM_NAME [<options>] <command> [<arguments>]

Options:

    --config-file=<path>     Read additional config file

    --ignore-fail            Ignore any failing build stages
    --ignore-fail=<stage>    Ignore failures only in a particular stage
                             (may be repeated to select more than one stage)
    --ignore-fail=<stage>=0  Don't ignore failures in this stage

Commands:

    projects             List all known projects
    status   [<project>] Show status of projects (defaults to all)
    info      <project>  Print info about a particular project
    showdeps  <project>  Show dependency resolution for a project

    fetch     <project>  Download source for a project
    configure <project>  Configure source for project (fetches first)
    build     <project>  Build project from source (configures first)
    test      <project>  Test built project (builds first)
    install   <project>  Installs built project files (tests first)

    version              Print program version and copyright
    usage                Print this usage info
";
}


sub command_version () {
    print(version_info());
}

sub version_info () {
    my $version := '0';
    return
"This is Parrot Plumage, version $version.

Copyright (C) 2009, Parrot Foundation.

This code is distributed under the terms of the Artistic License 2.0.
For more details, see the full text of the license in the LICENSE file
included in the Parrot Plumage source tree.
";
}


sub command_projects () {
    my @projects := get_project_list();

    say("\nKnown projects:\n");

    for @projects -> $project {
        my $desc := '';

        my %info := get_project_metadata($project, 0);
        if %info && metadata_valid(%info) {
            my %general := %info<general>;
            if %general {
                my $abstract := %general<abstract>;

                $desc := " - $abstract" if $abstract;
            }
        }

        say("    $project$desc");
    }

    say('');
}


sub command_status () {
    my @projects  := get_project_list();
    my @installed := get_installed_projects();
    my %installed := set_from_array(@installed);

    say("\nKnown projects:\n");

    for @projects -> $project {
        my $status := %installed{$project} ?? 'installed' !! '-';
        my $output := pir::sprintf__SsP("    %-30s   %s", [$project, $status]);
        say($output);
    }

    say('');
}


sub command_info (@projects) {
    unless (@projects) {
        say('Please include the name of the project you wish info for.');
    }

    for @projects -> $project {
        my %info := get_project_metadata($project, 0);

        _dumper(%info, 'INFO') if %info;
    }
}


sub command_showdeps (@projects) {
    unless (@projects) {
        say('Please include the name of the project to show dependencies for.');
    }

    my $unknown_project := 0;
    for @projects -> $project {
        my %info := get_project_metadata($project, 0);

        unless %info {
            $unknown_project := 1;
        }
    }

    unless $unknown_project {
        show_dependencies(@projects);
    }
}


sub command_fetch (@projects) {
       install_required_projects(@projects)
    && perform_actions_on_projects(%STAGES<fetch>, @projects);
}

sub command_configure (@projects) {
       install_required_projects(@projects)
    && perform_actions_on_projects(%STAGES<configure>, @projects);
}

sub command_build (@projects) {
       install_required_projects(@projects)
    && perform_actions_on_projects(%STAGES<build>, @projects);
}

sub command_test (@projects) {
       install_required_projects(@projects)
    && perform_actions_on_projects(%STAGES<test>, @projects);
}

sub command_install (@projects) {
       install_required_projects(@projects)
    && perform_actions_on_projects(%STAGES<install>, @projects);
}


sub install_required_projects (@projects) {
    my %resolutions   := resolve_dependencies(@projects);
    my @need_projects := %resolutions<need_project>;

    if (@need_projects) {
        my $need_projects := join(', ', @need_projects);
        say("\nInstalling other projects to satisfy dependencies:\n"
            ~ "    $need_projects\n");

        return perform_actions_on_projects(%STAGES<install>, @need_projects);
    }

    return 1;
}

sub show_dependencies (@projects) {
    my %resolutions := resolve_dependencies(@projects);

    say('');

    my $have_bin     := join(' ', %resolutions<have_bin>);
    say("Resolved by system binaries: $have_bin");

    my $have_project := join(' ', %resolutions<have_project>);
    say("Resolved by Parrot projects: $have_project");

    my $need_bin     := join(' ', %resolutions<need_bin>);
    say("Missing system binaries:     $need_bin");

    my $need_project := join(' ', %resolutions<need_project>);
    say("Missing Parrot projects:     $need_project");

    my $need_unknown := join(' ', %resolutions<need_unknown>);
    say("Missing and unrecognized:    $need_unknown");

    if $need_unknown {
        # XXXX: Don't forget to fix this when metadata is retrieved from server

        say("\nI don't recognize some of these dependencies.  First, update and\n"
            ~ "rebuild Plumage to get the latest metadata.  Next, please check\n"
            ~ "that there are no typos in the project dependency information.\n");
        return 0;
    }
    elsif $need_bin {
        say("\nPlease use your system's package manager to install\n"
            ~ "the missing system binaries, then restart Plumage.\n");
        return 0;
    }
    elsif $need_project {
        say("\nPlumage will install missing Parrot projects automatically.\n");
        return 0;
    }
    else {
        say("\nAll dependencies resolved.\n");
        return 1;
    }
}

sub mark_projects_installed (@projects) {
    my $lines := join("\n", @projects) ~ "\n";
    my $file  := replace_config_strings(%CONF<installed_list_file>);

    append($file, $lines);
}

sub get_installed_projects () {
    my $inst_file := replace_config_strings(%CONF<installed_list_file>);
    my $contents  := try(slurp, [$inst_file]);

    my @projects;
       @projects := grep(-> $_ { ?$_ }, split("\n", $contents)) if $contents;

    return @projects;
}

sub resolve_dependencies (@projects) {
    my @all_deps       := all_dependencies(@projects);
    my @known_projects := get_project_list();
    my @installed      := get_installed_projects();
    my %is_project     := set_from_array(@known_projects);
    my %is_installed   := set_from_array(@installed);

    my @have_bin;
    my @need_bin;
    my @have_project;
    my @need_project;
    my @need_unknown;

    for @all_deps -> $dep {
        if %BIN{$dep} || find_program($dep) {
            @have_bin.push($dep);
        }
        elsif %BIN.exists($dep) {
            @need_bin.push($dep);
        }
        elsif %is_installed{$dep} {
            @have_project.push($dep);
        }
        elsif %is_project{$dep} {
            @need_project.push($dep);
        }
        else {
            @need_unknown.push($dep);
        }
    }

    my %resolutions;

    %resolutions<have_bin>     := @have_bin;
    %resolutions<need_bin>     := @need_bin;
    %resolutions<have_project> := @have_project;
    %resolutions<need_project> := @need_project;
    %resolutions<need_unknown> := @need_unknown;

    return %resolutions;
}

sub all_dependencies (@projects) {
    my @dep_stack;
    my @deps;
    my %seen;

    for @projects -> $project {
        @dep_stack.unshift($project);
        %seen{$project} := 1;
    }

    while @dep_stack {
        my $project := @dep_stack.pop();
        my %info    := get_project_metadata($project, 1);

        if %info && metadata_valid(%info) {
            my %info_deps := %info<dependency-info>;
            if %info_deps {
                my %requires := %info_deps<requires>;
                if %requires {
                    for %requires.values -> @step_requires {
                        for @step_requires -> $dep {
                            unless %seen{$dep} {
                                @dep_stack.push($dep);
                                @deps.unshift($dep);
                                %seen{$dep} := 1;
                            }
                        }
                    }
                }
            }
        }
    }

    return @deps;
}


sub perform_actions_on_projects (@actions, @projects) {
    my $cwd        := cwd();
    my $build_root := replace_config_strings(%CONF<plumage_build_root>);
    mkpath($build_root);

    for @projects -> $project {
        my %info := get_project_metadata($project, 0);
        if %info && metadata_valid(%info) {
            chdir($build_root);
            my $success := perform_actions_on_project(@actions, $project, %info);
            chdir($cwd);

            return 0 unless $success;
        }
    }

    return 1;
}

sub perform_actions_on_project (@actions, $project, %info) {
    my $has_ignore_flag := %OPT.exists('ignore-fail');
    my %ignore          := %OPT<ignore-fail>;
    my $ignore_all      := $has_ignore_flag && !%ignore;

    for @actions -> $action {
        my &action := %STAGE_ACTION{$action};
        if &action {
           my $cwd    := cwd();
           my $result := &action($project, %info);
           chdir($cwd);

           if $result {
               say("Successful.\n");
           }
           else {
               if $ignore_all || %ignore && %ignore{$action} {
                   say("FAILED, but ignoring failure at user request.\n");
               }
               else {
                   say("###\n### FAILED!\n###\n");
                   return 0;
               }
           }
        }
        else {
           say("I don't know how to perfom action '$action'.");
        }
    }

    return 1;
}


###
### ACTIONS
###


# FETCH

sub action_fetch ($project, %info) {
    my %fetch := %info<instructions><fetch>;
    if %fetch {
        my &action := %ACTION<fetch>{%fetch<type>};
        return &action($project, %info);
    }
    else {
        say("Don't know how to fetch $project.");
        return 0;
    }
}

sub fetch_repository ($project, %info) {
    my %repo := %info<resources><repository>;
    if %repo {
        say("Fetching $project ...");

        my &action := %ACTION<fetch>{%repo<type>};
        return &action($project, %repo<checkout_uri>);
    }
    else {
        say("Trying to fetch from a repository, but no repository info for $project.");
        return 0;
    }
}

sub fetch_git ($project, $uri) {
    if path_exists($project) {
        if path_exists(fscat([$project, '.git'])) {
            chdir($project);
            return do_run(%BIN<git>, 'pull');
        }
        else {
            return report_fetch_collision('Git', $project);
        }
    }
    else {
        return do_run(%BIN<git>, 'clone', $uri, $project);
    }
}

sub fetch_svn ($project, $uri) {
    if  path_exists($project)
    && !path_exists(fscat([$project, '.svn'])) {
        return report_fetch_collision('Subversion', $project);
    }
    else {
        return do_run(%BIN<svn>, 'checkout', $uri, $project);
    }
}

sub report_fetch_collision ($type, $project) {
    my $build_root  := replace_config_strings(%CONF<plumage_build_root>);
    my $project_dir := fscat([$build_root, $project]);

    say("\n$project is a $type project, but the fetch directory:\n"
        ~ "\n    $project_dir\n\n"
        ~ "already exists and is not the right type.\n"
        ~ "Please remove or rename it, then rerun $PROGRAM_NAME.\n");

    return 0;
}


# CONFIGURE

sub action_configure ($project, %info) {
    my %conf := %info<instructions><configure>;
    if %conf {
        say("\nConfiguring $project ...");

        my &action := %ACTION<configure>{%conf<type>};
        return &action($project, %conf);
    }
    else {
        say("\nConfiguration not required for $project.");
        return 1;
    }
}

sub configure_perl5_configure ($project, %conf) {
    my @extra := map(replace_config_strings, %conf<extra_args>);
    my $perl5 := %VM<config><perl>;

    chdir($project);
    return do_run($perl5, 'Configure.pl', |@extra);
}

sub configure_parrot_configure ($project, %conf) {
    my $parrot := fscat([%VM<config><bindir>], 'parrot');

    chdir($project);
    return do_run($parrot, 'Configure.pir');
}

sub configure_nqp_configure ($project, %conf) {
    my $parrot_nqp := fscat([%VM<config><bindir>], 'parrot-nqp');

    chdir($project);
    return do_run($parrot_nqp, 'Configure.nqp');
}


# MAKE

sub action_build ($project, %info) {
    my %conf := %info<instructions><build>;
    if %conf {
        say("\nBuilding $project ...");

        my &action := %ACTION<build>{%conf<type>};
        return &action($project);
    }
    else {
        say("\nBuild not required for $project.");
        return 1;
    }
}

sub build_make ($project) {
    my $make := %VM<config><make>;

    chdir($project);
    return do_run($make);
}

sub build_parrot_setup ($project) {
    my $parrot := fscat([%VM<config><bindir>], 'parrot');

    chdir($project);
    return do_run($parrot, 'setup.pir');
}


# TEST

sub action_test ($project, %info) {
    my %conf := %info<instructions><test>;
    if %conf {
        say("\nTesting $project ...");

        my &action := %ACTION<test>{%conf<type>};
        return &action($project);
    }
    else {
        say("\nNo test method found for $project.");
        return 1;
    }
}

sub test_make ($project) {
    my $make := %VM<config><make>;

    chdir($project);
    return do_run($make, 'test');
}

sub test_parrot_setup ($project) {
    my $parrot := fscat([%VM<config><bindir>], 'parrot');

    chdir($project);
    return do_run($parrot, 'setup.pir', 'test');
}


# INSTALL

sub action_install ($project, %info) {
    my %conf := %info<instructions><install>;
    if %conf {
        say("\nInstalling $project ...");

        my &action  := %ACTION<install>{%conf<type>};
        my $success := &action($project);

        if $success {
            mark_projects_installed([$project]);
        }

        return $success;
    }
    else {
        say("Don't know how to install $project.");
        return 0;
    }
}

sub install_make ($project) {
    my $make     := %VM<config><make>;
    my $bin_dir  := %VM<config><bindir>;
    my $root_cmd := replace_config_strings(%CONF<root_command>);

    chdir($project);

    if !test_dir_writable($bin_dir) && $root_cmd {
        return do_run($root_cmd, $make, 'install');
    }
    else {
        return do_run($make, 'install');
    }
}

sub install_parrot_setup ($project) {
    my $bin_dir  := %VM<config><bindir>;
    my $parrot   := fscat([$bin_dir], 'parrot');
    my $root_cmd := replace_config_strings(%CONF<root_command>);

    chdir($project);

    if !test_dir_writable($bin_dir) && $root_cmd {
        return do_run($root_cmd, $parrot, 'setup.pir', 'install');
    }
    else {
        return do_run($parrot, 'setup.pir', 'install');
    }
}
