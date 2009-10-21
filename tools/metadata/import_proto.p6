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

        # Apparently dead (or misconfigured) projects
        next if $project ~~ /^epoxy/;

        %info<project> = $project;

        my $json := make_meta_file(%info);
    }
}

sub make_meta_file (%info is rw) {
    guess_repo_info(%info);
    checkout_repo(%info);

    return json_from_meta_info(%info);
}

sub guess_repo_info (%info is rw) {
    my $project = %info<project>;
    my $owner   = %info<owner>;
    my $home    = %info<home>;

    given $home {
        when 'github' {
            %info<type>         = 'git';
            %info<authority>    = "github.com/$owner";
            %info<checkout_uri> = "git://github.com/$owner/$project.git";
            %info<browser_uri>  = "http://github.com/$owner/$project/tree/master";
            %info<project_uri>  = "http://github.com/$owner/$project";
        }
        when 'gitorious' {
            %info<type>         = 'git';
            %info<authority>    = "gitorious.org/~$owner";
            %info<checkout_uri> = "git://gitorious.org/$project/mainline.git";
            %info<browser_uri>  = "http://gitorious.org/$project/mainline/trees/master";
            %info<project_uri>  = "http://gitorious.org/$project";
        }
        when 'googlecode' {
            %info<type>         = 'svn';
            %info<authority>    = "googlecode.com/$project";
            %info<checkout_uri> = "http://$project.googlecode.com/svn/trunk";
            %info<browser_uri>  = "http://code.google.com/p/$project/source/browse/";
            %info<project_uri>  = "http://code.google.com/p/$project/";
        }
        default {
            die "Unknown home '$home' for project '$project'.\n";
        }
    }
}

sub checkout_repo (%info) {
    my $project  = %info<project>;
    my $temp_dir = 'import_temp';
    my $cwd      = $*CWD;

    mkdir($temp_dir);
    chdir($temp_dir);

    given %info<type> {
        when 'git' {
            run("git clone    {%info<checkout_uri>} $project");
        }
        when 'svn' {
            run("svn checkout {%info<checkout_uri>} $project");
        }
    }

    die "Could not checkout $project at {%info<checkout_uri>}" unless $project ~~ :e;

    chdir($project);

    say "Cloned $project";

    chdir($cwd);
}

sub json_from_meta_info (%info) {
    return '{
    "meta-spec"    : {
        "version"  : 1,
        "uri"      : "https://trac.parrot.org/parrot/wiki/ModuleEcosystem"
    },
    "general"      : {
        "name"     : "' ~ %info<project> ~ '",
        "abstract" : "",
        "authority": "' ~ %info<authority> ~ '",
        "version"  : "HEAD",
        "license"  : {
            "type" : "UNKNOWN",
            "uri"  : "UNKNOWN",
        },
        "copyright_holder" : "' ~ %info<owner> ~ '",
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
        "provides"     : ["' ~ %info<project> ~ '"],
        "requires"     : {
            "fetch"    : ["' ~ %info<type> ~ '"],
            "configure": ["perl5"],
            "build"    : ["perl5", "make"],
            "test"     : ["make"],
            "install"  : ["make"],
            "runtime"  : []
        }
    },
    "resources"            : {
        "repository"       : {
             "type"        : "' ~ %info<type> ~ '",
             "checkout_uri": "' ~ %info<checkout_uri> ~ '",
             "browser_uri" : "' ~ %info<browser_uri> ~ '",
             "project_uri" : "' ~ %info<project_uri> ~ '"
        }
    }
}
';
}
