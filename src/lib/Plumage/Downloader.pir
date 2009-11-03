# Copyright (C) 2009, Parrot Foundation.
# $Id$

=head1 NAME

Plumage::Downloader - Fetch the contents of a url in various ways

=head1 SYNOPSIS

Plumage::Downloader::save_to_file($url[, $filename])

=head1 DESCRIPTION

Downloads files.

.namespace ['Plumage';'Downloader']

.sub 'load' :anon :load :init
    .local pmc c
    load_language 'parrot'
    c = compreg 'parrot'
    c.'export'('save_url_to_file')
.end
.include 'socket.pasm'

.sub 'parse_url'
    # half-assed url parser; should use PGE and a URI grammar
    .param string url
    .local string host, path
    $S0 = substr url, 0, 7
    ne $S0, 'http://', no_trim
    url = substr url, 7
  no_trim:
    $I0 = index url, '/'
    host = substr url, 0, $I0
    path = substr url, $I0
    .return (host, path)
.end

.sub 'get_filename'
    .param string path
    .local string filename
    $I0 = 0
  slash_loop:
    inc $I0
    $I1 = index path, '/', $I0
    eq $I1, -1, end_slash_loop
    $I0 = $I1
    goto slash_loop
  end_slash_loop:
    filename = substr path, $I0
    .return (filename)
.end

.sub 'build_request'
    .param string host
    .param string path
    .param string ua     :optional
    .param int    has_ua :opt_flag
    .local string request
    .local pmc args
    ne has_ua, 0, got_ua
    ua = 'Parrot'
  got_ua:
    args = new 'FixedPMCArray'
    args = 3
    args[0] = path
    args[1] = host
    args[2] = ua
    request = sprintf "GET %s HTTP/1.1\r\nHost: %s\r\nUser-agent: %s\r\n\r\n", args
    .return (request)
.end

.sub 'parse_headers'
    .param string buf
    .local pmc lines, headers, it
    .local string i, k, v
    .local int returncode
    lines = split "\r\n", buf
    $S0 = shift lines
    $P0 = split ' ', $S0
    returncode = $P0[1]
    headers = new 'Hash'
    it = iter lines
  header_loop:
    unless it goto end_header_loop
    i = shift it
    $I0 = index i, ': '
    k = substr i, 0, $I0
    $I0 += 2
    v = substr i, $I0
    headers[k] = v
    goto header_loop
  end_header_loop:
    .return (returncode, headers)
.end

.sub 'save_url_to_file'
    .param string url
    .param string filename :optional
    .param int has_filename :opt_flag
    .local string host, path

    (host, path) = 'parse_url'(url)
    if has_filename goto got_filename
    filename = 'get_filename'(path)
    ne filename, '', got_filename
    die "Couldn't determine filename to save. Provide a filename."
  got_filename:

    .local pmc sock, address, fh, headers
    .local string headerbuf, buf, request
    .local int ret, len, got_headers, returncode

    # create the socket handle
    sock = new 'Socket'
    sock.'socket'(.PIO_PF_INET, .PIO_SOCK_STREAM, .PIO_PROTO_TCP)
    unless sock goto ERR

    # Pack a sockaddr_in structure with IP and port
    address = sock.'sockaddr'(host, 80)
    ret = sock.'connect'(address)

    request = 'build_request'(host, path, 'Plumage_HTTP')
    ret = sock.'send'(request)
    fh = new 'FileHandle'
    fh.'open'(filename, 'w')
    got_headers = 0
    $I5 = 1
MORE:
    #say $I5
    inc $I5
    buf = sock.'recv'()
    ret = length buf
    if ret <= 0 goto END
    ne got_headers, 0, save_content
    $I0 = index buf, "\r\n\r\n"
    ne $I0, -1, found_content
    concat headerbuf, buf
    goto MORE
  found_content:
    $S0 = substr buf, 0, $I0
    concat headerbuf, $S0
    (returncode, headers) = 'parse_headers'(headerbuf)
    $I1 = returncode / 100
    eq $I1, 2, http_success
    $S0 = returncode
    $S0 = concat "HTTP error: ", $S0
    die $S0
  http_success:
    $I0 += 4
    buf = substr buf, $I0
    got_headers = 1
  save_content:
    fh.'print'(buf)
    goto MORE
ERR:
    die "Socket error"
    end
END:
    fh.'close'()
    close sock
    end
.end

# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:
