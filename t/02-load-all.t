#!/usr/bin/env parrot-nqp

MAIN();

sub MAIN() {
    # Load testing tools
    pir::load_language('parrot');
    pir::compreg__PS('parrot').import('Test::More');

    # Run all component loading tests
    run_tests();
}

sub run_tests() {
    plan(13);

    test_load_pbcs();
}

sub test_load_pbcs() {
    my @pbcs := <config.pbc
                 dumper.pbc
                 Config/JSON.pbc
                 Getopt/Obj.pbc
                 P6object.pbc
                 P6Regex.pbc
                 Plumage/NQPUtil.pbc
                 Plumage/Util.pbc
                 Plumage/Metadata.pbc
                 Plumage/Dependencies.pbc
                 Plumage/Project.pbc
                 Plumage/Interactive.pbc
                 Plumage/Command.pbc>;

    for @pbcs -> $pbc {
        pir::load_bytecode($pbc);

        ok(1, "success loading '$pbc'");

        CATCH {
            ok(0, "FAILED TO LOAD '$pbc'");
        }
    }
}

# vim: ft=perl6
