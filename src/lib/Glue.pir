
=head1 NAME

Glue.pir - Rakudo "glue" builtins (functions/globals) converted for NQP

=head1 SYNOPSIS

    # Load this library
    pir::load_bytecode('src/lib/Glue.pbc');

    # Other languages
    $result := eval($source_code, $language);

    # I/O
    print('things', ' to ', 'print', ...);
    say(  'things', ' to ', 'say',   ...);
    $contents := slurp($filename);
    spew(  $filename, $contents);
    append($filename, $contents);

    # Regular expressions
    $regex_object := rx($regex_source);
    @matches := all_matches($regex, $text);
    $edited := subst($original, $regex, $replacement);

    # Filesystems and paths
    mkdir($path [, $mode]);
    @info   := stat($path);
    $found  := path_exists($path);
    $is_dir := is_dir($path);
    @names  := readdir($directory);
    $path   := fscat(@path_parts [, $filename]);

=cut

.namespace []

.include 'interpinfo.pasm'
.include 'sysinfo.pasm'
.include 'iglobals.pasm'
.include 'stat.pasm'


=head1 DESCRIPTION

=head2 Functions

=over 4

=item $result := eval($source_code, $language)

Evaluate a string of C<$source_code> in a known Parrot C<$language>,
returning the C<$result> of executing the compiled code.

=cut

.sub 'eval'
    .param string source_code
    .param string language

    .local pmc compiler
    language = downcase language
    load_language language
    compiler = compreg language

    .local pmc compiled
    compiled = compiler.'compile'(source_code)
    $P0      = compiled()

    .return ($P0)
.end


=item print('things', ' to ', 'print', ...)

Print a list of strings to standard output.

=cut

.sub 'print'
    .param pmc strings :slurpy

    .local pmc it
    it = iter strings
  print_loop:
    unless it goto print_end
    $P0 = shift it
    print $P0
    goto print_loop
  print_end:
.end


=item say('things', ' to ', 'say', ...)

Print a list of strings to standard output, followed by a newline.

=cut

.sub 'say'
    .param pmc strings :slurpy

    .tailcall 'print'(strings :flat, "\n")
.end


=item $contents := slurp($filename)

Read the C<$contents> of a file as a single string.

=cut

.sub 'slurp'
    .param string filename
    .local string contents

    $P0 = open filename, 'r'
    contents = $P0.'readall'()
    close $P0
    .return(contents)
.end


=item spew($filename, $contents)

Write the string C<$contents> to a file.

=cut

.sub 'spew'
    .param string filename
    .param string contents

    $P0 = open filename, 'w'
    $P0.'print'(contents)
    close $P0
.end


=item append($filename, $contents)

Append the string C<$contents> to a file.

=cut

.sub 'append'
    .param string filename
    .param string contents

    $P0 = open filename, 'a'
    $P0.'print'(contents)
    close $P0
.end


=item $regex_object := rx($regex_source)

Compile C<$regex_source> (a string representing the source code form of a
Perl 6 Regex) into a C<$regex_object>, suitable for using in C<match()> and
C<subst()>.

=cut

.sub 'rx'
    .param string source

    .local pmc p6regex, object
    p6regex = compreg 'PGE::Perl6Regex'
    object  = p6regex(source)

    .return(object)
.end


=item @matches := all_matches($regex, $text)

Find all matches (C<:g> style, not C<:exhaustive>) for C<$regex> in the
C<$text>.  The C<$regex> must be a regex object returned by C<rx()>.

=cut

.sub 'all_matches'
    .param pmc    regex
    .param string text

    # Find all matches in the original string
    .local pmc matches, match
    matches = root_new ['parrot';'ResizablePMCArray']
    match   = regex(text)
    unless match goto done_matching

  match_loop:
    push matches, match

    $I0   = match.'to'()
    match = regex(match, 'continue' => $I0)

    unless match goto done_matching
    goto match_loop
  done_matching:

    .return(matches)
.end


=item $edited := subst($original, $regex, $replacement)

Substitute all matches of the C<$regex> in the C<$original> string with the
C<$replacement>, and return the edited string.  The C<$regex> must be a regex
object returned by the C<rx()> function.

The C<$replacement> may be either a simple string or a sub that will be called
with each match object in turn, and must return the proper replacement string
for that match.

=cut

.sub 'subst'
    .param string original
    .param pmc    regex
    .param pmc    replacement

    # Find all matches in the original string
    .local pmc matches
    matches = all_matches(regex, original)

    # Do the substitutions on a clone of the original string
    .local string edited
    edited = clone original

    # Now replace all the matched substrings
    .local pmc match
    .local int offset
    offset = 0
  replace_loop:
    unless matches goto done_replacing
    match = shift matches

    # Handle either string or sub replacement
    .local string replace_string
    $I0 = isa replacement, 'Sub'
    if $I0 goto call_replacement_sub
    replace_string = replacement
    goto have_replace_string
  call_replacement_sub:
    replace_string = replacement(match)
  have_replace_string:

    # Perform the replacement
    $I0  = match.'from'()
    $I1  = match.'to'()
    $I2  = $I1 - $I0
    $I0 += offset
    substr edited, $I0, $I2, replace_string
    $I3  = length replace_string
    $I3 -= $I2
    offset += $I3
    goto replace_loop
  done_replacing:

    .return(edited)
.end


=item mkdir($path [, $mode])

Create a directory specified by C<$path> with mode C<$mode>.  C<$mode> is
optional and defaults to octal C<777> (full permissions) if absent.  C<$mode>
is modified by the user's current C<umask> as usual.

=cut

.sub 'mkdir'
    .param string path
    .param int    mode     :optional
    .param int    has_mode :opt_flag

    if has_mode goto have_mode
    mode = 0o777
  have_mode:

    .local pmc os
    os = root_new [ 'parrot' ; 'OS' ]
    os.'mkdir'(path, mode)
.end


=item @info := stat($path)

Returns a 13-item list of information about the given C<$path>, as in Perl 5.
(See C<perldoc -f stat> for more details.)

=cut

.sub 'stat'
    .param string path

    .local pmc os, stat_list
    os = root_new [ 'parrot' ; 'OS' ]
    stat_list = os.'stat'(path)

    .return (stat_list)
.end


=item $found := path_exists($path);

Return a true value if the C<$path> exists on the filesystem, or a false
value if not.

=cut

.sub 'path_exists'
    .param string path

    push_eh stat_failed
    .local pmc stat_list
    stat_list = 'stat'(path)
    pop_eh
    .return (1)

  stat_failed:
    pop_eh
    .return (0)
.end


=item $is_dir := is_dir($path);

Return a true value if the C<$path> exists on the filesystem and is a
directory, or a false value if not.

=cut

.sub 'is_dir'
    .param string path

    push_eh stat_failed
    .local pmc stat_list
    stat_list = 'stat'(path)
    pop_eh

    .local int is_dir
    is_dir = stat path, .STAT_ISDIR
    .return (is_dir)

  stat_failed:
    pop_eh
    .return (0)
.end


=item @names := readdir($directory)

List the names of all entries in the C<$directory>.

=cut

.sub 'readdir'
    .param string dir

    .local pmc os, names
    os = root_new [ 'parrot' ; 'OS' ]
    names = os.'readdir'(dir)

    .return (names)
.end


=item $path := fscat(@path_parts [, $filename])

Join C<@path_parts> and C<$filename> strings together with the appropriate
OS separator.  If no C<$filename> is supplied, C<fscat()> will I<not> add a
trailing slash (though slashes inside the C<@path_parts> will not be removed,
so don't do that).

=cut

.sub 'fscat'
    .param pmc    parts
    .param string filename     :optional
    .param int    has_filename :opt_flag

    .local string sep
    $P0 = getinterp
    $P1 = $P0[.IGLOBALS_CONFIG_HASH]
    sep = $P1['slash']

    .local string joined
    joined = join sep, parts

    unless has_filename goto no_filename
    joined .= sep
    joined .= filename
  no_filename:

    .return (joined)
.end


=back

=cut


# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:
