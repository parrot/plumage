=begin

=head1 NAME

Pluamge::Util - Plumage-specific utility functions

=head1 SYNOPSIS

    # Load this library
    pir::load_bytecode('Plumage/Util.pbc');

    # Plumage-specific
    $replaced := replace_config_strings($original);


=head1 DESCRIPTION

These utility functions are likely only directly useful to Plumage-related
programs, unlike the more general utility functions provided by
F<src/lib/Util.nqp>.

=over 4

=item $replaced := replace_config_strings($original)

Replace all config strings (marked as C<#config_var_name#>) within the
C<$original> string with replacements found in one of the global
configuration hashes. These are searched in the following order:

    %*CONF        # Plumage configuration
    %*VM<config>  # VM (Parrot) configuration
    %*BIN         # Locations of system programs
    %*ENV         # Program environment

If no replacement is found in any of the above, an empty string is used
instead.

C<replace_config_strings()> will do a full pass replacing all config strings
within the original, and then loop back to the beginning and try again with
the updated string.  This continues until the string stops changing.  This
allows configuration settings to be defined in terms of other configuration
settings.

B<NOTE> that this function is currently B<NOT> protected from an infinite loop
caused by bad config settings, nor is it protected from nefarious inputs
producing unintended expansions.

=end

sub replace_config_strings ($original) {
    my $new := $original;

    repeat {
        $original := $new;
        $new      := subst($original, /\#<ident>\#/, config_value);
    }
    while $new ne $original;

    return $new;
}

sub config_value ($match) {
    my $key    := $match<ident>;
    my $config := %*CONF{$key}
               || %*VM<config>{$key}
               || %*BIN{$key}
               || %*ENV{$key}
               || '';

    return $config;
}


=begin

=back

=end
