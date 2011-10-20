# Copyright (C) 2011, Parrot Foundation.

=begin pod

=head1 NAME

Plumage::FeatherSpec - represents a featherspec file

=head1 DESCRIPTION

The C<Plumage::FeatherSpec> class is an abstract representation of a
featherspec file.

=head2 Public Attributes

=item C<$!filename>

The filename of the featherspec.

=end pod

class Plumage::FeatherSpec;

has $!filename;

# Accessors
method filename() { $!filename  }

method new(:$filename) {
    my $class := pir::getattribute__PPs(self.HOW, "parrotclass");

    Q:PIR {
        $P0  = find_lex '$class'
        self = new $P0
    };

    $!filename := $filename;

    return self;
}

# vim: ft=perl6
