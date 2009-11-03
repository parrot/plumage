###
### cap-test.nqp: Test the current capabilities of NQP
###

# TO USE:
#   $ parrot_nqp cap-test.nqp


# First, load the "glue builtins" borrowed from Rakudo.
pir::load_bytecode('src/lib/Glue.pir');
say("Glue loaded.\n");

# Inline PIR
print("Inline PIR says:  ");
test_inline_pir('Plumage');

sub test_inline_pir ($name) {
    my $string := Q:PIR{
        $S0  = 'Hello, '
        $P0  = find_lex '$name'
	$S1  = $P0
	$S0 .= $S1
	$S0 .= '!'
	%r   = box $S0
    };

    say($string);
}

# Binding only, no assignment.  Also no interpolation.
our %VM;
our $libdir := get_versioned_libdir();
say("\nVersioned libdir: " ~ $libdir);

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

# Test that %ENV is writable
say("\nSetting environment variables:");
say('%ENV<PATH> before: ' ~ %ENV<PATH>);
say('echo $PATH before: ' ~ qx('echo $PATH'));

# XXXX: Need system-dependent path separator
%ENV<PATH> := '/foo/bar:' ~ %ENV<PATH>;

say('%ENV<PATH> after:  ' ~ %ENV<PATH>);
say('echo $PATH after:  ' ~ qx('echo $PATH'));

# Load JSON
say("\nLoad JSON:");
my $json := eval('{"a":[null,false,true,3.5,"Hello from JSON"]}', 'data_json');
say($json<a>[4]);
