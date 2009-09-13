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


=back

=head1 Global Variables

=over 4

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
