###
### cap-test.nqp: Test the current capabilities of NQP
###

# TO USE:
#   * Make sure parrot and parrot_config are in your path, then:
#   $ export  NQP_PBC=$(parrot_config libdir)$(parrot_config versiondir)/languages/nqp/nqp.pbc
#   $ parrot $NQP_PBC test.nqp


# First, load the "glue builtins" borrowed from Rakudo.
load_bytecode('Glue.pir');
say("Glue loaded.\n");

# Binding only, no assignment.  Also no interpolation.
our %VM;
our $libdir := get_versioned_libdir();
say('Versioned libdir: ' ~ $libdir);

sub get_versioned_libdir () {
    my $config := %VM<config>;
    my $libdir := $config<libdir>;
    my $verdir := $config<versiondir>;

    return $libdir ~ $verdir;
}

# The NQP parser complains about PIR-created globals
# unless they are (redundantly) declared in NQP.
our $OS;
our $OSVER;
our %ENV;
say('Operating system: ' ~ $OS ~ ' ' ~ $OSVER);
say('%ENV<PATH>:       ' ~ %ENV<PATH>);

# Class declaration is ... suboptimal ... at the moment
my $bar := BarFly.new(:flea('bag'));
say('$bar.foo():       ' ~ $bar.foo());

class BarFly {
    # has $!flea;

    # method new () {...}

    method foo () {
        # say($!flea);
        return "BARFLE";
    }
}

# These work OK, but qx() is insecurely implemented (in Parrot),
# and the error handling is not yet strong.
say("\nLocal directory:");
my $status := run('ls', '-l');

say("\nEnvironment variables:");
my $output := qx('env');
print($output);
