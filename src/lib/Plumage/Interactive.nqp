# Copyright (C) 2011, Parrot Foundation.

=begin pod

=head1 NAME

Plumage::Interactive - manages an interactive session

=head1 SYNOPSIS

    # Load library
    pir::load_bytecode('Plumage/Interactive.pbc')

    my $session := Plumage::Interactive.new;

=head1 DESCRIPTION

The C<Plumage::Interactive> class handles all the tasks of managing an
interactive session. For example, prompting for commands, .

=end pod

class Plumage::Interactive;

method new(:$action, :$args, :$usage, :$help) {
    my $class := pir::getattribute__PPs(self.HOW, "parrotclass");

    Q:PIR {
        $P0  = find_lex '$class'
        self = new $P0
    };

    self.welcome();

    return self;
}

method prompt(Str $msg) {
    return pir::getstdin__P().readline_interactive("$msg> ");
}

method welcome() {
    say("Plumage: Package Manager for Parrot\n"
      ~ "Copyright (C) 2009-2011, Parrot Foundation.\n\n"

      ~ "Enter 'help' for help or see docs/interactive.pod "
      ~ "for further information\n");
}

# vim: ft=perl6
