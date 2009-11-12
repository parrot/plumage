=begin

=head1 NAME

Metadata.nqp - Metadata-handling functions for Plumage

=head1 SYNOPSIS

    # Load this library
    pir::load_bytecode('src/lib/Metadata.pbc');

    # Functions
    @projects := get_project_list()
    %info     := get_project_metadata($project, $ignore_missing)
    $is_valid := metadata_valid(%info)


=head1 DESCRIPTION

=end

our %CONF;
our %ACTION;

=begin

=head2 Functions

=over 4

=item @projects := get_project_list()

Return a list of project names currently known to Plumage, regardless of
whether they are currently installed or not.  Each name is suitable for passing
to C<get_project_metadata()> to obtain more details.

=end

sub get_project_list () {
    my @files := readdir(replace_config_strings(%CONF<plumage_metadata_dir>));
    my $regex := rx('\.json$');
    my @projects;

    for @files -> $file {
        if $regex($file) {
            my $project := subst($file, $regex, '');
            @projects.push($project);
        }
    }

    return @projects;
}

=begin

=item %info := get_project_metadata($project, $ignore_missing)

Return metadata for the project named C<$project>.  Returns a false value if no
such project is known, and also outputs an error message unless
C<$ignore_missing> is true.

=end

sub get_project_metadata ($project, $ignore_missing) {
    my $meta_dir  := replace_config_strings(%CONF<plumage_metadata_dir>);
    my $json_file := fscat([$meta_dir], "$project.json");

    unless path_exists($json_file) {
        unless $ignore_missing {
            say("I don't know anything about project '$project'.");
        }
        return 0;
    }

    return try(Config::JSON::ReadConfig, [$json_file],
               show_metadata_parse_error);
}

sub show_metadata_parse_error ($exception, &code, @args) {
    say("Failed to parse metadata file '{ @args[0] }': $exception");

    return 0;
}

=begin

=item $is_valid := metadata_valid(%info)

Check that the metadata returned by C<get_project_metadata()> is understood and
seems otherwise valid.  Returns a true value if all tests pass, or a false value
if not.  Also outputs error messages and hints to the user for any problems
found.

=end

sub metadata_valid (%info) {
    return metadata_spec_known(%info)
        && metadata_instruction_types_known(%info);
}

sub metadata_spec_known (%info) {
    my %spec          := %info<meta-spec>;
    my $known_uri     := 'https://trac.parrot.org/parrot/wiki/ModuleEcosystem';
    my $known_version := 1;

    unless %spec && %spec<uri> {
        say("I don't understand this project's metadata at all.");
        return 0;
    }

    unless %spec<uri> eq $known_uri {
        say("This project's metadata specifies unknown metadata spec URI '{ %spec<uri> }'.");
        return 0;
    }

    if    %spec<version> == $known_version {
        return 1;
    }
    elsif %spec<version>  > $known_version {
        say("This project's metadata is too new to parse; it is version "
            ~ "{ %spec<version> } and I only understand version $known_version.");
    }
    else {
        say("This project's metadata is too old to parse; it is version "
            ~ "{ %spec<version> } and I only understand version $known_version.");
    }

    return 0;
}

sub metadata_instruction_types_known (%info) {
    my %inst   := %info<instructions>;
    my @stages := %inst.keys;

    unless %inst && @stages {
        say("This project has no instructions.");
        return 0;
    }

    for @stages -> $stage {
        my $type   := %inst{$stage}<type>;
        my $action := %ACTION{$stage}{$type};

        unless $action {
            my @types := %ACTION{$stage}.keys;
            my $types := join(', ', @types);

            say("I don't understand $stage type '$type'.\n"
                ~ "I only understand these types: $types");

            return 0;
        }
    }

    return 1;
}

=begin

=back

=end
