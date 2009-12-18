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
    @mapped  := map(   &code, @originals);
    @matches := grep(  &code, @all);
    $result  := reduce(&code, @array, $initial?);

    # Containers
    %hash := hash(:key1(value1), :key2(value2), ...);
    %set  := set_from_array(@array);

    # Filesystems and paths
    $path        := fscat(@path_parts [, $filename]);
    $home        := user_home_dir();
    $found       := path_exists($path);
    $is_dir      := is_dir($path);
    $writable    := test_dir_writable($directory_path);
    $binary_path := find_program($program);
    mkpath($directory_path);

    # External programs
    $status_code := run(   $command, $and, $args, ...);
    $success     := do_run($command, $and, $args, ...);
    $output      := qx(    $command, $and, $args, ...);

    # Deep Magic
    store_dynlex_safely($var_name, $value);

    # Global variables
    my $*EXECUTABLE_NAME;
    my $*PROGRAM_NAME;
    my $*OSNAME;
    my $*OSVER;
    my @*ARGS;
    my %*ENV;
    my %*VM;
    my $*OS;

    # Plumage-specific
    $replaced := replace_config_strings($original);


=head1 DESCRIPTION

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

=item $result := reduce(&code, @array, $initial?)

Loop over the C<@array>, applying the binary function C<&code> to the current
C<$result> and next element of the C<@array>, each time saving the return
value of the C<&code> as the new C<$result>.  When all elements of the array
have been processed, the last C<$result> computed is returned.

If an C<$initial> value is supplied, it is used as the starting value for
C<$result> when iterating over the C<@array>.  This automatically works with
any length C<@array>, even an empty one.

Without an C<$initial> value, C<reduce()> applies the C<&code> to the first two
elements in the C<@array> to determine the inital C<$result> (and skips these
first two elements when looping).  If the C<@array> has only one element, it
is returned directly as the final C<$result>.  If the C<@array> is empty, the
C<$result> is an undefined value.

=end

sub reduce (&code, @array, *@initial) {
    my    $init_elems := pir::elements(@initial);
    if    $init_elems >  1 {
        pir::die('Only one initial value allowed in reduce()');
    }
    elsif $init_elems == 1 {
        return _reduce(&code, @array, @initial[0]);
    }
    else {
        my    $array_elems := pir::elements(@array);
        if    $array_elems == 0 {
            return my $undef;
        }
        elsif $array_elems == 1 {
            return @array[0];
        }
        else {
            my $initial := &code(@array[0], @array[1]);
            my $iter    := pir::iter__PP(@array);

            pir::shift($iter);
            pir::shift($iter);

            return _reduce(&code, $iter, $initial);
        }
    }
}

sub _reduce(&code, $iter, $initial) {
    my $result := $initial;

    for $iter {
        $result := &code($result, $_);
    }

    return $result;
}


=begin

=head2 Container Coercions

These functions create a container of a desired type from one or more
containers of another type.  While some of these would not exist in the Perl 6
setting, they are still generally useful for NQP programs because NQP syntax is
considerably more wordy than Perl 6.  DRY thus applies.

=over 4

=item %hash := hash(:key1(value1), :key2(value2), ...)

Coerce a list of pairs into a hash.

=end

sub hash (*%h) { return %h }


=begin

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


=head2 Filesystem and Path Functions

These functions provide convenient ways to interact with the file system,
user PATH, and similar operating system constructs.

=over 4

=item $path := fscat(@path_parts [, $filename])

Join C<@path_parts> and C<$filename> strings together with the appropriate
OS separator.  If no C<$filename> is supplied, C<fscat()> will I<not> add a
trailing slash (though slashes inside the C<@path_parts> will not be removed,
so don't do that).

=end

sub fscat(@path_parts, *@filename) {
    pir::die('Only one filename allowed in fscat()')
        if @filename > 1;

    my $sep    := $*VM<config><slash>;
    my $joined := pir::join($sep, @path_parts);
       $joined := $joined ~ $sep ~ @filename[0] if @filename;

    return $joined;
}


=begin

=item $home := user_home_dir()

Determine the user's home directory in the proper platform-dependent manner.

=end

sub user_home_dir() {
    return (%*ENV<HOMEDRIVE> // '') ~ %*ENV<HOME>;
}


=begin

=item $found := path_exists($path);

Return a true value if the C<$path> exists on the filesystem, or a false
value if not.

=end

sub path_exists ($path) {
    my @stat := $*OS.stat($path);
    return 1;

    CATCH {
        return 0;
    }
}


=begin

=item $is_dir := is_dir($path);

Return a true value if the C<$path> exists on the filesystem and is a
directory, or a false value if not.

=end

sub is_dir($path) {
    my @stat := $*OS.stat($path);
    return pir::stat($path, 2);   # STAT_ISDIR

    CATCH {
        return 0;
    }
}


=begin

=item $writable := test_dir_writable($directory_path)

Sadly there is no portable, guaranteed way to check if a directory is writable
(with create permission, on platforms that separate it) except to actually try
to create a file within it.  This function does just that, and then removes the
test file afterwards.

This function should only be considered helpful from a usability sense, allowing
the program to detect a likely failure case early, before wasting the user's
time.  In no circumstance should it be considered a security function; only
checking for errors on every real operation can avoid security holes due to
race conditions between test and action.

=end

sub test_dir_writable($dir) {
    my $test_file := fscat([$dir], 'WrItAbLe.UtL');

    pir::die("Test file '$test_file'\nthat should never exist already does.")
        if path_exists($test_file);

    try {
       spew($test_file, "test_dir_writable() test file.\n");
    };

    if path_exists($test_file) {
        $*OS.rm($test_file);
        return 1;
    }
    else {
        return 0;
    }
}


=begin

=item $binary_path := find_program($program)

Search C<%*ENVE<lt>PATHE<gt>> to find the full path for a given C<$program>.  If
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
    my $path_sep := $*OSNAME eq 'MSWin32' ?? ';' !! ':';
    my @paths    := pir::split($path_sep, %*ENV<PATH>);
    my @exts     := pir::split($path_sep, %*ENV<PATHEXT>);

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
    my @path := pir::split('/', $path);
    my $cur  := @path.shift;

    for @path -> $dir {
        $cur := fscat([$cur, $dir]);

        unless path_exists($cur) {
            $*OS.mkdir($cur, 0o777);
        }
    }
}


=begin

=back


=head2 Program Spawning Functions

These functions provide several variations on the "spawn a child program
and wait for the results" theme.

=over 4

=item $status_code := run($command, $and, $args, ...)

Spawn the command with the given arguments as a new process; returns
the status code of the spawned process, which is equal the the result
of the waitpid system call, right bitshifted by 8.  Throws an exception
if the process could not be spawned at all.

=end

sub run (*@command_and_args) {
    return pir::shr(pir::spawnw__iP(@command_and_args), 8);
}


=begin

=item $success := do_run($command, $and, $args, ...)

Print out the command and arguments, then spawn the command with the given
arguments as a new process; return 1 if the process exited successfully, or
0 if not.  Unlike C<run()> and C<qx()>, will I<not> throw an exception if
the process cannot be spawned.  Since this is a convenience function, it will
instead return 0 on spawn failure, just as if the child process had spawned
successfully but itself exited with failure.

=end

sub do_run (*@command_and_args) {
    say(pir::join(' ', @command_and_args));

    return pir::spawnw__iP(@command_and_args) ?? 0 !! 1;

    CATCH {
        return -1;
    }
}


=begin

=item $output := qx($command, $and, $args, ...)

Spawn the command with the given arguments as a read only pipe;
return the output of the command as a single string.  Throws an
exception if the pipe cannot be opened.  Sets the caller's C<$!>
to the exit value of the child process.

B<WARNING>: Parrot currently implements the pipe open B<INSECURELY>!

=end

sub qx (*@command_and_args) {
    my $cmd  := pir::join(' ', @command_and_args);
    my $pipe := pir::open__Pss($cmd, 'rp');
    pir::die("Unable to execute '$cmd'") unless $pipe;

    $pipe.encoding('utf8');
    my $output := $pipe.readall;
    $pipe.close;

    store_dynlex_safely('$!', $pipe.exit_status);

    return $output;
}


=begin

=head2 Deep Magic

These functions reach into the guts of NQP, PIR, or Parrot and shuffle them.
Use with care.

=over 4

=item store_dynlex_safely($var_name, $value)

Set a dynamic lexical ("contextual") variable named C<$var_name> to C<$value>
if such a variable has been declared in some calling scope, or do nothing if
the variable has not been declared.  This allows library code to
unconditionally set well-known contextual variables such as C<$!> and C<$*VM>
without worrying about an exception being thrown because the calling code
doesn't care about the value of that contextual and thus has not declared it.

=end

sub store_dynlex_safely($var_name, $value) {
    pir::store_dynamic_lex__vsP($var_name, $value)
        unless pir::isnull(pir::find_dynamic_lex($var_name));
}


=begin

=back


=head2 Global Variables

Standard variables available in Perl 6, variously known as "core globals",
"setting contextuals", and "predefined dynamic lexicals".

=over 4

=item $*EXECUTABLE_NAME

Full path of interpreter executable

=item $*PROGRAM_NAME

Name of running program (argv[0] in C)

=item $*OSNAME

Operating system generic name

=item $*OSVER

Operating system version

=item @*ARGS

Program's command line arguments (including options, which are NOT parsed)

=item %*ENV

Process-wide environment variables

=item %*VM

Parrot configuration (in the %*VM<config> subhash)

=item $*OS

Parrot operating system control object

=back

=end

INIT {
    pir::load_bytecode('config.pbc');

    my $interp  := pir::getinterp__P();
    my @argv    := $interp[2];   # IGLOBALS_ARGV_LIST
    my $config  := $interp[6];   # IGLOBALS_CONFIG_HASH

    # Only fill the config portion of %*VM for now
    my %VM;
    %VM<config> := $config;
    store_dynlex_safely('%*VM', %VM);

    # Handle argv properly even for -e one-liners
    @argv.unshift('<anonymous>')   unless @argv;
    store_dynlex_safely('$*PROGRAM_NAME', @argv.shift);
    store_dynlex_safely('@*ARGS',         @argv);

    # INTERPINFO_EXECUTABLE_FULLNAME
    store_dynlex_safely('$*EXECUTABLE_NAME', pir::interpinfo__si(19));

    # SYSINFO_PARROT_OS / SYSINFO_PARROT_VERSION
    store_dynlex_safely('$*OSNAME', pir::sysinfo__si(4));
    store_dynlex_safely('%*OSVER',  pir::sysinfo__si(5));

    # Magic objects
    store_dynlex_safely('%*ENV', pir::root_new__PP(< parrot Env >));
    store_dynlex_safely('$*OS',  pir::root_new__PP(< parrot OS  >));
}


=begin

=head2 Plumage Specific Functions

While the previous functions are likely usable by a great variety of NQP
programs, these functions are likely only directly useful to Plumage-related
programs.

=over 4

=item $replaced := replace_config_strings($original)

Replace all config strings (marked as C<#config_var_name#>) within the
C<$original> string with replacements found in one of the global
configuration hashes. These are searched in the following order:

    %*CONF        # Plumage configuration
    %*VM<config>  # VM (Parrot) configuration
    %*BIN         # Locations of system programs
    %*ENV         # Program environment

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
    my $config := %*CONF{$key}
               || %*VM<config>{$key}
               || %*BIN{$key}
               || %*ENV{$key}
               || '';

    return $config;
}


=begin

=back

=end
