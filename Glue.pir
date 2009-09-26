=head1 NAME

Glue.pir - Rakudo "glue" builtins (functions/globals) converted for NQP

=cut

.namespace []

.include 'interpinfo.pasm'
.include 'sysinfo.pasm'
.include 'iglobals.pasm'


=head1 Functions

=over 4

=item $status_code := run($command, $and, $args, ...)

Spawns the command with the given arguments as a new process; returns
the spawn status code when the process exits.

=cut

.sub 'run'
    .param pmc command_and_args :slurpy
    .local int status

    status = spawnw command_and_args

    .return (status)
.end


=item $output := qx($command, $and, $args, ...)

Spawns the command with the given arguments as a read only pipe;
returns the output of the command as a single string.

B<WARNING>: Parrot currently implements this B<INSECURELY>!

=cut

.sub 'qx'
    .param pmc command_and_args :slurpy

    .local string cmd
    cmd = join ' ', command_and_args

    .local pmc pipe
    pipe = open cmd, 'rp'
    unless pipe goto pipe_open_error

    .local pmc output
    pipe.'encoding'('utf8')
    output = pipe.'readall'()
    pipe.'close'()
    .return (output)

  pipe_open_error:
    $S0  = 'Unable to execute "'
    $S0 .= cmd
    $S0 .= '"'
    die $S0
.end


=item $contents := slurp($filename)

Reads the C<$contents> of a file as a single string.

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

Writes the string C<$contents> to a file.

=cut

.sub 'spew'
    .param string filename
    .param string contents

    $P0 = open filename, 'w'
    $P0.'print'(contents)
    close $P0
.end


=item $edited := subst($original, $regex, $replacement)

Substitute all matches of the C<$regex> in the C<$original> string with the
C<$replacement>, and return the edited string.  The C<$regex> must be a simple
string to be compiled using the C<PGE::Perl6Regex> language.

The C<$replacement> may be either a simple string or a sub that will be called
with each match object in turn, and must return the proper replacement string
for that match.

=cut

.sub 'subst'
    .param string original
    .param string regex
    .param pmc    replacement

    # Compile the string regex into a regex object
    .local pmc p6regex, matcher
    p6regex = compreg 'PGE::Perl6Regex'
    matcher = p6regex(regex)

    # Find all matches in the original string
    .local pmc matches, match
    matches = root_new ['parrot';'ResizablePMCArray']
    match   = matcher(original)
    unless match goto done_matching

  match_loop:
    push matches, match

    $I0 = match.'to'()
    match = matcher(match, 'continue' => $I0)

    unless match goto done_matching
    goto match_loop
  done_matching:

    # Do the substitutions on a clone of the original string
    .local string edited
    edited = clone original

    # Now replace all the matched substrings
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
    $I0 = match.'from'()
    $I1 = match.'to'()
    $I2 = $I1 - $I0
    $I0 += offset
    substr edited, $I0, $I2, replace_string
    $I3 = length replace_string
    $I3 -= $I2
    offset += $I3
    goto replace_loop
  done_replacing:

    .return(edited)
.end

=item  chdir($path)  

Changes the current working directory to the one specified by C<path>.

=cut

.sub 'chdir'
    .param string path
    .local pmc os
    os = root_new [ 'parrot' ; 'OS' ]
    os.'chdir'(path)
.end

=item $path := cwd()

Returns the current working directory.

=cut

.sub 'cwd'  
    .local pmc os
    os = root_new [ 'parrot' ; 'OS' ]

    .local string path
    path = os.'cwd'()
    .return(path)
.end

=item mkdir($path, $mode)

Creates a directory specified by C<path> with mode C<mode>.

=cut

.sub 'mkdir'
    .param string path
    .param int mode

    .local pmc os
    os = root_new [ 'parrot' ; 'OS' ]
    os.'mkdir'(path, mode)
.end

=item stat($path)

Returns a 13-item list of information about the given path, as in Perl.

=cut

.sub 'stat'
    .param string path

    .local pmc os, retval
    os = root_new [ 'parrot' ; 'OS' ]
    retval = os.'stat'(path)
    .return (retval)
.end

=item fscat(@pathparts[, $filename)

Join strings together with the appropriate OS separator.

=cut

.sub 'fscat'
    .param pmc parts
    .param string filename :optional
    .param int has_filename :opt_flag

    .local string retval
    .local string sep
    sep = '/' # afaik, this works on linux and windows... should maybe be fixed

    retval = join sep, parts
    unless has_filename == 1 goto no_filename
    concat retval, sep
    concat retval, filename
  no_filename:
    .return (retval)
.end

=item join($delim, @strings)

Join strings together with the specified delimiter.

=cut

.sub 'join'
    .param string delim
    .param pmc parts

    .local string retval
    retval = join delim, parts
    .return (retval)
.end

=item split($delim, $string)

Split $string with the specified delimiter.

=cut

.sub 'split'
    .param string delim
    .param string text

    .local pmc retval
    retval = split delim, text
    .return (retval)
.end

=back


=head1 Global Variables

=over 4

=item $PROGRAM_NAME

Name of running program (argv[0] in C)

=item @ARGS

Program's command line arguments (including options, which are NOT parsed)

=item %VM

Parrot configuration

=item %ENV

Process-wide environment variables

=item $OS

Operating system generic name

=item $OSVER

Operating system version

=back

=cut

.sub 'onload' :anon :load :init
    load_bytecode 'config.pbc'
    $P0 = getinterp
    $P1 = $P0[.IGLOBALS_CONFIG_HASH]
    $P2 = new ['Hash']
    $P2['config'] = $P1
    set_hll_global '%VM', $P2

    $P1 = $P0[.IGLOBALS_ARGV_LIST]
    if $P1 goto have_args
    unshift $P1, '<anonymous>'
  have_args:
    $S0 = shift $P1
    $P2 = box $S0
    set_hll_global '$PROGRAM_NAME', $P2
    set_hll_global '@ARGS', $P1

    $P0 = root_new ['parrot';'Env']
    set_hll_global '%ENV', $P0

    $S0 = sysinfo .SYSINFO_PARROT_OS
    $P0 = box $S0
    set_hll_global '$OS', $P0

    $S0 = sysinfo .SYSINFO_PARROT_OS_VERSION
    $P0 = box $S0
    set_hll_global '$OSVER', $P0
.end


# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:
