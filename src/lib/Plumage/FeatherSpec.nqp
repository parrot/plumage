# Copyright (C) 2011, Parrot Foundation.

=begin pod

=head1 NAME

Plumage::FeatherSpec - represents a featherspec file

=head1 DESCRIPTION

The C<Plumage::FeatherSpec> class is an abstract representation of a
featherspec file.

=head2 Public Attributes

=item C<$!error>

In the event of an error, holds a string describing what went wrong.

=item C<$!filename>

The filename of the featherspec.

=item C<$!is_valid>

A boolean value indicating whether or not the JSON content is valid.

=item C<%!metadata>

Actual metadata structure from file.

=end pod

class Plumage::FeatherSpec;

has $!error;
has $!filename;
has $!is_valid;
has %!metadata;

# Accessors
method error()    { $!error    }
method filename() { $!filename }
method is_valid() { $!is_valid }
method metadata() { %!metadata }

method new(:$filename) {
    my $class := pir::getattribute__PPs(self.HOW, "parrotclass");

    Q:PIR {
        $P0  = find_lex '$class'
        self = new $P0
    };

    $!filename := $filename;

    return self;
}

method parse() {
    %!metadata := Config::JSON::ReadConfig($!filename);

    return self.validate;

    CATCH {
        $!error    := "Failed to parse featherspec file '$!filename'.";
        %!metadata := 0;

        return 0;
    }
}

method validate() {
    # Check for all required fields
    $!is_valid := %!metadata<name>
        && %!metadata<version>,
        && %!metadata<description>,
        && %!metadata<description><summary>,
        && %!metadata<description><detailed>,
        && %!metadata<description><license>,
        && %!metadata<description><homepage>,
        && %!metadata<dependencies>,
        && %!metadata<platforms>,
        && %!metadata<source>,
        && %!metadata<source><file>,
        && %!metadata<source><sha256>,
        && %!metadata<type>;

    $!error := $!is_valid
        ?? ''
        !! "File $!filename is not a valid featherspec.";

    return $!is_valid;
}

# vim: ft=perl6
