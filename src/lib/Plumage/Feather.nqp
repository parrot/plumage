# Copyright (C) 2011, Parrot Foundation.

=begin pod

=head1 NAME

Plumage::Feather - represents a source or binary feather

=head1 DESCRIPTION

The C<Plumage::Feather> class is an abstract representation of a Plumage
feather. It keeps track of the filename, the featherspec, etc.

=head2 Public Attributes

=item C<$!filename>

The filename of the feather.

=item C<$!spec>

A C<Plumage::FeatherSpec> object which represents the featherspec file used to
build the feather.

=end pod

class Plumage::Feather;

has $!filename;
has $!spec;

# Accessors
method filename() { $!filename  }
method spec()     { $!spec      }

method new(:$spec, :$filename) {
    my $class := pir::getattribute__PPs(self.HOW, "parrotclass");

    Q:PIR {
        $P0  = find_lex '$class'
        self = new $P0
    };

    $!filename := $filename;
    $!spec     := $spec;

    return self;
}

# vim: ft=perl6
