# Copyright (C) 2011, Parrot Foundation.

=begin pod

=head1 NAME

Plumage::Command - represents a Plumage command

=head1 DESCRIPTION

The C<Plumage::Command> class is an abstract representation of a Plumage
command. It keeps track of the command name, its arguments, and any associated
help/usage information.

=head2 Object Initialization

=item C<new()>

Returns a new C<Plumage::Command> instance.

=head2 Public Attributes

=item C<$!action>

Contains a reference to the callback subroutine to execute.

=item C<$!args>

A string representing the type of arguments the command takes. It can take the
following forms: 

    * 'none'        - no arguments
    * 'opt_command' - optional command
    * 'opt_project' - optional project
    * 'project'     - project name

=item C<$!usage>

A string which describes the semantics of using the command.

=item C<$!help>

A string which describes the purpose of the command in more detail.

=end pod

class Plumage::Command;

has $!action;    # Subroutine to execute
has $!args;      # Type of argument(s) command takes
has $!usage;     # Describes semantics of command usage
has $!help;      # Describes purpose of command in more detail

# Accessors
method action() { $!action }
method args()   { $!args   }
method usage()  { $!usage  }
method help()   { $!help   }

method new(:$action, :$args, :$usage, :$help) {
    my $class := pir::getattribute__PPs(self.HOW, "parrotclass");

    Q:PIR {
        $P0  = find_lex '$class'
        self = new $P0
    };

    $!action := $action;
    $!args   := $args;
    $!usage  := $usage;
    $!help   := $help;

    return self;
}

# vim: ft=perl6
