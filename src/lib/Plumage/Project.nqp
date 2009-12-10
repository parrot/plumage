=begin

=head1 NAME

Plumage::Project - A project, its metadata, and its state

=head1 SYNOPSIS

    # Load this library
    pir::load_bytecode('src/lib/Plumage/Project.pbc');

    # Instantiate a project, given name, metadata file, directory, or 'this'
    my $project := Plumage::Project.new('foo');       # By name
    my $project := Plumage::Project.new('foo.json');  # By metadata
    my $project := Plumage::Project.new('git/foo');   # By specific directory
    my $project := Plumage::Project.new('this');      # By current directory

    # Perform multiple actions on a project in sequence, stopping on failure
    $project.perform_actions(:$up_to, :@actions, :$ignore_all, :%ignore);

    # Perform individual actions on a project
    $project.fetch;
    $project.update;
    $project.configure;
    $project.build;
    $project.test;
    $project.smoke;
    $project.install;
    $project.uninstall;
    $project.clean;
    $project.realclean;


=head1 DESCRIPTION

=end

class Plumage::Project;

has $!name;
has $!metadata;
has $!source_dir;

method name       () { $!name       }
method metadata   () { $!metadata   }
method source_dir () { $!source_dir }


# CONSTRUCTION

method new($locator) {
    my $class := pir::getattribute__PPs(self.HOW, 'parrotclass');
    Q:PIR{ $P0  = find_lex '$class'
           self = new $P0           };

    return self._init($locator);
}


method _init($locator) {
    $!metadata     := Plumage::Metadata.new;
    my $build_root := replace_config_strings(%*CONF<plumage_build_root>);
    my $undef;

    if $locator eq 'this' {
        $!source_dir := self._find_source_dir();
        $!metadata.load_from_project_dir($!source_dir);
    }
    elsif is_dir($locator) {
        $!source_dir := self._find_source_dir($locator);
        $!metadata.load_from_project_dir($!source_dir);
    }
    elsif pir::length($locator) > 5
       && pir::substr($locator, -5, 5) eq '.json' {
        $!metadata.load_from_file($locator);

        my $file_dir := subst($locator, rx('<-[/]>+$'), '');
        $!source_dir := self._find_source_dir($file_dir);
    }
    elsif $!metadata.find_by_project_name($locator) {
        $!source_dir := fscat([$build_root], $locator);
    }
    else {
        say("I don't know anything about project '$locator'.");
        return $undef;
    }

    unless $!metadata.is_valid {
        say("Could not read project metadata for locator '$locator':\n"
            ~ $!metadata.error);
        return $undef;
    }

    $!name       := $!metadata.metadata<general><name>;
    $!source_dir := fscat([$build_root], $!name)
                    unless pir::length($!source_dir);

    return self;
}


method _find_source_dir($start_dir?) {
    my $orig_dir := cwd();

    chdir($start_dir) if pir::length($start_dir);

    my $old_dir  := '';

    until $old_dir eq cwd() || $!metadata.exists {
        $old_dir := cwd();
        chdir('..');
    }

    my $source_dir := $!metadata.exists ?? cwd() !! '';

    chdir($orig_dir);

    return $source_dir;
}

###
### ACTIONS
###

sub _build_stages () {
    our %STAGES;
    my @stages := pir::split(' ', 'install test build configure fetch');

    for @stages -> $stage {
        %STAGES{$stage} := [];

        for %STAGES {
            $_.value.unshift($stage);
        }
    }
}

method _actions_up_to ($stage) {
    our %STAGES;
    _build_stages();

    return %STAGES{$stage};
}

method perform_actions (:$up_to, :@actions, :$ignore_all, :%ignore) {
    if $up_to && @actions {
        die("Cannot specify both up_to and actions in perform_actions()");
    }
    elsif $up_to {
        @actions := self._actions_up_to($up_to);
    }

    for @actions -> $action {
        if self.HOW.can(self, $action) {
           my $cwd    := cwd();
           my $result := self."$action"();
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
           return 0;
        }
    }

    return 1;
}


# FETCH

method fetch () {
    my %fetch := $!metadata.metadata<instructions><fetch>;
    if %fetch {
        my $build_root := replace_config_strings(%*CONF<plumage_build_root>);

        mkpath($build_root) if !is_dir($build_root)
                            && pir::index($!source_dir, $build_root) == 0;

        return self."fetch_{%fetch<type>}"();
    }
    else {
        say("Don't know how to fetch $!name.");
        return 0;
    }
}

method fetch_repository () {
    my %repo := $!metadata.metadata<resources><repository>;
    if %repo {
        say("Fetching $!name ...");

        return self."fetch_{%repo<type>}"();
    }
    else {
        say("Trying to fetch from a repository, but no repository info for $!name.");
        return 0;
    }
}

method fetch_git () {
    if path_exists($!source_dir) {
        if path_exists(fscat([$!source_dir, '.git'])) {
            chdir($!source_dir);
            return do_run(%*BIN<git>, 'pull');
        }
        else {
            return self.report_fetch_collision('Git');
        }
    }
    else {
        my $uri := $!metadata.metadata<resources><repository><checkout_uri>;

        return do_run(%*BIN<git>, 'clone', $uri, $!source_dir);
    }
}

method fetch_svn () {
    if  path_exists($!source_dir)
    && !path_exists(fscat([$!source_dir, '.svn'])) {
        return report_fetch_collision('Subversion');
    }
    else {
        my $uri := $!metadata.metadata<resources><repository><checkout_uri>;

        return do_run(%*BIN<svn>, 'checkout', $uri, $!source_dir);
    }
}

method report_fetch_collision ($type) {
    say("\n$!name is a $type project, but the fetch directory:\n"
        ~ "\n    $!source_dir\n\n"
        ~ "already exists and is not the right type.\n"
        ~ "Please remove or rename it, then rerun $*PROGRAM_NAME.\n");

    return 0;
}


# UPDATE

method update () {
    my %update := $!metadata.metadata<instructions><update>;
    if %update {
        return self."update_{%update<type>}"();
    }
    else {
        # Fall back to standard FETCH semantics
        return self.fetch;
    }
}

method update_repository () {
    my %repo := $!metadata.metadata<resources><repository>;
    if %repo {
        say("Updating $!name ...");

        # Reuse existing FETCH logic
        return self."fetch_{%repo<type>}"();
    }
    else {
        say("Trying to update from a repository, but no repository info for $!name.");
        return 0;
    }
}


# CONFIGURE

method configure () {
    my %conf := $!metadata.metadata<instructions><configure>;
    if %conf {
        say("\nConfiguring $!name ...");

        chdir($!source_dir);

        return self."configure_{%conf<type>}"();
    }
    else {
        say("\nConfiguration not required for $!name.");
        return 1;
    }
}

method configure_rake () {
    return do_run(%*BIN<rake>, 'config');
}

method configure_perl5_configure () {
    my $extra := $!metadata.metadata<instructions><configure><extra_args>;
    my @extra := map(replace_config_strings, $extra);

    return do_run(%*BIN<perl5>, 'Configure.pl', |@extra);
}

method configure_parrot_configure () {
    return do_run(%*BIN<parrot>, 'Configure.pir');
}

method configure_nqp_configure () {
    return do_run(%*BIN<parrot-nqp>, 'Configure.nqp');
}


# BUILD

method build () {
    my %build := $!metadata.metadata<instructions><build>;
    if %build {
        say("\nBuilding $!name ...");

        chdir($!source_dir);

        return self."build_{%build<type>}"();
    }
    else {
        say("\nBuild not required for $!name.");
        return 1;
    }
}

method build_make () {
    return do_run(%*BIN<make>);
}

method build_rake () {
    return do_run(%*BIN<rake>);
}

method build_parrot_setup () {
    return do_run(%*BIN<parrot>, 'setup.pir');
}


# TEST

method test () {
    my %test := $!metadata.metadata<instructions><test>;
    if %test {
        say("\nTesting $!name ...");

        chdir($!source_dir);

        return self."test_{%test<type>}"();
    }
    else {
        say("\nNo test method found for $!name.");
        return 1;
    }
}

method test_make () {
    return do_run(%*BIN<make>, 'test');
}

method test_rake () {
    return do_run(%*BIN<rake>, 'test');
}

method test_parrot_setup () {
    return do_run(%*BIN<parrot>, 'setup.pir', 'test');
}


# SMOKE

method smoke () {
    my %smoke := $!metadata.metadata<instructions><smoke>;
    if %smoke {
        say("\nSmoke testing $!name ...");

        chdir($!source_dir);

        return self."smoke_{%smoke<type>}"();
    }
    else {
        say("\nNo smoke test method found for $!name.");
        return 1;
    }
}

method smoke_make () {
    return do_run(%*BIN<make>, 'smoke');
}

method smoke_parrot_setup () {
    return do_run(%*BIN<parrot>, 'setup.pir', 'smoke');
}


# INSTALL

method install () {
    my %inst := $!metadata.metadata<instructions><install>;
    if %inst {
        say("\nInstalling $!name ...");

        chdir($!source_dir);

        my $success := self."install_{%inst<type>}"();

        if $success {
            Plumage::Dependencies.mark_projects_installed([$!name]);
        }

        return $success;
    }
    else {
        say("Don't know how to install $!name.");
        return 0;
    }
}

method install_make () {
    return self.do_with_privs(%*BIN<make>, 'install');
}

method install_rake () {
    return self.do_with_privs(%*BIN<rake>, 'install');
}

method install_parrot_setup () {
    return self.do_with_privs(%*BIN<parrot>, 'setup.pir', 'install');
}


# UNINSTALL

method uninstall () {
    my %uninst := $!metadata.metadata<instructions><uninstall>;
    if %uninst {
        say("\nUninstalling $!name ...");

        chdir($!source_dir);

        my $success := self."uninstall_{%uninst<type>}"();

        if $success {
            Plumage::Dependencies.mark_projects_uninstalled([$!name]);
        }

        return $success;
    }
    else {
        say("Don't know how to uninstall $!name.");
        return 0;
    }
}

method uninstall_parrot_setup () {
    return self.do_with_privs(%*BIN<parrot>, 'setup.pir', 'uninstall');
}

method do_with_privs (*@cmd) {
    my $bin_dir  := %*VM<config><bindir>;
    my $root_cmd := replace_config_strings(%*CONF<root_command>);

    if !test_dir_writable($bin_dir) && $root_cmd {
        return do_run($root_cmd, |@cmd);
    }
    else {
        return do_run(|@cmd);
    }
}


# CLEAN

method clean () {
    my %clean := $!metadata.metadata<instructions><clean>;
    if %clean {
        say("\nCleaning $!name ...");

        chdir($!source_dir);

        return self."clean_{%clean<type>}"();
    }
    else {
        say("\nNo clean method found for $!name.");
        return 1;
    }
}

method clean_make () {
    return do_run(%*BIN<make>, 'clean');
}

method clean_rake () {
    return do_run(%*BIN<rake>, 'clean');
}

method clean_parrot_setup () {
    return do_run(%*BIN<parrot>, 'setup.pir', 'clean');
}



# REALCLEAN

method realclean () {
    my %realclean := $!metadata.metadata<instructions><realclean>;
    if %realclean {
        say("\nRealcleaning $!name ...");

        chdir($!source_dir);

        return self."realclean_{%realclean<type>}"();
    }
    else {
        say("\nNo realclean method found for $!name.");
        return 1;
    }
}

method realclean_make () {
    return do_run(%*BIN<make>, 'realclean');
}

method realclean_rake () {
    return do_run(%*BIN<rake>, 'clobber');
}

