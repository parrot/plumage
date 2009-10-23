=head1 NAME

Metadata.nqp - Metadata-handling functions for Plumage


=head1 SYNOPSIS

    # Load this library
    load_bytecode('src/lib/Metadata.pbc');


=head1 DESCRIPTION

=cut

our %CONF;
our %ACTION;

sub get_project_list () {
    my @files := readdir(replace_config_strings(%CONF<plumage_metadata_dir>));
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
    my $meta_dir  := replace_config_strings(%CONF<plumage_metadata_dir>);
    my $json_file := fscat(as_array($meta_dir), $project ~ '.json');

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

sub metadata_instruction_types_known (%info) {
    my %inst   := %info<instructions>;
    my @stages := keys(%inst);

    unless %inst && @stages {
        say("This project has no instructions.");
        return 0;
    }

    for @stages {
        my $type   := %inst{$_}<type>;
        my $action := %ACTION{$_}{$type};

        unless $action {
            my @types := keys(%ACTION{$_});
            my $types := join(', ', @types);

            say("I don't understand " ~ $_ ~ " type '" ~ $type ~ "'.\n"
                ~ "I only understand these types: " ~ $types);

            return 0;
        }
    }

    return 1;
}

