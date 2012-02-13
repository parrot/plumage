# Parrot Plumage

Parrot Plumage is the Parrot Virtual Machine module ecosystem.  It includes
tools to search metadata, handle dependencies, install modules, and so forth.

This is the first implementation of the toolchain for Parrot Plumage;
it is functional for day-to-day use, but still under rapid development,
and we're always looking for testers and contributors (see CONTRIBUTING
below).

The initial overall design document can be found at:

    https://trac.parrot.org/parrot/wiki/ModuleEcosystem

We practice the 'whirlpool' development model, so this design document
could at best be described as "getting us close enough to the sucking
vortex to begin our descent".  We expect to make many changes as we
discover new issues during implementation.


# Building

    parrot setup.pir build
# Testing

    parrot setup.pir test

# Installing

    parrot setup.pir install

# Using

Once built, Plumage is relatively easy to use, especially if you've used
another install tool such as apt-get or yum.  For example, to install
Rakudo (a Perl 6 implementation), run the following command:

    ./plumage install rakudo

This will automatically install any dependencies that Rakudo may need.
To see what those dependencies are, try this:

    ./plumage showdeps rakudo

To see what other commands and options are available, ask for usage info:

    ./plumage usage

If you have any problems, just come by #parrot at irc.parrot.org and ask.
We're happy to help!


# Contributing

We aim to be very contributor-friendly here; take a look at the documents
in the docs/hacking/ directory (starting with contributing.pod) to get up
to speed.

Welcome to the crew, and don't forget to be bold!

# License

Parrot Plumage is Copyright (C) 2009-2012, The Parrot Foundation, and is
distributed under the terms of the Artistic License 2.0.  For more
details, see the full text of the license in the file LICENSE.
