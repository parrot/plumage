# Copyright (C) 2011, Parrot Foundation.

=begin pod

=head1 NAME

Plumage::Interactive - manages an interactive session

=head1 DESCRIPTION

The C<Plumage::Interactive> class handles all the tasks of managing the
interactive command-line interface (CLI); for example, prompting for commands,
parsing user input, and running commands.

=head2 Object Initialization

=item C<new()>

Returns a new C<Plumage::Interactive> instance.

=head2 Public Attributes

=item C<$!input>

Contains the user input string.

=item C<$!prompt_string>

A string representing the text used for the command prompt. Defaults to
I<plumage>.

=head2 Methods

=item C<parse_command_line()>

Splits the user input in C<$!input> and returns an array where the first
element is the command and the remainder contains the arguments (if any).

=item C<prompt()>

Displays the command prompt and blocks until the user enters something.

=item C<welcome()>

Displays the welcome message. Called only once when the C<Plumage::Command>
object is instantiated.

=end pod

# TODO Make Plumage::Interactive a singleton object

class Plumage::Interactive;

has $!input;            # User input
has $!prompt_string;    # Text used for command prompt

# Accessors
method input()         { $!input         }
method prompt_string() { $!prompt_string }

method new(:$prompt_string = 'plumage') {
    my $class := pir::getattribute__PPs(self.HOW, "parrotclass");

    Q:PIR {
        $P0  = find_lex '$class'
        self = new $P0
    };

    $!prompt_string := $prompt_string;

    self.welcome();

    return self;
}

method parse_command_line() {
    pir::split__Pss(' ', $!input);
}

method prompt() {
    $!input := pir::getstdin__P().readline_interactive("$!prompt_string> ");
}

method welcome() {
    say("Plumage: Package Manager for Parrot\n"
      ~ "Copyright (C) 2009-2011, Parrot Foundation.\n\n"

      ~ "Enter 'help' for help or see docs/interactive.pod "
      ~ "for further information.\n");
}

# vim: ft=perl6
