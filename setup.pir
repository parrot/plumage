#!/usr/bin/env parrot
# Copyright (C) 2011, Parrot Foundation.

=head1 NAME

setup.pir - Python distutils style

=head1 DESCRIPTION

No Configure step, no Makefile generated.

=head1 USAGE

    $ parrot setup.pir build
    $ parrot setup.pir test
    $ sudo parrot setup.pir install

=cut

.sub 'main' :main
    .param pmc args
    $S0 = shift args
    load_bytecode 'distutils.pbc'
    .local pmc config
    config = get_config()

    .const 'Sub' selfinstall       = 'selfinstall'
    .const 'Sub' install_manpage   = 'install_manpage'
    .const 'Sub' uninstall_manpage = 'uninstall_manpage'

    register_step('selfinstall',     selfinstall)
    register_step_after('install',   install_manpage)
    register_step_after('uninstall', uninstall_manpage)

    $P0 = new 'Hash'
    $P0['name']                 = 'Plumage'
    $P0['abstract']             = 'Parrot Plumage is the Parrot module ecosystem'
    $P0['authority']            = 'http://github.com/parrot'
    $P0['description']          = 'Parrot Plumage is the Parrot module ecosystem.  It includes tools to search metadata, handle dependencies, install modules, and so forth.'
    $P1 = split ',', 'parrot package deployment module ecosystem'
    $P0['keywords']             = $P1
    $P0['license_type']         = 'Artistic License 2.0'
    $P0['license_uri']          = 'http://www.perlfoundation.org/artistic_license_2_0'
    $P0['copyright_holder']     = 'Parrot Foundation'
    $P0['checkout_uri']         =  'git://github.com/parrot/plumage.git'
    $P0['browser_uri']          = 'http://github.com/parrot/plumage'
    $P0['project_uri']          = 'https://trac.parrot.org/parrot/wiki/ModuleEcosystem'

    # build
    $P2 = new 'Hash'
    $P2['src/lib/Plumage/Dependencies.pir']     = 'src/lib/Plumage/Dependencies.nqp'
    $P2['src/lib/Plumage/Metadata.pir']         = 'src/lib/Plumage/Metadata.nqp'
    $P2['src/lib/Plumage/Project.pir']          = 'src/lib/Plumage/Project.nqp'
    $P2['src/lib/Plumage/Util.pir']             = 'src/lib/Plumage/Util.nqp'
    $P2['src/lib/Plumage/NQPUtil.pir']          = 'src/lib/Plumage/NQPUtil.nqp'
    $P2['src/plumage.pir']                      = 'src/plumage.nqp'
    $P0['pir_nqp'] = $P2

    $P3 = new 'Hash'
    $P3['Plumage/Dependencies.pbc']     = 'src/lib/Plumage/Dependencies.pir'
    $P3['Plumage/Metadata.pbc']         = 'src/lib/Plumage/Metadata.pir'
    $P3['Plumage/Project.pbc']          = 'src/lib/Plumage/Project.pir'
    $P3['Plumage/Util.pbc']             = 'src/lib/Plumage/Util.pir'
    $P3['Plumage/NQPUtil.pbc']          = 'src/lib/Plumage/NQPUtil.pir'
    $P3['plumage.pbc']                  = 'src/plumage.pir'
    $P0['pbc_pir'] = $P3

    $P4 = new 'Hash'
    $P4['plumage'] = 'plumage.pbc'
    $P0['installable_pbc'] = $P4

    # test
    $S0 = get_nqp_rx()
    $P0['prove_exec'] = $S0

    # smoke
    $P0['prove_archive'] = 'test_plumage.tar.gz'
    $P0['smolder_url'] = 'http://smolder.parrot.org/app/projects/process_add_report/3'
#    $P0['smolder_comments'] = 'plumage'
    $S0 = get_tags(config)
    $P0['smolder_tags'] = $S0

    # install
    $P5 = split "\n", <<'LIBS'
Plumage/Dependencies.pbc
Plumage/Metadata.pbc
Plumage/Project.pbc
Plumage/Util.pbc
Plumage/NQPUtil.pbc
LIBS
    $S0 = pop $P5
    $P0['inst_lib'] = $P5
    $P6 = glob('plumage/metadata/*.json')
    $P0['inst_data'] = $P6

    # dist
    $P7 = glob('CREDITS README TASKS TODO docs/*/*.pod')
    $P0['doc_files'] = $P7

    .tailcall setup(args :flat, $P0 :flat :named)
.end

.sub 'selfinstall' :anon
    .param pmc kv :slurpy :named
    system('parrot plumage.pbc install plumage', 1 :named('verbose'))
.end

.sub 'install_manpage' :anon
    .param pmc kv :slurpy :named

    .include 'iglobals.pasm'

    $P0 = getinterp
    $P1 = $P0[.IGLOBALS_CONFIG_HASH]

    # Do nothing on MSWin32 platforms
    $S0 = $P1['osname']
    if $S0 == 'MSWin32' goto L1

    .local string man, man_path, man_base
    man      = 'docs/man/plumage.1.gz'
    man_base = basename(man)
    man_path = '/usr/share/man/man1/' . man_base

    cp(man, man_path, 1 :named('verbose'))
  L1:
.end

.sub 'uninstall_manpage' :anon
    .param pmc kv :slurpy :named

    .local string man
    man = '/usr/share/man/man1/plumage.1.gz'

    # Do nothing if manpage doesn't exist
    $I0 = file_exists(man)
    unless $I0 goto L1

    unlink(man, 1 :named('verbose'))
  L1:
.end

.sub 'get_tags'
    .param pmc config
    .local string tags
    tags = config['osname']
    tags .= ", "
    $S0 = config['archname']
    tags .= $S0
    .return (tags)
.end


# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:
