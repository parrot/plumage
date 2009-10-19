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
our %ENV;
our %VM;
our $OS;

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

my $_DEFAULT_CONF_JSON := '
{
    "parrot_user_root"     : "#HOME#/.parrot",
    "plumage_user_root"    : "#parrot_user_root#/plumage",
    "plumage_build_root"   : "#plumage_user_root#/build",
    "plumage_metadata_dir" : "metadata",
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
    load_bytecode('src/lib/Glue.pbc');

    # utility functions written in nqp
    load_bytecode('src/lib/Util.pbc');

    # Process command line options
    load_bytecode('Getopt/Obj.pbc');

    # Parse files in JSON format
    load_bytecode('Config/JSON.pbc');

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

sub parse_command_line_options () {
    my $getopts := Q:PIR{ %r = root_new ['parrot';'Getopt::Obj'] };

    $getopts.push_string('config-file=s');
    $getopts.push_string('ignore-fail:%');

    %OPT := $getopts.get_options(@ARGS);
}

sub read_config_files () {
    # Find config files for this system and user (ignored if missing).
    my $etc      := %VM<conf><sysconfdir>;
    my $home     := %ENV<HOME>;
    my $base     := 'plumage.json';
    my $sysconf  := fscat(as_array($etc,  'parrot', 'plumage'), $base);
    my $userconf := fscat(as_array($home, 'parrot', 'plumage'), $base);
    my @configs  := as_array($sysconf, $userconf);

    # If another config specified via command line option, add it.  Because
    # this was manually set by the user, it is a fatal error if missing.
    my $optconf  := %OPT<config-file>;
    if $optconf {
        if path_exists($optconf) {
            @configs.push($optconf);
        }
        else {
            die("Could not find config file '" ~ $optconf ~ "'.\n");
        }
    }

    # Merge together default, system, user, and option configs
    my %default := eval($_DEFAULT_CONF_JSON, 'data_json');
    %CONF := merge_tree_structures(%CONF, %default);

    for @configs {
        if path_exists($_) {
            my %conf := try(Config::JSON::ReadConfig, as_array($_));
            if %conf {
                %CONF := merge_tree_structures(%CONF, %conf);
            }
            else {
                say("Could not parse JSON file '" ~ $_ ~ "'.");
            }
        }
    }

    # _dumper(%CONF, 'CONF');
}

sub merge_tree_structures ($dst, $src) {
    for keys($src) {
        my $d := $dst{$_};
        my $s := $src{$_};

        if  $d && does($d, 'hash')
        &&  $s && does($s, 'hash') {
            $dst{$_} := merge_tree_structures($d, $s);
        }
        else {
            $dst{$_} := $s;
        }
    }

    return $dst;
}

sub find_binaries () {
    my %conf       := %VM<config>;
    my $parrot_bin := %conf<bindir>;

    %BIN<parrot_config> := fscat(as_array($parrot_bin), 'parrot_config');

    %BIN<perl5> := %conf<perl>;
    %BIN<make>  := %conf<make>;

    %BIN<svn>   := find_program('svn');
    %BIN<git>   := find_program('git');
}

sub build_stages () {
    my @stages := split(' ', 'install test build configure fetch');

    for @stages {
        my $stage       := $_;
        %STAGES{$stage} := as_array();

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
    parse_command_line_options();
    read_config_files();
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
        Q:PIR{ exit 1 };
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

Options:

    --config-file=<path>     Read additional config file

    --ignore-fail            Ignore any failing build stages
    --ignore-fail=<stage>    Ignore failures only in a particular stage
                             (may be repeated to select more than one stage)
    --ignore-fail=<stage>=0  Don\'t ignore failures in this stage

Commands:

    projects             List all known projects
    info      <project>  Print info about a particular project
    showdeps  <project>  Show dependency resolution for a project

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


sub command_projects () {
    my @projects := get_project_list();

    say("\nKnown projects:\n");

    for @projects {
        my $desc := '';

        my %info := get_project_metadata($_, 0);
        if %info && metadata_valid(%info) {
            my %general := %info<general>;
            if %general {
                my $abstract := %general<abstract>;
                if $abstract {
                    $desc := ' - ' ~ $abstract;
                }
            }
        }

        say('    ' ~ $_ ~ $desc);
    }

    say('');
}


sub command_info (@projects) {
    unless (@projects) {
        say('Please include the name of the project you wish info for.');
    }

    for @projects {
        my %info := get_project_metadata($_, 0);
        if %info {
            _dumper(%info, 'INFO');
        }
    }
}


sub command_showdeps (@projects) {
    unless (@projects) {
        say('Please include the name of the project to show dependencies for.');
    }

    my $unknown_project := 0;
    for @projects {
        my %info := get_project_metadata($_, 0);

        unless %info {
            $unknown_project := 1;
        }
    }

    unless $unknown_project {
        show_dependencies(@projects);
    }
}

sub get_project_list () {
    my @files := readdir(%CONF<plumage_metadata_dir>);
    my $regex := rx('\.json$');
    my @projects;

    for @files {
        if $regex($_) {
            my $project := subst($_, $regex, '');
            @projects.push($project);
        }
    }

    return @projects;
}

sub get_project_metadata ($project, $ignore_missing) {
    my $json_file := fscat(as_array(%CONF<plumage_metadata_dir>),
                           $project ~ '.json');
    unless path_exists($json_file) {
        unless $ignore_missing {
            say("I don't know anything about project '" ~ $project ~ "'.");
        }
        return 0;
    }

    return try(Config::JSON::ReadConfig, as_array($json_file),
               show_metadata_parse_error);
}

sub show_metadata_parse_error ($exception, &code, @args) {
    say("Failed to parse metadata file '" ~ @args[0] ~ "': " ~ $exception);

    return 0;
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

sub show_dependencies (@projects) {
    my %resolutions := resolve_dependencies(@projects);

    say('');

    my $have_bin     := join(' ', %resolutions<have_bin>);
    say("Resolved by system binaries: " ~ $have_bin);

    my $have_project := join(' ', %resolutions<have_project>);
    say("Resolved by Parrot projects: " ~ $have_project);

    my $need_bin     := join(' ', %resolutions<need_bin>);
    say("Missing system binaries:     " ~ $need_bin);

    my $need_project := join(' ', %resolutions<need_project>);
    say("Missing Parrot projects:     " ~ $need_project);

    my $need_unknown := join(' ', %resolutions<need_unknown>);
    say("Missing and unrecognized:    " ~ $need_unknown);

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

sub resolve_dependencies (@projects) {
    my @all_deps       := all_dependencies(@projects);
    my @known_projects := get_project_list();

    my %is_project;
    for @known_projects {
        %is_project{$_} := 1;
    }

    my @have_bin;
    my @need_bin;
    my @have_project;
    my @need_project;
    my @need_unknown;

    for @all_deps {
        if %BIN{$_} || find_program($_) {
            @have_bin.push($_);
        }
        elsif exists(%BIN, $_) {
            @need_bin.push($_);
        }
        elsif %is_project{$_} {
            @need_project.push($_);
        }
        else {
            @need_unknown.push($_);
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

    for @projects {
        @dep_stack.push($_);
        %seen{$_} := 1;
    }

    while @dep_stack {
        my $project := @dep_stack.shift();
        my %info    := get_project_metadata($project, 1);

        if %info && metadata_valid(%info) {
            my %info_deps := %info<dependency-info>;
            if %info_deps {
                my %requires := %info_deps<requires>;
                if %requires {
                    for keys(%requires) {
                        my @step_requires := %requires{$_};
                        if @step_requires {
                            for @step_requires {
                                unless %seen{$_} {
                                    @dep_stack.push($_);
                                    @deps.push($_);
                                    %seen{$_} := 1;
                                }
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

    for @projects {
        my %info := get_project_metadata($_, 0);
        if %info && metadata_valid(%info) {
            chdir($build_root);
            perform_actions_on_project(@actions, $_, %info);
            chdir($cwd);
        }
    }
}

sub perform_actions_on_project (@actions, $project, %info) {
    my $has_ignore_flag := exists(%OPT, 'ignore-fail');
    my %ignore          := %OPT<ignore-fail>;
    my $ignore_all      := $has_ignore_flag && !%ignore;

    for @actions {
        my &action := %STAGE_ACTION{$_};

        if &action {
           my $result := &action($project, %info);
           if $result {
               say("Successful.\n");
           }
           else {
               if $ignore_all || %ignore && %ignore{$_} {
                   say("FAILED, but ignoring failure at user request.\n");
               }
               else {
                   say("###\n### FAILED!\n###\n");
                   return 0;
               }
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
    my %repo := %info<instructions><fetch>;
    unless %repo<type> eq 'repository' {
        say("Don't know how to fetch " ~ $project ~ '.');
        return 0;
    }

    my %repo := %info<resources><repository>;
    if %repo {
        say("Fetching " ~ $project ~ ' ...');

        my &action := %ACTION<fetch>{%repo<type>};
        return &action($project, %repo<checkout_uri>);
    }
    else {
        say("Don't know how to fetch " ~ $project ~ '.');
        return 0;
    }
}

sub fetch_git ($project, $uri) {
    if path_exists($project) {
        if path_exists(fscat(as_array($project, '.git'))) {
            my $cwd := cwd();
            chdir($project);

            my $success := do_run('git', 'pull');

            chdir($cwd);

            return $success;
        }
        else {
            return report_fetch_collision('Git', $project);
        }
    }
    else {
        return do_run('git', 'clone', $uri, $project);
    }
}

sub fetch_svn ($project, $uri) {
    if  path_exists($project)
    && !path_exists(fscat(as_array($project, '.svn'))) {
        return report_fetch_collision('Subversion', $project);
    }
    else {
        return do_run('svn', 'checkout', $uri, $project);
    }
}

sub report_fetch_collision ($type, $project) {
    my $build_root  := replace_config_strings(%CONF<plumage_build_root>);
    my $project_dir := fscat(as_array($build_root, $project));

    say("\n"
        ~ $project ~ ' is a ' ~ $type ~ " project, but the fetch directory:\n"
        ~ "\n    " ~ $project_dir ~ "\n\n"
        ~ "already exists and is not the right type.\n"
        ~ 'Please remove or rename it, then rerun ' ~ $PROGRAM_NAME ~ ".\n");

    return 0;
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

    my @extra   := map(replace_config_strings, %conf<extra_args>);

    my $perl5   := %VM<config><perl>;
    my $success := call_flattened(do_run, $perl5, 'Configure.pl', @extra);

    chdir($cwd);

    return $success;
}

sub configure_parrot_configure ($project, %conf) {
    my $cwd := cwd();
    chdir($project);

    my $parrot  := fscat(as_array(%VM<config><bindir>), 'parrot');
    my $success := do_run($parrot, 'Configure.pir');

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
    my $success := do_run($make);

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
    my $success := do_run($make, 'test');

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

    my $make     := %VM<config><make>;
    my $bin_dir  := %VM<config><bin_dir>;
    my $root_cmd := %CONF<root_command>;
    my $success;

    if !test_dir_writable($bin_dir) && $root_cmd {
        $success := do_run($root_cmd, $make, 'install');
    }
    else {
        $success := do_run($make, 'install');
    }

    chdir($cwd);

    return $success;
}
