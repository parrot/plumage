# Copyright (C) 2009-2011, Parrot Foundation.

# TODO Add perldoc

# Global setting variables (NQP workaround)
my $*PROGRAM_NAME;
my $*OSNAME;
my @*ARGS;
my %*ENV;
my %*VM;
my $*OS;

load_libraries();

# Global structure of recognized commands
my  %COMMANDS  := hash(
    usage       => Plumage::Command.new(:action(command_usage),
                                        :args('none'),
                                        :usage('usage'),
                                        :help('This command is here for compatibility '
                                            ~ 'only. Please use `help` instead.')),

    cli         => Plumage::Command.new(:action(command_cli),
                                        :args('none'),
                                        :usage('cli'),
                                        :help('Starts the interactive command-line interface. '
                                            ~ 'Invoked by default if no command was specified.')),

    help        => Plumage::Command.new(:action(command_help),
                                        :args('opt_command'),
                                        :usage('help [<command>]'),
                                        :help('Displays a help message on <command> usage '
                                            ~ '(defaults to all).')),

    version     => Plumage::Command.new(:action(command_version),
                                        :args('none'),
                                        :usage('version'),
                                        :help('Displays Plumage version and copyright statement.')),

    projects    => Plumage::Command.new(:action(command_projects),
                                        :args('none'),
                                        :usage('projects'),
                                        :help('Lists all known projects.')),

    status      => Plumage::Command.new(:action(command_status),
                                        :args('opt_project'),
                                        :usage('status <project>'),
                                        :help('Shows status of <project> (defaults to all).')),

    info        => Plumage::Command.new(:action(command_info),
                                        :args('project'),
                                        :usage('info <project>'),
                                        :help('Displays detailed description of <project>.')),

    metadata    => Plumage::Command.new(:action(command_info),
                                        :args('project'),
                                        :usage('metadata <project>'),
                                        :help('Displays JSON metadata for <project>.')),

    project_dir => Plumage::Command.new(:action(command_project_dir),
                                        :args('project'),
                                        :usage('project-dir <project>'),
                                        :help('Displays top directory for <project>.')),

    show_deps   => Plumage::Command.new(:action(command_show_deps),
                                        :args('project'),
                                        :usage('show-deps <project>'),
                                        :help('Shows dependencies for <project>.')),

    fetch       => Plumage::Command.new(:action(command_project_action),
                                        :args('project'),
                                        :usage('fetch <project>'),
                                        :help('Downloads source code for <project>.')),

    update      => Plumage::Command.new(:action(command_project_action),
                                        :args('project'),
                                        :usage('update <project>'),
                                        :help('Updates source code for <project> '
                                            ~ "(falls back to 'fetch').")),

    configure   => Plumage::Command.new(:action(command_project_action),
                                        :args('project'),
                                        :usage('configure <project>'),
                                        :help('Configures source code for <project> '
                                            ~ "(runs 'update' first).")),

    build       => Plumage::Command.new(:action(command_project_action),
                                        :args('project'),
                                        :usage('build <project>'),
                                        :help('Builds <project> in current directory '
                                            ~ "(runs 'configure' first).")),

    test        => Plumage::Command.new(:action(command_project_action),
                                        :args('project'),
                                        :usage('test <project>'),
                                        :help('Runs test suite for <project> '
                                            ~ "(runs 'build' first).")),

    smoke       => Plumage::Command.new(:action(command_project_action),
                                        :args('project'),
                                        :usage('smoke <project>'),
                                        :help("Sends test results to Parrot's Smolder server "
                                            ~ "(runs 'build' first).")),

    install     => Plumage::Command.new(:action(command_project_action),
                                        :args('project'),
                                        :usage('install <project>'),
                                        :help("Installs <project> (runs 'test' first).")),

    uninstall   => Plumage::Command.new(:action(command_project_action),
                                        :args('project'),
                                        :usage('uninstall <project>'),
                                        :help('Uninstalls <project> from system '
                                            ~ '(not always available).')),

    clean       => Plumage::Command.new(:action(command_project_action),
                                        :args('project'),
                                        :usage('clean <project>'),
                                        :help('Performs basic clean up of source tree '
                                            ~ 'for <project>.')),

    realclean   => Plumage::Command.new(:action(command_project_action),
                                        :args('project'),
                                        :usage('realclean <project>'),
                                        :help('Removes all files generated during the '
                                            ~ 'build process for <project>.')));

# Add support for both spellings of certain commands
%COMMANDS<project-dir> := %COMMANDS<project_dir>;
%COMMANDS<show-deps>   := %COMMANDS<show_deps>;

# Default configuration
my %DEFAULT_CONF := hash(
    parrot_user_root     => '#user_home_dir#/.parrot',
    plumage_user_root    => '#parrot_user_root#/plumage',
    plumage_build_root   => '#plumage_user_root#/build',
    saved_metadata_root  => '#plumage_user_root#/saved_metadata',
    plumage_metadata_dir => 'plumage/metadata',
    installed_list_file  => '#plumage_user_root#/installed_projects.list',
    root_command         => 'sudo',
);

unless path_exists(%DEFAULT_CONF<plumage_metadata_dir>) {
    %DEFAULT_CONF<plumage_metadata_dir> := %*VM<config><datadir> ~ '/plumage/metadata';
}

MAIN();

###
### INITIALIZATION
###
### The following subroutines perform the various tasks that need to be
### performed before any commands are executed such as loading libraries,
### parsing command-line options, and reading the config file
###

# XXX Why is this package-scoped? Can it be declared with 'my'?
our %OPTIONS;    # Command-line switches

my %*CONF;       # Configuration options
my %*BIN;        # System binaries

sub load_libraries() {
    # Object-oriented interface
    pir::load_bytecode('P6object.pbc');

    # Processes command-line switches
    pir::load_bytecode('Getopt/Obj.pbc');

    # Parses JSON config files
    pir::load_bytecode('Config/JSON.pbc');

    # "Stringifies" PMC data structures (used for debugging only)
    pir::load_bytecode('dumper.pbc');

    # Extends NQP runtime environment and native data structures
    pir::load_bytecode('Plumage/NQPUtil.pbc');

    # Provides subroutines needed to replace config strings
    pir::load_bytecode('Plumage/Util.pbc');

    # Parses a project's metadata
    pir::load_bytecode('Plumage/Metadata.pbc');

    # Represents a project and performs certain actions on them
    pir::load_bytecode('Plumage/Project.pbc');

    # Resolves dependencies
    pir::load_bytecode('Plumage/Dependencies.pbc');

    # Represents Plumage commands
    pir::load_bytecode('Plumage/Command.pbc');
}

sub parse_command_line_options() {
    my $getopt := pir::root_new__PP(< parrot Getopt Obj >);

    # Configure -c switch
    my $config := $getopt.add();
    $config.name('CONFIG_FILE');
    $config.long('config-file');
    $config.short('c');
    $config.type('String');

    # Configure -i switch
    my $ignore := $getopt.add();
    $ignore.name('IGNORE_FAIL');
    $ignore.long('ignore-fail');
    $ignore.short('i');
    $ignore.type('Hash');
    $ignore.optarg(1);

    # Configure -h switch
    my $help := $getopt.add();
    $help.name('HELP');
    $help.long('help');
    $help.short('h');

    %OPTIONS := $getopt.get_options(@*ARGS);
}

sub read_config_files() {
    # Find config file for this system and user (if any)
    my $etc      := %*VM<conf><sysconfdir>;
    my $home     := %*ENV<PLUMAGE_HOME> || user_home_dir();
    my $base     := 'plumage.json';
    my $sysconf  := fscat([$etc,  'parrot', 'plumage'], $base);
    my $userconf := fscat([$home, 'parrot', 'plumage'], $base);
    my @configs  := ($sysconf, $userconf);

    # Remember home directory
    %*CONF<user_home_dir> := $home;

    # Use config file given on command-line, if given
    my $optconf := %OPTIONS<CONFIG_FILE>;

    if $optconf {
        if path_exists($optconf) {
            @configs.push($optconf);
        }
        else {
            pir::die("Could not find config file '$optconf'.\n");
        }
    }

    # Merge together 'default', 'system', 'user', and 'option' config options
    %*CONF := merge_tree_structures(%*CONF, %DEFAULT_CONF);

    for @configs -> $config {
        if path_exists($config) {
            my %conf := Config::JSON::ReadConfig($config);
            %*CONF   := merge_tree_structures(%*CONF, %conf);

            CATCH {
                say("Could not parse config file '$config'.");
            }
        }
    }
}

sub merge_tree_structures($dst, $src) {
    for $src.keys -> $k {
        my $d := $dst{$k};
        my $s := $src{$k};

        if $d && pir::does__IPs($d, 'hash')
        && $s && pir::does__IPs($s, 'hash') {
           $dst{$k}  := merge_tree_structures($d, $s);
        }
        else {
            $dst{$k} := $s;
        }
    }

    return $dst;
}

sub find_binaries() {
    my %conf       := %*VM<config>;
    my $parrot_bin := %conf<bindir>;

    # Parrot binaries (must be sourced from configured Parrot bin directory)
    %*BIN<parrot_config> := fscat([$parrot_bin], 'parrot_config');
    %*BIN<parrot-nqp>    := fscat([$parrot_bin], 'parrot-nqp');
    %*BIN<parrot>        := fscat([$parrot_bin], 'parrot');

    # Use the same programs used to build Parrot
    %*BIN<perl5>         := %conf<perl>;
    %*BIN<make>          := %conf<make>;

    # Additional programs needed to fetch project's source code
    %*BIN<rake>          := find_program('rake');
    %*BIN<svn>           := find_program('svn');
    %*BIN<git>           := find_program('git');
    %*BIN<hg>            := find_program('hg');
}

sub parse_command_line() {
    my $command := @*ARGS ?? @*ARGS.shift !! 'cli';

    return $command;
}

sub execute_command($command) {
    my $action := %COMMANDS{$command}.action;
    my $args   := %COMMANDS{$command}.args;

    if $action {
        if $args eq 'project' && !@*ARGS {
            say('Please specify a project to act on.');
        }
        #elsif $args eq 'opt_project' {
        #}
        else {
            $action(@*ARGS, :command($command));
        }
    }
    else {
        say("No such command: $command. Please use $*PROGRAM_NAME --help");
        pir::exit(1);
    }
}

###
### COMMANDS
###
### Each of the following subroutines represents an individual command recognized
### by Plumage (note the command_* prefix followed by the actual command name)
###

sub command_usage() {
    print(usage_info());
}

sub usage_info() {
    return
"Usage: $*PROGRAM_NAME [<options>] <command> [<arguments>]

Options:

    -h, --help                   Displays a help message on command usage.

    -c, --config-file=<path>     Reads additional config file in <path>.

    -i, --ignore-fail            Ignores any failed build stages.

    -i, --ignore-fail=<stage>    Ignores failures only for <stage>
                                 (may be repeated to select more than one stage).

    -i, --ignore-fail=<stage>=0  Doesn't ignore failures in <stage>.

Commands:

  Query metadata and project info:
    projects                Lists all known projects.
    status      [<project>] Shows status of <project> (defaults to all).
    info         <project>  Displays detailed description of <project>.
    metadata     <project>  Displays JSON metadata for <project>.
    show-deps    <project>  Shows dependencies for <project>.
    project-dir  <project>  Displays top directory for <project>.

  Perform actions on a project:
    fetch        <project>  Downloads source code for <project>.
    update       <project>  Updates source code for <project> (falls back to fetch).
    configure    <project>  Configures source code for <project> (runs 'update' first).
    build        <project>  Builds <project> in current directory (runs 'configure' first).
    test         <project>  Runs test suite for <project> (runs 'build' first).
    smoke        <project>  Sends test results to Parrot's Smolder server (runs 'build' first).
    install      <project>  Installs <project> (runs 'test' first).
    uninstall    <project>  Uninstalls <project> from system (not always available).
    clean        <project>  Performs basic cleanup of source tree for <project>.
    realclean    <project>  Removes all generated files during the build process for <project>.

  Get information about Plumage:
    version                 Displays Plumage version and copyright statement.
    help        [<command>] Displays a help message on <command> usage (defaults to all).
";
}

sub command_help($help_cmd, :$command) {
    if ?$help_cmd {
        my $usage := %COMMANDS{$help_cmd[0]}.usage;
        my $help  := %COMMANDS{$help_cmd[0]}.help;

        say("$usage\n");
        say($help);
    }
    else {
        command_usage();
    }
}

sub command_cli() {
    pir::load_bytecode('Plumage/Interactive.pbc');

    my $session := Plumage::Interactive.new;

    my $command := $session.prompt('plumage');

    say("COMMAND: $command");
}

sub command_version() {
    print(version_info());
}

sub version_info() {
    my $version := '0';
    return
"This is Plumage, version $version.

Copyright (C) 2009-2011, Parrot Foundation.

This code is distributed under the terms of the Artistic License 2.0.
For more details, see the full text of the license in the LICENSE file
included in the Plumage source tree.
";
}

sub command_projects() {
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

sub command_status(@projects, :$command) {
    my $showing_all := !@projects;

    unless @projects {
        @projects := Plumage::Metadata.get_project_list();
        say("Known projects:\n");
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

sub command_info(@projects, :$command) {
    unless (@projects) {
        say('Please include the name of the project you wish info for.');
    }

    for @projects -> $project {
        my $meta  := Plumage::Metadata.new();
        my $valid := $meta.find_by_project_name($project);

        if $valid {
            if $command ~~ /metadata/ {
                _dumper($meta.metadata, 'METADATA');
            }
            else {
                print_project_summary($meta.metadata);
            }
        }
        else {
            report_metadata_error($project, $meta);
        }
    }
}

sub command_show_deps(@projects, :$command) {
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

sub report_metadata_error($project_name, $meta) {
    say("Metadata error for project '$project_name':\n" ~ $meta.error);
}

sub command_project_dir(@projects, :$command) {
    unless (@projects) {
        say('Please include the name of the project you wish to find.');
    }

    for @projects -> $project_name {
        my $project := Plumage::Project.new($project_name);

        say($project.source_dir) if pir::defined__IP($project);
    }
}

sub command_project_action(@projects, :$command) {
       install_required_projects(@projects)
    && perform_actions_on_projects(@projects, :up_to($command));
}

sub install_required_projects(@projects) {
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

sub show_dependencies(@projects) {
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
        # XXX Don't forget to fix this when metadata is retrieved from server

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

sub perform_actions_on_projects(@projects, :$up_to, :@actions) {
    my $has_ignore_flag := %OPTIONS.exists('IGNORE_FAIL');
    my %ignore          := %OPTIONS<IGNORE_FAIL>;
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

sub print_project_summary($meta) {
    my %general     := $meta<general>;

    my $name        := %general<name>;
    my $version     := %general<version> // "HEAD";
    my $summary     := %general<abstract>;
    my $author      := %general<copyright_holder>;
    my $url         := %general<authority>;
    my $license     := %general<license><type>;
    my $description := %general<description>;

    say(pir::sprintf__SsP("%-11s : %s", ["Name",        $name]));
    say(pir::sprintf__SsP("%-11s : %s", ["Version",     $version]));
    say(pir::sprintf__SsP("%-11s : %s", ["Summary",     $summary]));
    say(pir::sprintf__SsP("%-11s : %s", ["Author",      $author]));
    say(pir::sprintf__SsP("%-11s : %s", ["URL",         $url]));
    say(pir::sprintf__SsP("%-11s : %s", ["License",     $license]));
    say(pir::sprintf__SsP("%-11s : %s", ["Description", $description]));
}

sub MAIN() {
    parse_command_line_options();
    read_config_files();
    find_binaries();

    if %OPTIONS.exists('HELP') {
        execute_command('help');
    }
    else {
        my $command := parse_command_line();
        execute_command($command);
    }
}

# vim: ft=perl6
