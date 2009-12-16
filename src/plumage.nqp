###
### NQP WORKAROUND HACKS
###


# Must redeclare PIR globals because the NQP parser doesn't know about
# variables created at load_bytecode time.
my $*PROGRAM_NAME;
my @*ARGS;
my %*ENV;
my %*VM;
my $*OS;


# NQP does not include a setting, so must load helper libraries before
# even eval() will be available
load_helper_libraries();


# NQP doesn't support hash literals, so parse main structure from JSON
# and then fix up values that can't be represented in JSON.
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
    "project-dir" : {
        "action" : "command_project_dir",
        "args"   : "project"
    },
    "showdeps"   : {
        "action" : "command_showdeps",
        "args"   : "project"
    },
    "fetch"      : {
        "action" : "command_project_action",
        "args"   : "project"
    },
    "update"     : {
        "action" : "command_project_action",
        "args"   : "project"
    },
    "configure"  : {
        "action" : "command_project_action",
        "args"   : "project"
    },
    "build"      : {
        "action" : "command_project_action",
        "args"   : "project"
    },
    "test"       : {
        "action" : "command_project_action",
        "args"   : "project"
    },
    "smoke"      : {
        "action" : "command_project_action",
        "args"   : "project"
    },
    "install"    : {
        "action" : "command_project_action",
        "args"   : "project"
    },
    "uninstall"  : {
        "action" : "command_project_action",
        "args"   : "project"
    },
    "clean"      : {
        "action" : "command_project_action",
        "args"   : "project"
    },
    "realclean"  : {
        "action" : "command_project_action",
        "args"   : "project"
    }
}
';
our %COMMANDS := fixup_commands(eval($_COMMANDS_JSON, 'data_json'));

my $_DEFAULT_CONF_JSON := '
{
    "parrot_user_root"     : "#user_home_dir#/.parrot",
    "plumage_user_root"    : "#parrot_user_root#/plumage",
    "plumage_build_root"   : "#plumage_user_root#/build",
    "saved_metadata_root"  : "#plumage_user_root#/saved_metadata",
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


our %OPT;

my %*CONF;
my %*BIN;


sub load_helper_libraries () {
    # Support OO
    pir::load_bytecode('P6object.pbc');

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

    # Plumage modules: metadata, project, dependencies
    pir::load_bytecode('src/lib/Plumage/Metadata.pbc');
    pir::load_bytecode('src/lib/Plumage/Project.pbc');
    pir::load_bytecode('src/lib/Plumage/Dependencies.pbc');
}

sub fixup_commands ($commands) {
    # Convert action sub *names* into actual action subs
    for $commands.kv -> $cmd, $opts {
        $opts<action> := pir::get_hll_global__Ps($opts<action>);
    }

    return $commands;
}

sub parse_command_line_options () {
    my $getopts := Q:PIR{ %r = root_new ['parrot';'Getopt::Obj'] };

    $getopts.push_string('config-file=s');
    $getopts.push_string('ignore-fail:%');

    %OPT := $getopts.get_options(@*ARGS);
}

sub read_config_files () {
    # Find config files for this system and user (ignored if missing).
    my $etc      := %*VM<conf><sysconfdir>;
    my $home     := user_home_dir();
    my $base     := 'plumage.json';
    my $sysconf  := fscat([$etc,  'parrot', 'plumage'], $base);
    my $userconf := fscat([$home, 'parrot', 'plumage'], $base);
    my @configs  := ($sysconf, $userconf);

    # Remember home dir, we'll need that later
    %*CONF<user_home_dir> := $home;

    # If another config specified via command line option, add it.  Because
    # this was manually set by the user, it is a fatal error if missing.
    my $optconf  := %OPT<config-file>;
    if $optconf {
        if path_exists($optconf) {
            @configs.push($optconf);
        }
        else {
            pir::die("Could not find config file '$optconf'.\n");
        }
    }

    # Merge together default, system, user, and option configs
    my %default := eval($_DEFAULT_CONF_JSON, 'data_json');
    %*CONF := merge_tree_structures(%*CONF, %default);

    for @configs -> $config {
        if path_exists($config) {
            my %conf := Config::JSON::ReadConfig($config);
            %*CONF   := merge_tree_structures(%*CONF, %conf);

            CATCH {
                say("Could not parse JSON file '$config'.");
            }
        }
    }

    # _dumper(%*CONF, 'CONF');
}

sub merge_tree_structures ($dst, $src) {
    for $src.keys -> $k {
        my $d := $dst{$k};
        my $s := $src{$k};

        if  $d && pir::does__IPs($d, 'hash')
        &&  $s && pir::does__IPs($s, 'hash') {
            $dst{$k} := merge_tree_structures($d, $s);
        }
        else {
            $dst{$k} := $s;
        }
    }

    return $dst;
}

sub find_binaries () {
    my %conf       := %*VM<config>;
    my $parrot_bin := %conf<bindir>;

    # Parrot programs; must be sourced from configured parrot bin directory
    %*BIN<parrot_config> := fscat([$parrot_bin], 'parrot_config');
    %*BIN<parrot-nqp>    := fscat([$parrot_bin], 'parrot-nqp');
    %*BIN<parrot>        := fscat([$parrot_bin], 'parrot');

    # Programs used to build parrot; make sure we use the same ones
    %*BIN<perl5> := %conf<perl>;
    %*BIN<make>  := %conf<make>;

    # Unrelated system programs; look for them in the user's search path
    %*BIN<rake>  := find_program('rake');
    %*BIN<svn>   := find_program('svn');
    %*BIN<git>   := find_program('git');
    %*BIN<hg>    := find_program('hg');
}


###
### MAIN
###


sub MAIN () {
    parse_command_line_options();
    read_config_files();
    find_binaries();

    my $command := parse_command_line();

    execute_command($command);
}

sub parse_command_line () {
    my $command := @*ARGS ?? @*ARGS.shift !! 'usage';

    return $command;
}

sub execute_command ($command) {
    my $action := %COMMANDS{$command}<action>;
    my $args   := %COMMANDS{$command}<args>;

    if ($action) {
        if $args eq 'project' && !@*ARGS {
            say('Please specify a project to act on.');
        }
        else {
            $action(@*ARGS, :command($command));
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
"Usage: $*PROGRAM_NAME [<options>] <command> [<arguments>]

Options:

    --config-file=<path>     Read additional config file

    --ignore-fail            Ignore any failing build stages
    --ignore-fail=<stage>    Ignore failures only in a particular stage
                             (may be repeated to select more than one stage)
    --ignore-fail=<stage>=0  Don't ignore failures in this stage

Commands:

  Query metadata/project info:
    projects                List all known projects
    status      [<project>] Show status of projects (defaults to all)
    info         <project>  Print info about a particular project
    showdeps     <project>  Show dependency resolution for a project
    project-dir  <project>  Print project's top directory

  Perform actions on a project:
    fetch        <project>  Download source
    update       <project>  Update source                (falls back to fetch)
    configure    <project>  Configure source             (updates first)
    build        <project>  Build project from source    (configures first)
    test         <project>  Test built project           (builds first)
    smoke        <project>  Smoke test project           (builds first)
    install      <project>  Install built files          (tests first)
    uninstall    <project>  Uninstalls installed files   (not always available)
    clean        <project>  Clean source tree
    realclean    <project>  Clobber/realclean source tree

  Get info about Plumage itself:
    version                 Print program version and copyright
    usage                   Print this usage info
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
    my @projects := Plumage::Metadata.get_project_list();
       @projects.sort;

    my @lengths  := map(-> $a { pir::length($a) }, @projects);
    my $max_len  := reduce(-> $a, $b { $a >= $b ?? $a !! $b }, @lengths);

    say("\nKnown projects:\n");

    for @projects -> $project {
        my $desc  := '';
        my $meta  := Plumage::Metadata.new();
        my $valid := $meta.find_by_project_name($project);

        if $valid {
            my %general := $meta.metadata<general>;
            if %general {
                my $abstract := %general<abstract>;

                $desc := "  $abstract" if $abstract;
            }
        }

        say(pir::sprintf__SsP("    %-{$max_len}s%s", [$project, $desc]));
    }

    say('');
}


sub command_status (@projects) {
    my $showing_all := !@projects;

    unless @projects {
        @projects := Plumage::Metadata.get_project_list();
        say("\nKnown projects:\n");
    }

    my @installed := Plumage::Dependencies.get_installed_projects();
    my %installed := set_from_array(@installed);

    for @projects -> $project {
        my $status := %installed{$project} ?? 'installed' !! '-';
        my $output := pir::sprintf__SsP("    %-30s   %s", [$project, $status]);
        say($output);
    }

    say('') if $showing_all;
}


sub command_info (@projects) {
    unless (@projects) {
        say('Please include the name of the project you wish info for.');
    }

    for @projects -> $project {
        my $meta  := Plumage::Metadata.new();
        my $valid := $meta.find_by_project_name($project);

        if $valid {
            _dumper($meta.metadata, 'INFO');
        }
        else {
            report_metadata_error($project, $meta);
        }
    }
}


sub command_showdeps (@projects) {
    unless (@projects) {
        say('Please include the name of the project to show dependencies for.');
    }

    my $unknown_project := 0;
    for @projects -> $project {
        my $meta  := Plumage::Metadata.new();
        my $valid := $meta.find_by_project_name($project);

        unless $valid {
            report_metadata_error($project, $meta);
            $unknown_project := 1;
        }
    }

    unless $unknown_project {
        show_dependencies(@projects);
    }
}

sub report_metadata_error ($project_name, $meta) {
    say("Metadata error for project '$project_name':\n" ~ $meta.error);
}


sub command_project_dir (@projects) {
    unless (@projects) {
        say('Please include the name of the project you wish to find.');
    }

    for @projects -> $project_name {
        my $project := Plumage::Project.new($project_name);

        say($project.source_dir) if pir::defined__IP($project);
    }
}


sub command_project_action (@projects, :$command) {
       install_required_projects(@projects)
    && perform_actions_on_projects(@projects, :up_to($command));
}


sub install_required_projects (@projects) {
    my %resolutions   := Plumage::Dependencies.resolve_dependencies(@projects);
    my @need_projects := %resolutions<need_project>;

    if (@need_projects) {
        my $need_projects := pir::join(', ', @need_projects);
        say("\nInstalling other projects to satisfy dependencies:\n"
            ~ "    $need_projects\n");

        return perform_actions_on_projects(@need_projects, :up_to('install'));
    }

    return 1;
}

sub show_dependencies (@projects) {
    my %resolutions := Plumage::Dependencies.resolve_dependencies(@projects);

    say('');

    my $have_bin     := pir::join(' ', %resolutions<have_bin>);
    say("Resolved by system binaries: $have_bin");

    my $have_project := pir::join(' ', %resolutions<have_project>);
    say("Resolved by Parrot projects: $have_project");

    my $need_bin     := pir::join(' ', %resolutions<need_bin>);
    say("Missing system binaries:     $need_bin");

    my $need_project := pir::join(' ', %resolutions<need_project>);
    say("Missing Parrot projects:     $need_project");

    my $need_unknown := pir::join(' ', %resolutions<need_unknown>);
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


sub perform_actions_on_projects (@projects, :$up_to, :@actions) {
    my $has_ignore_flag := %OPT.exists('ignore-fail');
    my %ignore          := %OPT<ignore-fail>;
    my $ignore_all      := $has_ignore_flag && !%ignore;

    for @projects -> $project_name {
        my $project := Plumage::Project.new($project_name);
        if pir::defined__IP($project) {
            return 0 unless $project.perform_actions(:up_to($up_to),
                                                     :actions(@actions),
                                                     :ignore_all($ignore_all),
                                                     :ignore(%ignore));
        }
    }

    return 1;
}
