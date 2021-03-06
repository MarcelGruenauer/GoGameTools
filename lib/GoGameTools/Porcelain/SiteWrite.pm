package GoGameTools::Porcelain::SiteWrite;
use GoGameTools::features;
use GoGameTools::Util;
use GoGameTools::JSON;
use Path::Tiny;
use GoGameTools::Class qw(
  $delete_metadata $site_dir $www_dir $viewer_delegate $site_data @nav_tree
);

sub assert_path_accessor ($self, $accessor, $default) {
    $self->$accessor(path($self->$accessor // $default));
    unless ($self->$accessor->exists) { die "no $accessor, quitting\n" }
}

sub run ($self) {
    return (
        sub ($site_data) {
            $self->site_data($site_data);
            $self->www_dir(path($self->www_dir));
            $self->assert_path_accessor('site_dir',
                "$ENV{HOME}/.local/share/gogametools/site/"
                  . $self->viewer_delegate->site_subdir);

            # perform the actions
            $self->write_by_filter;
            $self->write_by_collection_id;
            $self->write_by_problem_id;

            # After write_by_filters() has created $self->nav_tree, we can
            # write the menu.
            $self->write_menus;
            $self->write_topic_index;
            $self->copy_support_files;
        },
    );
}

sub collection_dir ($self) {
    return $self->www_dir->child('training')->child('collections');
}

# separate method so we could do logging, overwrite checks etc.
sub write_file ($self, $path, $data) {
    $path->spew_utf8($data);
}

# Munge SGJ objects before writing them.
#
# For each collection, each SGJ object needs an 'order' in which it originally
# appeared in the collection. This is required for the 'tree order' button to
# work. 'Tree order' means that the user wants to study the problems in a kind
# of narrative order.
#
# Also delete metadata and helper data that the site doesn't need.
sub fixup_collection ($self, $collection) {
    while (my ($i, $sgj_obj) = each $collection->@*) {
        $sgj_obj->{order} = $i;
        delete $sgj_obj->@{qw(game_info vars)};
        delete $sgj_obj->{metadata}{input_filename};
        delete $sgj_obj->{metadata} if $self->delete_metadata;
    }
}

sub write_by_filter ($self) {
    my $by_filter_dir = $self->collection_dir->child('by_filter');
    for my $section ($self->site_data->{menu}->@*) {
        my @result_topics;    # collects topics for current section
        for my $topic ($section->{topics}->@*) {
            $topic->{problems} //= [];
            next unless $topic->{problems}->@*;
            $self->fixup_collection($topic->{problems});

            # Write the matching problems to a file, and store its filename
            # in the nav tree.
            $self->write_collection_file(
                www_dir => $by_filter_dir,
                file    => "$topic->{filename}.html",
                data    => {
                    section  => $section->{text},
                    topic    => $topic->{text},
                    problems => $topic->{problems},
                    (defined($topic->{subsets}) ? (subsets => $topic->{subsets}) : ()),
                }
            );
            $topic->{count} = scalar($topic->{problems}->@*);
            $topic->{collate} //= $topic->{text};
            delete $topic->{$_} for qw(filter problems);
            push @result_topics, $topic;
        }

        # Within each section, we want the topics sorted. If a topic has
        # 'collate', it will be used as the sort key, otherwise the topic text
        # will be used.
        @result_topics =
          map  { $_->[1] }
          sort { $a->[0] cmp $b->[0] }
          map  { [ $_->{collate} // $_->{text}, $_ ] } @result_topics;
        if (@result_topics) {
            push $self->nav_tree->@*,
              { text   => $section->{text},
                topics => \@result_topics,
              };
        }
    }
}

# for each id with more than one problem, write a file
sub write_by_collection_id ($self) {
    my $by_collection_id_dir = $self->collection_dir->child('by_collection_id');
    while (my ($id, $sgj_list) = each $self->site_data->{by_collection_id}->%*) {
        next unless $sgj_list->@* > 1;
        $self->fixup_collection($sgj_list);
        $self->write_collection_file(
            www_dir => $by_collection_id_dir,
            file    => "$id.html",
            data    => {
                section  => 'Same tree',
                topic    => 'Variations',
                problems => $sgj_list,
            }
        );
    }
}

# problems won't have a problem_id if `gogame-site-gen-data --nopermalinks`
sub write_by_problem_id ($self) {
    my $by_problem_id_dir = $self->collection_dir->child('by_problem_id');
    for my $sgj_obj ($self->site_data->{full_collection}->@*) {
        my $id = $sgj_obj->{problem_id};
        return unless defined $id;
        my $sgj_list = [$sgj_obj];    # dummy array so we can add the order...
        $self->fixup_collection($sgj_list);

        # There can be many thousands of problems, so split the files into
        # two levels by the first two hex digits; e.g., 01/01234567.
        my $sub_dir = substr($id, 0, 2);
        $self->write_collection_file(
            www_dir => $by_problem_id_dir->child($sub_dir),
            file    => "$id.html",
            data    => {
                section  => 'Permalink',
                topic    => 'Problem',
                problems => $sgj_list,
            }
        );
    }
}

# FIXME kludge: we munge the filename; this should be more generic
sub write_collection_file ($self, %args) {
    $args{www_dir}->mkpath;
    my $filename = $args{file} =~ s/\.html$/\.json/r;
    $self->write_file($args{www_dir}->child($filename),
        json_encode($args{data}, { pretty => 0 }));
}

sub get_text_menu ($self, %args) {
    my $menu = '';
    for my $section ($args{sections}->@*) {
        $menu .= sprintf "\n<h3>%s</h3>\n", $section->{text};
        $menu .= "<ul>\n";
        for my $topic ($section->{topics}->@*) {
            $menu .=
              qq!<li><a href="/training-module-collection/?collection=by_filter/$topic->{filename}">$topic->{text} ($topic->{count})</a></li>\n!;
        }
        $menu .= "</ul>\n";
    }
    return $menu;
}

sub get_visual_menu ($self, %args) {
    my $menu = qq!<ul id="section-nav">\n!;

    # Quick top navigation to the sections
    for my $section ($args{sections}->@*) {
        $section->{anchor} = lc $section->{text} =~ s/\s+/-/gr;
        $menu .= sprintf qq!<li><a href="#%s">%s</a></li>\n!, $section->{anchor},
          $section->{text};
    }
    for my $section ($args{sections}->@*) {

        # Section header
        our $section_header_template //= <<~EOHTML;
            <div class="section-header">
                <div class="section-title">
                    <h3 id="<% anchor %>"><% text %></h3>
                </div>
                <div class="section-top-link">
                    <a href="#section-nav">Top</a>
                </div>
            </div>
        EOHTML
        my %vars = ($section->%*);
        $menu .= $section_header_template =~ s/<% \s* (\w+) \s* %>/$vars{$1}/rgex;

        # Section contents
        $menu .= qq!<div class="ggs-menu-section">\n!;
        for my $topic ($section->{topics}->@*) {
            our $menu_item_template //= <<~EOHTML;
                <div class="ggs-menu-item">
                    <div class="ggs-menu-item-thumbnail">
                        <a href="<% href %>">
                            <img src="/training/support/images/thumbnails/<% thumbnail %>">
                        </a>
                    </div>
                    <div class="ggs-menu-item-title">
                        <a href="<% href %>">
                            <% text %> (<% count %>)
                        </a>
                    </div>
                </div>
            EOHTML
            my %vars = (
                href =>
                  qq!/training-module-collection/?collection=by_filter/$topic->{filename}!,
                $topic->%*,
            );
            $menu .= $menu_item_template =~ s/<% \s* (\w+) \s* %>/$vars{$1}/rgex;
        }
        $menu .= "</div>\n";
    }
    $menu .= "</ul>\n";
    return $menu;
}

sub write_menus ($self) {

    # Main menu page: Write a JS heredoc
    $self->write_file(
        $self->www_dir->child('training')->child('menu-html-main.js'),
        sprintf("var menuHTML = `\n%s`;\n",
            $self->get_visual_menu(sections => $self->nav_tree))
    );

    # Yunguseng Dojang menu page: Write a JS heredoc
    $self->write_file(
        $self->www_dir->child('training')->child('menu-html-yunguseng-dojang.js'),
        sprintf(
            "var menuHTML = `\n%s`;\n",
            $self->get_text_menu(
                sections => [ grep { $_->{text} eq 'Yunguseng Dojang' } $self->nav_tree->@* ]
            )
        )
    );
}

# use { pretty => 0 } to compact the JSON string
sub write_topic_index ($self) {
    $self->collection_dir->mkpath;
    $self->write_file(
        $self->collection_dir->child('topic_index.js'),
        sprintf("topicIndex = %s;",
            json_encode($self->site_data->{topic_index}, { pretty => 0 }))
    );
}

sub copy_support_files ($self) {
    my $iterator =
      $self->site_dir->iterator({ recurse => 1, follow_symlinks => 1 });
    while (my $path = $iterator->()) {
        next if $path =~ /(\.DS_Store|\.un~|\.swp)$/o;
        next if $path->is_dir;
        my $dest_file = $self->www_dir->child($path->relative($self->site_dir));
        $dest_file->parent->mkpath;
        $path->copy($dest_file);
    }
}
1;
