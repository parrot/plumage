# Copyright (C) 2011, Parrot Foundation.

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
my %COMMANDS := hash(
    help      => Plumage::Command.new(:action(command_help),
                                      :args('opt_command'),
                                      :usage('help [<command>]'),
                                      :help('Displays a help message on <command> usage '
                                          ~ '(defaults to all).')),

    pack      => Plumage::Command.new(:action(command_pack),
                                      :args('featherspec'),
                                      :usage('pack <featherspec>'),
                                      :help('Builds a source feather from the metadata '
                                          ~ 'in <featherspec>.')),

    unpack    => Plumage::Command.new(:action(command_unpack),
                                      :args('feather'),
                                      :usage('unpack <feather>'),
                                      :help('Unpacks <feather> into current directory.')));

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

# XXX Can these be moved to beginning of file?
my %*CONF;       # Configuration options
my %*BIN;        # System binaries

sub execute_command($command) {
    my $action := %COMMANDS{$command}.action;
    my $args   := %COMMANDS{$command}.args;

    if $action {
        # Make sure an argument was given, if required
        if !($args ~~ /opt_\w+/) && !@*ARGS {
            my $error := "Invalid argument, '$command' requires a $args.";

            output_error($error);
            pir::exit__vi(1);
        }
        else {
            $action(@*ARGS, :command($command));
        }
    }
    else {
        output_error("No such command: $command. Please use `$*PROGRAM_NAME --help`.");
        pir::exit__vi(1);
    }
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

sub get_version() {
    my $file := 'VERSION';
    my $version;

    # Read string from 'VERSION' and store it in $version
    Q:PIR {
        $P0 = find_lex '$file'
        $S0 = $P0

        load_bytecode 'String/Utils.pbc'

        $P1 = new 'FileHandle'
        $S1 = $P1.'readall'($S0)
        $P1.'close'()

        .local pmc chomp
        chomp = get_global ['String';'Utils'], 'chomp'

        $S1 = chomp($S1)
        $P2 = new 'String'
        $P2 = $S1

        store_lex '$version', $P2
    };

    return $version;
}

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

    # Represents feathers
    pir::load_bytecode('Plumage/Feather.pbc');

    # Represents featherspec files
    pir::load_bytecode('Plumage/FeatherSpec.pbc');
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

sub output_error($msg) {
    $msg := '[ERROR] ' ~ $msg;

    Q:PIR {
        $P0  = find_lex '$msg'
        $S0  = $P0
        $S0 .= "\n"

        $P0  = getinterp
        $P1  = $P0.'stderr_handle'()
        $P1.'print'($S0)
    };
}

sub parse_command_line() {
    return @*ARGS ?? @*ARGS.shift !! 'help';
}

sub parse_command_line_options() {
    my $getopt := pir::root_new__PP(< parrot Getopt Obj >);

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

sub usage() {
    say(
"Usage: $*PROGRAM_NAME [<options>] <command> [<arguments>]

Options:

    -h, --help       Displays a help message on command usage.
    -s, --source     Builds source feather (default).
    -b, --binary     Builds binary feather ('pack' only).
    -v, --no-verify  Do not verify SHA256 digest.

Commands:

    help   [<command>]    Displays a help message on <command> usage (defaults to all).
    pack   <featherspec>  Builds a source feather from the metadata in <featherspec>.
    unpack <feather>      Unpacks <feather> into current directory.");
}

###
### COMMANDS
###
### Each of the following subroutines represents an individual command recognized
### by `plumage-admin` (note the command_* prefix followed by the actual command
### name)
###

sub command_help($help_cmd, :$command) {
    if ?$help_cmd {
        my $usage := %COMMANDS{$help_cmd[0]}.usage;
        my $help  := %COMMANDS{$help_cmd[0]}.help;

        # Check that command actually exists
        if ($usage eq '') || ($help eq '') {
            usage();
        }
        else {
            say("$usage\n\n$help");
        }
    }
    else {
        usage();
    }
}

sub command_pack(@args, :$command) {
    # Make sure file is a featherspec
    if !(@args[0] ~~ /^FEATHER\.spec$/) {
        output_error('File ' ~ @args[0] ~ ' is not a featherspec.');
        pir::exit__vi(1);
    }

    my $featherspec := Plumage::FeatherSpec.new(:filename(@args[0]));

    if $featherspec.parse {
        # XXX Do something
    }
    else {
        output_error($featherspec.error);
    }
}

sub command_unpack(@args, :$command) {
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
