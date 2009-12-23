#! parrot-nqp

MAIN();

sub MAIN () {
    # Load testing tools
    pir::load_language('parrot');
    pir::compreg__PS('parrot').import('Test::More');

    # Run all component loading tests
    run_tests();
}

sub run_tests () {
    plan(11);

    test_load_pbcs();
}

sub test_load_pbcs() {
    my @pbcs := <
                  config.pbc
		  dumper.pbc
		  Config/JSON.pbc
		  Getopt/Obj.pbc
		  P6object.pbc
		  P6Regex.pbc
		  src/lib/Util.pbc
		  src/lib/Plumage/Util.pbc
		  src/lib/Plumage/Metadata.pbc
		  src/lib/Plumage/Dependencies.pbc
		  src/lib/Plumage/Project.pbc
		>;

    for @pbcs -> $pbc {
        pir::load_bytecode($pbc);

        ok(1, "success loading '$pbc'");
	CATCH {
	   ok(0, "FAILED TO LOAD '$pbc'");
        }
    }
}
