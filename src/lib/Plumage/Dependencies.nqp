=begin

=head1 NAME

Plumage::Dependencies - Resolve dependency relationships

=head1 SYNOPSIS

    # Load this library
    pir::load_bytecode('src/lib/Plumage/Dependencies.pbc');



=head1 DESCRIPTION

=end

class Plumage::Dependencies;


method resolve_dependencies (@projects) {
    my @known_projects := Plumage::Metadata.get_project_list();
    my @all_deps       := self.all_dependencies(@projects);
    my @installed      := self.get_installed_projects;

    my %is_project     := set_from_array(@known_projects);
    my %is_installed   := set_from_array(@installed);

    my @have_bin;
    my @need_bin;
    my @have_project;
    my @need_project;
    my @need_unknown;

    for @all_deps -> $dep {
        if %*BIN{$dep} || find_program($dep) {
            @have_bin.push($dep);
        }
        elsif %*BIN.exists($dep) {
            @need_bin.push($dep);
        }
        elsif %is_installed{$dep} {
            @have_project.push($dep);
        }
        elsif %is_project{$dep} {
            @need_project.push($dep);
        }
        else {
            @need_unknown.push($dep);
        }
    }

    my %resolutions;

    %resolutions<have_bin>     := @have_bin;
    %resolutions<need_bin>     := @need_bin;
    %resolutions<have_project> := @have_project;
    %resolutions<need_project> := @need_project;
    %resolutions<need_unknown> := @need_unknown;

    return %resolutions;
}


method all_dependencies (@projects) {
    my @dep_stack;
    my @deps;
    my %seen;

    for @projects -> $project {
        @dep_stack.unshift($project);
        %seen{$project} := 1;
    }

    while @dep_stack {
        my $project := @dep_stack.pop();
        my $meta    := Plumage::Metadata.new();
        my $valid   := $meta.find_by_project_name($project);

        if $valid {
            my %info_deps := $meta.metadata<dependency-info>;
            if %info_deps {
                my %requires := %info_deps<requires>;
                if %requires {
                    for %requires.values -> @step_requires {
                        for @step_requires -> $dep {
                            unless %seen{$dep} {
                                @dep_stack.push($dep);
                                @deps.unshift($dep);
                                %seen{$dep} := 1;
                            }
                        }
                    }
                }
            }
        }
    }

    return @deps;
}


method get_installed_projects () {
    my $inst_file := replace_config_strings(%*CONF<installed_list_file>);
    my $contents  := slurp($inst_file);
    my @projects  := grep(-> $_ { ?$_ }, pir::split("\n", $contents));

    return @projects;

    CATCH {
        return [];
    }
}


method mark_projects_installed (@projects) {
    my $lines := pir::join("\n", @projects) ~ "\n";
    my $file  := replace_config_strings(%*CONF<installed_list_file>);

    append($file, $lines);
}
