=begin

=head1 NAME

Plumage::Metadata - Project metadata: find it, parse it, query it

=head1 SYNOPSIS

    # Load this library
    pir::load_bytecode('src/lib/Plumage/Metadata.pbc');

    # Class Methods
    my @projects := Plumage::Metadata.get_project_list;
    my $found    := Plumage::Metadata.exists($project_directory);
    my $path     := Plumage::Metadata.project_metadata_path($project_directory);
    my $meta     := Plumage::Metadata.new;

    # Accessors
    my $valid := $meta.is_valid;
    my $error := $meta.error;
    my $data  := $meta.metadata;

    # Search / Load / Parse
    my $valid := $meta.find_by_project_name($project_name);
    my $valid := $meta.load_from_project_dir($project_directory);
    my $valid := $meta.load_from_file($metadata_file_path);
    my $valid := $meta.load_from_string($serialized_metadata);


=head1 DESCRIPTION

=end

class Plumage::Metadata;


=begin

=head2 Class Methods

=over 4

=item @projects := Plumage::Metadata.get_project_list

Return a list of project names currently known to Plumage, regardless of
whether they are currently installed or not.  Each name is suitable for
passing to C<$meta.find_by_project_name()> to obtain more details.

=end

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


=begin

=item $found := Plumage::Metadata.exists($project_directory?)

Determine if a Plumage metadata file exists in a given C<$project_directory>.
If the directory is omitted, the current directory is assumed to be the
top of the project.  Uses C<project_metadata_path> to determine the default
location for Plumage metadata files.

=end

method exists ($dir?) {
    return path_exists(self.project_metadata_path($dir));
}


=begin

=item $path := Plumage::Metadata.project_metadata_path($project_directory?)

Determine the correct path to the default location for Plumage metadata
within a project tree.  If the C<$project_directory> is provided, it is
included as the leading portion of the returned C<$path>.  If it is omitted,
the C<$path> will be the generic default location relative to a project root.

=end

method project_metadata_path ($dir?) {
    my @dir  := pir::length($dir) ?? [$dir, 'plumage']
                                  !! [      'plumage'];
    my $path := fscat(@dir, 'metadata.json');

    return $path;
}


=begin

=item $meta := Plumage::Metadata.new

Instantiate a new, empty metadata object.

=back


=head2 Accessors

=over 4

=item $valid := $meta.is_valid

True if C<$meta> has loaded, parsed, and validated proper metadata, false
otherwise.

=item $error := $meta.error

If not valid, what error caused the failure?  Resets to empty when the object
successfully loads and parses valid metadata.

=item $data  := $meta.metadata

Fetch the actual data structure from the metadata object.

=back

=end

has %!metadata;
has $!valid;
has $!error;

method is_valid () { ?$!valid    }
method error    () {  $!error    }
method metadata () {  %!metadata }


=begin

=head2 Search / Load / Parse

After creating an empty metadata object using C<new>, use these methods to load
metadata for a particular project.  Each finds the metadata by a different
method, but all eventually return a boolean C<$value> indicating whether valid
metadata was successfully loaded and parsed.  If the C<$value> is false, use
the C<error> accessor to determine what went wrong; otherwise, use the
C<metadata> accessor to retrieve the loaded data structure.

=over 4

=item $valid := $meta.find_by_project_name($project_name)

Find metadata using the project's name, in the format retrieved by
C<get_project_list>.

=end

method find_by_project_name ($project_name) {
    my $meta_dir  := replace_config_strings(%*CONF<plumage_metadata_dir>);
    my $meta_file := fscat([$meta_dir], "$project_name.json");

    unless path_exists($meta_file) {
        $!error    := "I don't know anything about project '$project_name'.";
        %!metadata := 0;
        return 0;
    }

    return self.load_from_file($meta_file);
}


=begin

=item $valid := $meta.load_from_project_dir($project_directory)

Given the directory path for the top level of a project, load and parse the
project's metadata from the default metadata file location (determined using
C<project_metadata_path>).

=end

method load_from_project_dir ($dir) {
    return self.load_from_file(self.project_metadata_path($dir));
}


=begin

=item $valid := $meta.load_from_file($metadata_file_path)

Load and parse a particular metadata file.

=end

method load_from_file ($path) {
    %!metadata := Config::JSON::ReadConfig($path);

    return self.validate;

    CATCH {
        $!error    := "Failed to parse metadata file '$path': $!";
        %!metadata := 0;
        return 0;
    }
}


=begin

=item $valid := $meta.load_from_string($serialized_metadata)

Parse metadata that is already in string form.

=end

method load_from_string($serialized) {
    %!metadata := eval($serialized, 'data_json');

    return self.validate;

    CATCH {
        $!error    := "Failed to parse metadata string: $!";
        %!metadata := 0;
        return 0;
    }
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

    my @known_actions := Plumage::Project.known_actions;
    my %valid_action  := set_from_array(@known_actions);

    for %inst.keys -> $action {
        unless %valid_action{$action} {
            $!error := "I don't understand project action '$action'."
                       ~ "  I only know about these actions:\n    "
                       ~ pir::join(' ', @known_actions);
            return 0;
        }

        my $type := %inst{$action}<type>;
        unless $type {
            $!error := "This project's '$action' action has no type.";
            return 0;
        }

        my $exists := Plumage::Project.HOW.can(Plumage::Project,
                                               "{$action}_$type");
        unless $exists {
            # XXXX: It would be useful if this listed known types also.
            $!error := "I don't understand $action type '$type'.";
            return 0;
        }
    }

    return 1;
}
