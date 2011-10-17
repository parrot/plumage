# Copyright (C) 2011, Parrot Foundation.

=begin pod

=head1 NAME

Plumage::Command - represents a Plumage command

=head1 SYNOPSIS

    # Load library
    pir::load_bytecode('Plumage/Command.pbc')

    # Class methods    
    my $help_cmd := Plumage::Command.new(:action(command_help),
                                         :args('opt_command'),
                                         :usage('help [<command>]'),
                                         :help('Displays a help message on command usage.')),

    # Accessors
    my $help_cmd.action;
    my $help_cmd.args;
    my $help_cmd.usage;
    my $help_cmd.help;

=head1 DESCRIPTION

The C<Plumage::Command> class is an abstract representation of a Plumage
command.

=end pod

class Plumage::Command;

has $!action;    # Subroutine to execute
has $!args;      # Type of argument(s) command takes
has $!usage;     # Describes semantics of command usage
has $!help;      # Describes purpose of command in more detail

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

# Accessors
method action() { return $!action }
method args()   { return $!args   }
method usage()  { return $!usage  }
method help()   { return $!help   }

# vim: ft=perl6
