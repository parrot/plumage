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

sub checkout_repo (%info is rw) {
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

    say "Cloned $project";

    chdir($project);

    if 'LICENSE' ~~ :e {
        my $md5sum = (qx`md5sum LICENSE`).subst(/ \s+ .* $ /, {''});

        if $md5sum ~~ 'b4a94da2a1f918b217ef5156634fc9e0'
                    | '18740546821e33d23e8809da70d4a79a' {
            %info<license>       = {};
            %info<license><type> = 'artistic2';
            %info<license><uri>  = 'http://www.perlfoundation.org/artistic_license_2_0';
        }
    }
    unless %info<license><type> {
        %info<license><type> = 'UNKNOWN';
        %info<license><uri>  = 'UNKNOWN';
    }

    if 'lib' ~~ :e {
        %*ENV<PERL6LIB> = "$*CWD/lib";
    }

    if    'Makefile.PL'  ~~ :e {
        %info<configure_requires> = ('perl5');
        %info<configure> = 'perl5_makefile';
        run('perl Makefile.PL');
    }
    elsif 'Configure.pl' ~~ :e {
        %info<configure_requires> = ('perl6');
        %info<configure> = 'perl6_configure';
        run('perl6 Configure.pl');
    }
    elsif 'Configure'    ~~ :e {
        %info<configure_requires> = ('perl6');
        %info<configure> = 'perl6_configure';
        run('perl6 Configure');
    }
    else {
        %info<configure_requires> = ();
    }

    if 'Makefile' ~~ :e {
        %info<build_requires>   = ('make');
        %info<test_requires>    = ('make');
        %info<install_requires> = ('make');

        %info<build>   = 'make';
        %info<test>    = 'make';
        %info<install> = 'make';
    }
    else {
        %info<build_requires>   = ();
        %info<test_requires>    = ();
        %info<install_requires> = ();
    }

    chdir($cwd);
}

sub json_from_meta_info (%info) {
    %info<test_requires>.push('rakudo');

    my $configure_requires = %info<configure_requires>.map({"\"$_\""}).join(', ');
    my $build_requires     = %info<build_requires>.map({"\"$_\""}).join(', ');
    my $test_requires      = %info<test_requires>.map({"\"$_\""}).join(', ');
    my $install_requires   = %info<install_requires>.map({"\"$_\""}).join(', ');

    my $configure = '';
    if %info<configure> {
        $configure = '
        "configure": {
            "type" : "' ~ %info<configure> ~ '"
        },';
    }

    my $build = '';
    if %info<build> {
        $build = '
        "build": {
            "type" : "' ~ %info<build> ~ '"
        },';
    }

    my $test = '';
    if %info<test> {
        $test = '
        "test": {
            "type" : "' ~ %info<test> ~ '"
        },';
    }

    my $install = '';
    if %info<install> {
        $install = '
        "install": {
            "type" : "' ~ %info<install> ~ '"
        }';
    }

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
            "type" : "' ~ %info<license><type> ~ '",
            "uri"  : "' ~ %info<license><uri>  ~ '",
        },
        "copyright_holder" : "' ~ %info<owner> ~ '",
        "generated_by"     : "import_proto.p6",
        "keywords"         : [],
        "description"      : ""
    },
    "instructions" : {
        "fetch"    : {
            "type" : "repository"
        },' ~ $configure ~ $build ~ $test ~ $install ~'
    },
    "dependency-info"  : {
        "provides"     : ["' ~ %info<project> ~ '"],
        "requires"     : {
            "fetch"    : ["' ~ %info<type> ~ '"],
            "configure": [' ~ $configure_requires ~ '],
            "build"    : [' ~ $build_requires ~ '],
            "test"     : [' ~ $test_requires ~ '],
            "install"  : [' ~ $install_requires ~ '],
            "runtime"  : ["rakudo"]
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
