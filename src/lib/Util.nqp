=begin

=head1 NAME

Util.nqp - Utility functions for NQP

=head1 SYNOPSIS

    # Load this library
    pir::load_bytecode('Util.pbc');

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

    # Regular expressions
    @matches := all_matches($regex, $text);
    $edited  := subst($original, $regex, $replacement);

    # I/O
    print('things', ' to ', 'print', ...);
    say(  'things', ' to ', 'say',   ...);
    $contents := slurp($filename);
    spew(  $filename, $contents);
    append($filename, $contents);

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

    # HLL Interop
    $result := eval($source_code, $language);

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
setting in Perl 6, but are not provided with NQP by default.

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


=head2 Regular Expression Functions

These functions add more power to the basic regex matching capability,
including doing global matches and global substitutions.

=over 4

=item @matches := all_matches($regex, $text)

=end

sub all_matches($regex, $text) {
    my @matches;

    my  $match := $text ~~ $regex;
    while $match {
        @matches.push($match);
        $match := $match.CURSOR.parse($text, :rule($regex), :c($match.to));
    }

    return @matches;
}


=begin

=item $edited := subst($original, $regex, $replacement)

Substitute all matches of the C<$regex> in the C<$original> string with the
C<$replacement>, and return the edited string.  The C<$regex> must be a regex
object as returned by C</.../>.

The C<$replacement> may be either a simple string or a sub that will be called
with each match object in turn, and must return the proper replacement string
for that match.

=end

sub subst($original, $regex, $replacement) {
    my @matches := all_matches($regex, $original);
    my $edited  := pir::clone($original);
    my $is_sub  := pir::isa($replacement, 'Sub');
    my $offset  := 0;

    for @matches -> $match {
        my $replace_string := $is_sub ?? $replacement($match) !! $replacement;
	my $replace_len    := pir::length($replace_string);
	my $match_len      := $match.to - $match.from;
	my $real_from      := $match.from + $offset;

	Q:PIR{
             $P0 = find_lex '$edited'
	     $S0 = $P0
	     $P1 = find_lex '$real_from'
	     $I0 = $P1
	     $P2 = find_lex '$match_len'
	     $I1 = $P2
	     $P3 = find_lex '$replace_string'
	     $S1 = $P3
	     substr $S0, $I0, $I1, $S1
	     $P0 = $S0
	};

	$offset := $offset - $match_len + $replace_len;
    }

    return $edited;
}


=begin

=back


=head2 I/O Functions

Basic stdio and file I/O functions.

=over 4

=item print('things', ' to ', 'print', ...)

Print a list of strings to standard output.

=end

sub print (*@strings) {
    for @strings {
        pir::print($_);
    }
}


=begin

=item say('things', ' to ', 'say', ...)

Print a list of strings to standard output, followed by a newline.

=end

sub say (*@strings) {
    print(|@strings, "\n");
}


=begin

=item $contents := slurp($filename)

Read the C<$contents> of a file as a single string.

=end

sub slurp ($filename) {
    my $fh       := pir::open__Pss($filename, 'r');
    my $contents := $fh.readall;
    pir::close($fh);

    return $contents;
}


=begin

=item spew($filename, $contents)

Write the string C<$contents> to a file.

=end

sub spew ($filename, $contents) {
    my $fh := pir::open__Pss($filename, 'w');
    $fh.print($contents);
    pir::close($fh);
}


=begin

=item append($filename, $contents)

Append the string C<$contents> to a file.

=end

sub append ($filename, $contents) {
    my $fh := pir::open__Pss($filename, 'a');
    $fh.print($contents);
    pir::close($fh);
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

    my $sep    := pir::getinterp__P()[6]<slash>;
    my $joined := pir::join($sep, @path_parts);
       $joined := $joined ~ $sep ~ @filename[0] if @filename;

    return $joined;
}


=begin

=item $home := user_home_dir()

Determine the user's home directory in the proper platform-dependent manner.

=end

sub user_home_dir() {
    my %env := pir::root_new__PP(< parrot Env >);
    return (%env<HOMEDRIVE> // '') ~ %env<HOME>;
}


=begin

=item $found := path_exists($path);

Return a true value if the C<$path> exists on the filesystem, or a false
value if not.

=end

sub path_exists ($path) {
    my @stat := pir::root_new__PP(< parrot OS >).stat($path);
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
    my @stat := pir::root_new__PP(< parrot OS >).stat($path);
    return pir::stat__isi($path, 2);   # STAT_ISDIR

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
        pir::root_new__PP(< parrot OS >).rm($test_file);
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
    my $path_sep := pir::sysinfo__si(4) eq 'MSWin32' ?? ';' !! ':';
    my %env      := pir::root_new__PP(< parrot Env >);
    my @paths    := pir::split($path_sep, %env<PATH>);
    my @exts     := pir::split($path_sep, %env<PATHEXT>);

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
            pir::root_new__PP(< parrot OS >).mkdir($cur, 0o777);
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
        return 0;
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

=back


=head2 HLL Interop Functions

These functions allow code in other languages to be evaluated and the
results returned.

=over 4

=item $result := eval($source_code, $language)

Evaluate a string of C<$source_code> in a known Parrot C<$language>,
returning the C<$result> of executing the compiled code.

=end

sub eval ($source_code, $language) {
    $language := pir::downcase($language);

    pir::load_language($language);
    my $compiler := pir::compreg__Ps($language);

    return $compiler.compile($source_code)();
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
unconditionally set well-known contextual variables such as C<$!> and C<%*VM>
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
    # Needed for rest of code to work
    pir::load_bytecode('config.pbc');
    pir::load_bytecode('P6Regex.pbc');

    my $interp  := pir::getinterp__P();
    my @argv    := $interp[2];   # IGLOBALS_ARGV_LIST
    my $config  := $interp[6];   # IGLOBALS_CONFIG_HASH

    # Only fill the config portion of %*VM for now
    my %vm;
    %vm<config> := $config;
    store_dynlex_safely('%*VM', %vm);

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
