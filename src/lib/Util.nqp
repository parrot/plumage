# NQP bug XXXX: Fakecutables broken because 'nqp' language is not loaded.
Q:PIR{
    $P0 = get_hll_global 'say'
  unless null $P0 goto got_nqp
    load_language 'nqp'
  got_nqp:
};

# NQP bug XXXX: Must redeclare PIR globals because the NQP parser can't
#               know about variables created at load_bytecode time.
our $PROGRAM_NAME;
our @ARGS;
our %ENV;
our %VM;
our %BIN;
our %CONF;
our $OS;

sub find_program ($binary) {
    my $path_sep := $OS eq 'MSWin32' ?? ';' !! ':';
    my @paths    := split($path_sep, %ENV<PATH>);

    for @paths {
        my $path := fscat(as_array($_), $binary ~ %VM<exe>);
        if path_exists($path) {
            return $path;
        }
    }

    return '';
}

sub map (&code, @originals) {
    my @mapped;

    for @originals {
        @mapped.push(&code($_));
    }

    return @mapped;
}

sub replace_config_strings ($original) {
    my $new := $original;

    repeat {
        $original := $new;
        $new      := subst($original, rx('\#<ident>\#'), config_value);
    }
    while $new ne $original;

    return $new;
}

sub config_value ($match) {
    my $key    := $match<ident>;
    my $config := %CONF{$key}
               || %VM<config>{$key}
               || %BIN{$key}
               || %ENV{$key}
               || '';

    return $config;
}

sub mkpath ($path) {
    my @path := split('/', $path);
    my $cur  := '';

    for @path {
        $cur := fscat(as_array($cur, $_));

        unless path_exists($cur) {
            mkdir($cur);
        }
    }
}
