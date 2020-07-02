package GoGameTools::Porcelain::SiteWrite;
use GoGameTools::features;
use GoGameTools::Util;
use GoGameTools::JSON;
use Path::Tiny;
use GoGameTools::Class qw(
  $site_dir $dir $viewer_delegate
  $site_data @nav_tree
);

sub assert_path_accessor ($self, $accessor, $default) {
    $self->$accessor(path($self->$accessor // $default));
    unless ($self->$accessor->exists) { die "no $accessor, quitting\n" }
}

sub run ($self) {
    return (
        sub ($site_data) {
            $self->site_data($site_data);
            $self->dir(path($self->dir));
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
    return $self->dir->child('collections');
}

sub support_dir ($self) {
    return $self->site_dir->child('support');
}

# separate method so we could do logging, overwrite checks etc.
sub write_file ($self, $path, $data) {
    $path->spew_utf8($data);
}

# For each collection, each SGJ object needs an 'order' in which it originally
# appeared in the collection. This is required for the 'tree order' button to
# work. 'Tree order' means that the user wants to study the problems in a kind
# of narrative order.
sub add_order_to_array_ref ($array) {
    while (my ($i, $element) = each $array->@*) {
        $element->{order} = $i;
    }
}

sub write_by_filter ($self) {
    my $by_filter_dir = $self->collection_dir->child('by_filter');
    for my $section ($self->site_data->{menu}->@*) {
        my @result_topics;    # collects topics for current section
        for my $topic ($section->{topics}->@*) {
            $topic->{problems} //= [];
            next unless $topic->{problems}->@*;
            add_order_to_array_ref($topic->{problems});

            # Write the matching problems to a file, and store its filename
            # in the nav tree.
            my $data = {
                section => $section->{text},
                (exists $topic->{group} ? (group => $topic->{group}) : ()),
                topic    => $topic->{text},
                problems => $topic->{problems},
            };
            $self->write_collection_file(
                dir  => $by_filter_dir,
                file => "$topic->{filename}.html",
                data => $data,
            );
            $topic->{count} = scalar($topic->{problems}->@*);
            $topic->{collate} //= $topic->{text};
            delete $topic->{$_} for qw(filter problems);
            push @result_topics, $topic;
        }

        # Within each section, we want the topics sorted by group/collate.
        # There is 'group_collate', which says how groups are collated, and
        # 'collate', which says how topics are collated within one group. The
        # collation defaults to the display text.
        @result_topics =
          map  { $_->[1] }
          sort { $a->[0] cmp $b->[0] }
          map  { [ ($_->{group_collate} // $_->{group} // '') . $_->{collate}, $_ ] }
          @result_topics;
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
        add_order_to_array_ref($sgj_list);
        my $data = {
            section  => 'Same tree',
            topic    => 'Variations',
            problems => $sgj_list,
        };
        $self->write_collection_file(
            dir  => $by_collection_id_dir,
            file => "$id.html",
            data => $data,
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
        add_order_to_array_ref($sgj_list);
        my $data = {
            section  => 'Permalink',
            topic    => 'Problem',
            problems => $sgj_list,
        };

        # There can be many thousands of problems, so split the files into
        # two levels by the first two hex digits; e.g., 01/01234567.
        my $sub_dir = substr($id, 0, 2);
        $self->write_collection_file(
            dir  => $by_problem_id_dir->child($sub_dir),
            file => "$id.html",
            data => $data,
        );
    }
}

sub write_collection_file ($self, %args) {
    my sub js_escape ($s) { $s =~ s#'#\\'#gr }
    my $js = <<~EOTEMPLATE;
        var collection_section = '<% collection_section %>';
        var collection_group = '<% collection_group %>';
        var collection_topic = '<% collection_topic %>';
        let problems = <% problems_json %>;
    EOTEMPLATE
    my %vars = (
        collection_section => js_escape($args{data}{section}),
        collection_group   => js_escape($args{data}{group} // ''),
        collection_topic   => js_escape($args{data}{topic}),
        problems_json      => json_encode($args{data}{problems}, { pretty => 0 }),
    );
    $js =~ s/<% \s* (\w+) \s* %>/$vars{$1}/gex;
    $args{dir}->mkpath;

    # FIXME kludge: we munge the filename; this should be more generic
    my $filename = $args{file} =~ s/\.html$/\.js/r;
    $self->write_file($args{dir}->child($filename), $js);
}

sub get_menu ($self, %args) {
    my $menu = '';
    my sub next_pseudo_group_id {
        our $id //= 0;
        $id++;
        return "pseudo-group $id";
    }
    my sub topic_html ($topic) {
        return
          qq!<a href="/training-module-collection/?collection=by_filter/$topic->{filename}">$topic->{text} ($topic->{count})</a>\n!;
    }
    my sub html_for_group (%group) {
        my $group_html;
        my $topics_html = join "\n",
          map { '<li>' . topic_html($_) . '</li>' } $group{topics}->@*;
        if (defined $group{name}) {
            $group_html = <<~HTML;
                <li><span class="topic-group">$group{name}</span>
                    <ul>
                        $topics_html
                    </ul>
                </li>
            HTML
        } else {

            # Assume that groups without a name only have one topic
            $group_html = $topics_html;
        }
        return $group_html;
    }
    for my $section ($args{sections}->@*) {
        $menu .= sprintf "\n<h3>%s</h3>\n", $section->{text};
        $menu .= "<ul>\n";
        my %current_group = (id => '', name => '', topics => []);
        for my $topic ($section->{topics}->@*) {

            # New <li> if the group has changed. Topics that aren't in a group
            # get a pseudo group id; this makes the code easier than having to
            # keep track of empty group ids. Then write all topics we've
            # gathered for the current group.
            my $this_group_id = $topic->{group} // next_pseudo_group_id();
            if ($current_group{topics}->@* && $current_group{id} ne $this_group_id) {
                $menu .= html_for_group(%current_group);
                $current_group{topics}->@* = ();
            }
            push $current_group{topics}->@*, $topic;
            $current_group{id}   = $this_group_id;
            $current_group{name} = $topic->{group};
        }

        # After the last topic, we still need to write out the last group.
        $menu .= html_for_group(%current_group);
        $menu .= "</ul>\n";
    }
    return $menu;
}

sub write_menus ($self) {

    # Main menu page: Write a JS heredoc
    my $menu = $self->get_menu(sections => $self->nav_tree);
    $self->write_file($self->dir->child('menu-html-main.js'),
        "var menuHTML = `\n$menu`;\n");

    # Yunguseng Dojang menu page: Write a JS heredoc
    $menu = $self->get_menu(
        sections => [ grep { $_->{text} eq 'Yunguseng Dojang' } $self->nav_tree->@* ]);
    $self->write_file($self->dir->child('menu-html-yunguseng-dojang.js'),
        "var menuHTML = `\n$menu`;\n");
}

# use { pretty => 0 } to compact the JSON string
sub write_topic_index ($self) {
    my $json = json_encode($self->site_data->{topic_index}, { pretty => 0 });
    $self->collection_dir->mkpath;
    $self->write_file($self->collection_dir->child('topic_index.js'),
        "topicIndex = $json;");
}

sub copy_support_files ($self) {
    my $iterator =
      $self->support_dir->iterator({ recurse => 1, follow_symlinks => 1 });
    while (my $path = $iterator->()) {
        next if $path =~ /(\.DS_Store|\.un~|\.swp)$/o;
        next if $path->is_dir;
        my $dest_file = $self->dir->child($path->relative($self->site_dir));
        $dest_file->parent->mkpath;
        $path->copy($dest_file);
    }
}
1;
