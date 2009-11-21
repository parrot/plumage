=begin

=head1 NAME

Plumage::Metadata - Project metadata: find it, parse it, query it

=head1 SYNOPSIS

    # Load this library
    pir::load_bytecode('src/lib/Plumage/Metadata.pbc');

    # Get list of known project names (regardless of install status)
    my @projects := Plumage::Metadata.get_project_list();

    # Instantiate a new metadata object
    my $metadata := Plumage::Metadata.new();

    # Can we find metadata in the usual place under this directory?
    my $found := $metadata.exists($project_directory);

    # What *is* the usual place to find metadata within a project?
    my $path  := $metadata.project_metadata_path($project_directory);

    # Load and parse a project's default metadata file
    my $valid := $metadata.load_from_project_dir($project_directory);

    # Load and parse a particular metadata file
    my $valid := $metadata.load_from_file($metadata_file_path);

    # Parse metadata that is already in string form
    # XXXX: NYI
    my $valid := $metadata.load_from_string($serialized_metadata);

    # Search for, fetch, and parse metadata given a project's name
    my $valid := $metadata.find_by_project_name($project_name);

    # Have we loaded, parsed, and validated proper metadata?
    my $valid := $metadata.is_valid;

    # If not valid, what error caused the failure?
    my $error := $metadata.error;


=head1 DESCRIPTION

=end

class Plumage::Metadata;


# ATTRIBUTES AND ACCESSORS

has %!metadata;
has $!valid;
has $!error;

method is_valid () { ?$!valid    }
method error    () {  $!error    }
method metadata () {  %!metadata }


# CLASS METHODS

method get_project_list () {
    my @files := readdir(replace_config_strings(%*CONF<plumage_metadata_dir>));
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


# INSTANCE METHODS

method project_metadata_path ($dir?) {
    my @dir  := pir::length($dir) ?? [$dir, 'plumage']
                                  !! [      'plumage'];
    my $path := fscat(@dir, 'metadata.json');

    return $path;
}

method exists ($dir?) {
    return path_exists(self.project_metadata_path($dir));
}

method find_by_project_name ($project_name) {
    my $meta_dir := replace_config_strings(%*CONF<plumage_metadata_dir>);

    return self.load_from_file(fscat([$meta_dir], "$project_name.json"));
}

method load_from_project_dir ($dir) {
    return self.load_from_file(self.project_metadata_path($dir));
}

# XXXX: Need to fix try() syntax
method load_from_file ($path) {
    %!metadata := try(Config::JSON::ReadConfig, [$path],
                      -> $e, &c, @args {
    $!error := "Failed to parse metadata file '{ @args[0] }': $e";

    return 0;
});

    return self.validate;
}

method validate () {
    $!valid := %!metadata
            && self.metadata_spec_known
            && self.metadata_instruction_types_known;

    $!error := '' if $!valid;

    return $!valid;
}

method metadata_spec_known () {
    my %spec          := %!metadata<meta-spec>;
    my $known_uri     := 'https://trac.parrot.org/parrot/wiki/ModuleEcosystem';
    my $known_version := 1;

    unless %spec && %spec<uri> {
        $!error := "I don't understand this project's metadata at all.";
        return 0;
    }

    unless %spec<uri> eq $known_uri {
        $!error := "This project's metadata specifies unknown metadata spec "
                 ~ "URI '{%spec<uri>}'.";
        return 0;
    }

    if    %spec<version> == $known_version {
        return 1;
    }
    elsif %spec<version>  > $known_version {
        $!error := "This project's metadata is too new to parse; it is version "
            ~ %spec<version> ~ " and I only understand version $known_version.";
    }
    else {
        $!error := "This project's metadata is too old to parse; it is version "
            ~ %spec<version> ~ " and I only understand version $known_version.";
    }

    return 0;
}

method metadata_instruction_types_known () {
    my %inst := %!metadata<instructions>;

    unless %inst && %inst.keys {
        $!error := "This project has no instructions.";
        return 0;
    }

    for %inst.keys -> $stage {
        my $type   := %inst{$stage}<type>;
        my $action := %*ACTION{$stage}{$type};

        unless $action {
            my @types := %*ACTION{$stage}.keys;
            my $types := join(', ', @types);

            $!error := "I don't understand $stage type '$type'.\n"
                     ~ "I only understand these types: $types";
            return 0;
        }
    }

    return 1;
}
