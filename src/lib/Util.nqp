=begin

=head1 NAME

Util.nqp - Utility functions for NQP and Plumage

=head1 SYNOPSIS

    # Load this library
    pir::load_bytecode('src/lib/Util.pbc');

    # Hash methods
    $found     := %hash.exists($key);
    @keys      := %hash.keys;
    @values    := %hash.values;
    @flattened := %hash.kv;

    # Array methods
    @reversed := @array.reverse;

    # Basics
    @mapped  := map( &code, @originals);
    @matches := grep(&code, @all)

    # General
    %set := set_from_array(@array);

    # Duct tape
    $binary_path := find_program($program);
    mkpath($directory_path);
    $writable := test_dir_writable($directory_path);
    $home := user_home_dir();

    # Plumage-specific
    $replaced := replace_config_strings($original);


=head1 DESCRIPTION

=end

our $PROGRAM_NAME;
our @ARGS;
our %ENV;
our %VM;
our %BIN;
our %CONF;
our $OS;


=begin

=head2 Hash Methods

These methods extend the native NQP Hash class to support more of the basic
functionality expected for Perl 6 Hashes.

=end

module Hash {

=begin

=over 4

=item $found := %hash.exists($key)

Return a true value if C<$key> exists in C<%hash>, or a false value otherwise.

=end

    method exists ($key) {
        return Q:PIR{
            $P1 = find_lex '$key'
            $I0 = exists self[$P1]
            %r  = box $I0
        };
    }

=begin

=item @keys := %hash.keys

Return all the C<@keys> in the C<%hash> as an unordered array.

=end

    method keys () {
        my @keys;
        for self { @keys.push($_.key); }
        @keys;
    }

=begin

=item @values := %hash.values

Return all the C<@values> in the C<%hash> as an unordered array.

=end

    method values () {
        my @values;
        for self { @values.push($_.value); }
        @values;
    }

=begin

=item @flattened := %hash.kv

Flatten C<%hash> into an array, alternating key and value.  This is useful
when iterating over key and value simultaneously:

    for %hash.kv -> $k, $v { ... }

=end

    method kv () {
        my @kv;
        for self { @kv.push($_.key); @kv.push($_.value); }
        @kv;
    }

=begin

=back

=end

}


=begin

=head2 Array Methods

These methods extend the native NQP Array class to support more of the basic
functionality expected for Perl 6 Hashes.

=end

module Array {

=begin

=over 4

=item @reversed := @array.reverse

Return a C<@reversed> copy of the C<@array>.

=end

    method reverse () {
        my @reversed;
        for self { @reversed.unshift($_); }
        @reversed;
    }

=begin

=back

=end

}


=begin

=head2 Basic Functions

These functions provide basic functionality that would be part of the standard
setting in Perl 6, but are not provided with NQP by default.  Functions that
cannot be easily implemented in pure NQP are instead provided by C<Glue.pir>.

=over 4

=item @mapped := map(&code, @originals)

Pretty much as you would expect, except there is no flattening or other
coersion, due to the current semantics of NQP.  This means that every
application of C<&code> to an item in the C<@originals> produces exactly
one entry in the C<@mapped> output.

=end

sub map (&code, @originals) {
    my @mapped;

    for @originals {
        @mapped.push(&code($_));
    }

    return @mapped;
}

=begin

=item @matches := grep(&code, @all)

Select all members of C<@all> for which C<&code($member)> returns true.
Order is retained, and duplicates are handled independently.

=end

sub grep (&code, @all) {
    my @matches;

    for @all {
        @matches.push($_) if &code($_);
    }

    return @matches;
}

=begin

=head2 General Utilities

While these would not exist in the Perl 6 setting, they are still generally
useful for NQP programs because NQP syntax is considerably more wordy than
Perl 6.  DRY thus applies.

=over 4

=item %set := set_from_array(@array)

Converts an array into a set by using the array elements as hash keys and
setting their corresponding value to 1, thus allowing cheap set membership
checks.

=end

sub set_from_array (@array) {
    my %set;

    for @array {
        %set{$_} := 1;
    }

    return %set;
}


=begin

=back


=head2 Duct Tape Functions

These functions provide convenient ways to interact with the file system,
other processes, and similar operating system constructs.

=over 4

=item $binary_path := find_program($program)

Search C<%ENVE<lt>PATHE<gt>> to find the full path for a given C<$program>.  If
the program is not found, C<find_program()> returns an empty path string,
which is false in boolean context.  Thus this is typically used in the
following way:

    my $path := find_program($program);
    if $path {
        # Found it, run it with some options
    }
    else {
        # Not found, try a different $program or fail
    }

=end

sub find_program ($program) {
    my $path_sep := $OS eq 'MSWin32' ?? ';' !! ':';
    my @paths    := split($path_sep, %ENV<PATH>);
    my @exts     := split($path_sep, %ENV<PATHEXT>);

    @exts.unshift('');

    for @paths -> $dir {
        my $path := fscat([$dir], $program);

        for @exts -> $ext {
            my $pathext := "$path$ext";
            return $pathext if path_exists($pathext);
        }
    }

    return '';
}

=begin

=item mkpath($directory_path)

Basically an iterative C<mkdir()>, C<mkpath()> works its way down from the
top making directories as needed until an entire path has been created.

=end

sub mkpath ($path) {
    my @path := split('/', $path);
    my $cur  := '';

    for @path -> $dir {
        $cur := fscat([$cur, $dir]);

        unless path_exists($cur) {
            mkdir($cur);
        }
    }
}

=begin

=item $writable := test_dir_writable($directory_path)

Sadly there is no portable, guaranteed way to check if a directory is writable
(with create permission, on platforms that separate it) except to actually try
to create a file within it.  This function does just that, and then unlinks the
file afterwards.

This function should only be considered helpful from a usability sense, allowing
the program to detect a likely failure case early, before wasting the user's
time.  In no circumstance should it be considered a security function; only
checking for errors on every real operation can avoid security holes due to
race conditions between test and action.

=end

sub test_dir_writable($dir) {
    my $test_file := fscat([$dir], 'WrItAbLe.UtL');

    die("Test file '$test_file'\nthat should never exist already does.")
        if path_exists($test_file);

    try(spew, [$test_file, "test_dir_writable() test file.\n"]);

    if path_exists($test_file) {
        unlink($test_file);
        return 1;
    }
    else {
        return 0;
    }
}

=begin

=item $home := user_home_dir()

Determine the user's home directory in the proper platform-dependent manner.

=end

sub user_home_dir() {
    return (%ENV<HOMEDRIVE> // '') ~ %ENV<HOME>;
}

=begin

=back


=head2 Plumage Specific Functions

While the previous functions are likely usable by a great variety of NQP
programs, these functions are likely only directly useful to Plumage-related
programs.

=over 4

=item $replaced := replace_config_strings($original)

Replace all config strings (marked as C<#config_var_name#>) within the
C<$original> string with replacements found in one of the global
configuration hashes. These are searched in the following order:

    %CONF        # Plumage configuration
    %VM<config>  # VM (Parrot) configuration
    %BIN         # Locations of system programs
    %ENV         # Program environment

If no replacement is found in any of the above, an empty string is used
instead.

C<replace_config_strings()> will do a full pass replacing all config strings
within the original, and then loop back to the beginning and try again with
the updated string.  This continues until the string stops changing.  This
allows configuration settings to be defined in terms of other configuration
settings.

B<NOTE> that this function is currently B<NOT> protected from an infinite loop
caused by bad config settings, nor is it protected from nefarious inputs
producing unintended expansions.

=end

sub replace_config_strings ($original) {
    my $new := $original;

    repeat {
        $original := $new;
        $new      := subst($original, rx('\#<ident>\#'), config_value);
    }
    while $new ne $original;

    return $new;
}

sub config_value ($match) {
    my $key    := $match<ident>;
    my $config := %CONF{$key}
               || %VM<config>{$key}
               || %BIN{$key}
               || %ENV{$key}
               || '';

    return $config;
}

=begin

=back

=end
