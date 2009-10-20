#!/usr/bin/env perl6
use v6;

# Purpose: Import proto's projects into Plumage's metadata
# Status:  Early WIP

sub MAIN ($proto_dir) {
    @*INC.unshift("$proto_dir/lib");
    require 'Ecosystem.pm';

    my  %projects := Ecosystem::load-project-list("$proto_dir/projects.list");
    for %projects.kv -> $project, %info {
        next unless %info<home> && %info<owner>;

        my $json := make_meta_file($project, %info<home>, %info<owner>);
    }
}

sub make_meta_file ($project, $home, $owner) {
    my ($type, $authority, $checkout_uri, $browser_uri, $project_uri);

    given $home {
        when 'github' {
            $type         := 'git';
            $authority    := "github.com/$owner";
            $checkout_uri := "git://github.com/$owner/$project.git";
            $browser_uri  := "http://github.com/$owner/$project/tree/master";
            $project_uri  := "http://github.com/$owner/$project";
        }
        when 'gitorious' {
            $type         := 'git';
            $authority    := "gitorious.org/$project";
            $checkout_uri := "git://gitorious.org/$project/$project.git";
            $browser_uri  := "http://gitorious.org/$project/$project/trees/master";
            $project_uri  := "http://gitorious.org/$project/$project";
        }
        when 'googlecode' {
            $type         := 'svn';
            $authority    := "googlecode.com/$project";
            $checkout_uri := "http://$project.googlecode.com/svn/trunk";
            $browser_uri  := "http://code.google.com/p/$project/source/browse/";
            $project_uri  := "http://code.google.com/p/$project/";
        }
        default {
            die "Unknown home '$home' for project '$project'.\n";
        }
    }

    my $json = '{
    "meta-spec"    : {
        "version"  : 1,
        "uri"      : "https://trac.parrot.org/parrot/wiki/ModuleEcosystem"
    },
    "general"      : {
        "name"     : "' ~ $project ~ '",
        "abstract" : "",
        "authority": "' ~ $authority ~ '",
        "version"  : "HEAD",
        "license"  : {
            "type" : "UNKNOWN",
            "uri"  : "UNKNOWN",
        },
        "copyright_holder" : "' ~ $owner ~ '",
        "generated_by"     : "import_proto.p6",
        "keywords"         : [],
        "description"      : ""
    },
    "instructions" : {
        "fetch"    : {
            "type" : "repository"
        },
        "configure": {
            "type" : "perl5_configure"
        },
        "build"    : {
            "type" : "make"
        },
        "test"     : {
            "type" : "make"
        },
        "install"  : {
            "type" : "make"
        }
    },
    "dependency-info"  : {
        "provides"     : ["' ~ $project ~ '"],
        "requires"     : {
            "fetch"    : ["' ~ $type ~ '"],
            "configure": ["perl5"],
            "build"    : ["perl5", "make"],
            "test"     : ["make"],
            "install"  : ["make"],
            "runtime"  : []
        }
    },
    "resources"            : {
        "repository"       : {
             "type"        : "' ~ $type ~ '",
             "checkout_uri": "' ~ $checkout_uri ~ '",
             "browser_uri" : "' ~ $browser_uri ~ '",
             "project_uri" : "' ~ $project_uri ~ '"
        }
    }
}
';

    return $json;
}
