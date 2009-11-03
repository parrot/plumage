# Copyright (C) 2009, Parrot Foundation.
# $Id$

=begin

=head1 NAME

wget.pir - HTTP client

=head1 SYNOPSIS

    $ ./parrot wget.pir URL [FILENAME]

=head1 DESCRIPTION

Accepts a url to download, and optionally a filename to save it in.

This is a very thin wrapper around Plumage::Downloader::save_url_to_file

=end

.sub 'main' :main
    .param pmc argv
    .local string url, filename
    .local pmc c

    $I0 = elements argv
    gt $I0, 3, USAGE
    lt $I0, 2, USAGE
    $P0 = shift argv
    load_language 'parrot'
    c = compreg 'parrot'
    c.'import'('Plumage::Downloader')
    'save_url_to_file'(argv :flat)
    end
  USAGE:
    $P0 = getstderr
    $P0.'print'("Usage: parrot wget.pir URL [FILENAME]\n")
    exit 1
.end

# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:
