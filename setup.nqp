#!/usr/bin/env parrot-nqp

sub MAIN() {
    # Load distutils library
    pir::load_bytecode('distutils.pbc');

    # ALL DISTUTILS CONFIGURATION IN THIS HASH
    my %config := hash(
        # General
        setup            => 'setup.nqp',
        name             => 'Plumage',
        abstract         => 'Parrot Plumage is the Parrot module ecosystem',
        authority        => 'http://gitorious.org/~japhb',
        copyright_holder => 'Geoffrey Broadwell',
        description      => 'Parrot Plumage is the Parrot module ecosystem.  It includes tools to search metadata, handle dependencies, install modules, and so forth.',
        keywords         => < parrot package deployment module ecosystem >,
        license_type     => 'Artistic License 2.0',
        license_uri      => 'http://www.perlfoundation.org/artistic_license_2_0',
        checkout_uri     => 'git://gitorious.org/parrot-plumage/parrot-plumage.git',
        browser_uri      => 'http://gitorious.org/parrot-plumage/parrot-plumage',
        project_uri      => 'http://gitorious.org/parrot-plumage/parrot-plumage',

        # Build
	# XXX: Doesn't actually work; need distutils to make any
        #      missing directories before performing compiles
        pir_nqprx        => unflatten(
            'build/Plumage/Dependencies.pir', 'src/lib/Plumage/Dependencies.nqp',
            'build/Plumage/Metadata.pir'    , 'src/lib/Plumage/Metadata.nqp',
            'build/Plumage/Project.pir'     , 'src/lib/Plumage/Project.nqp',
            'build/Plumage/Util.pir'        , 'src/lib/Plumage/Util.nqp',
            'build/plumage.pir'             , 'src/plumage.nqp',
        ),
        pbc_pir          => unflatten(
            'build/Plumage/Dependencies.pbc', 'build/Plumage/Dependencies.pir',
            'build/Plumage/Metadata.pbc'    , 'build/Plumage/Metadata.pir',
            'build/Plumage/Project.pbc'     , 'build/Plumage/Project.pir',
            'build/Plumage/Util.pbc'        , 'build/Plumage/Util.pir',
            'build/Util.pbc'                , 'build/Util.pir',
            'build/plumage.pbc'             , 'build/plumage.pir',
        ),
        exe_pbc          => unflatten(
            'build/plumage'                 , 'build/plumage.pbc',
        ),

        # Test
        prove_exec       => get_nqp(),

        # Install
        # XXX: Doesn't actually work; need distutils to strip
        #      the build/ prefix from paths during install
        inst_bin         => 'plumage',
        inst_lib         => <
                              Plumage/Dependencies.pbc
                              Plumage/Metadata.pbc
                              Plumage/Project.pbc
                              Plumage/Util.pbc
                              Util.pbc
                            >,

        # Dist
        doc_files        => < CREDITS README TASKS TODO >,
    );


    # Boilerplate; should not need to be changed
    my @*ARGS := pir::getinterp__P()[2];
       @*ARGS.shift;

    setup(@*ARGS, %config);
}

# Work around minor nqp-rx limitations
sub hash     (*%h ) { %h }
sub unflatten(*@kv) { my %h; for @kv -> $k, $v { %h{$k} := $v }; %h }

# Start it up!
MAIN();


# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
