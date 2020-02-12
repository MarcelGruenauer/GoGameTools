package GoGameTools::Porcelain::SiteWrite::Static;
use GoGameTools::features;
use GoGameTools::Util;
use GoGameTools::JSON;
use Path::Tiny;
use parent qw(GoGameTools::Porcelain::SiteWrite);
use GoGameTools::Class qw($no_permalinks);

sub default_index_template_path ($self) {
    return $self->site_dir->child('templates')->child('static')
      ->child('index.html');
}

sub default_collection_template_path ($self) {
    return $self->site_dir->child('templates')->child('static')
      ->child('collection.html');
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

sub write_by_problem_id ($self) {
    return if $self->no_permalinks;
    my $by_problem_id_dir = $self->collection_dir->child('by_problem_id');
    for my $sgj_obj ($self->site_data->{full_collection}->@*) {
        my $sgj_list = [$sgj_obj];    # dummy array so we can add the order...
        add_order_to_array_ref($sgj_list);
        my $data = {
            section  => 'Permalink',
            topic    => 'Problem',
            problems => $sgj_list,
        };

        # There can be many thousands of problems, so split the files into
        # three levels by first four hex digits; e.g., 01/23/01234567.
        my $id      = $sgj_obj->{problem_id};
        my $sub_dir = substr($id, 0, 2);
        $self->write_collection_file(
            dir  => $by_problem_id_dir->child($sub_dir),
            file => "$id.html",
            data => $data,
        );
    }
}

sub collection_as_json ($self, $collection) {

    # Impose problem order so results are consistent between runs.
    return json_encode(
        [ sort { $a->{problem_id} cmp $b->{problem_id} } $collection->@* ],
        { pretty => 0 });
}

sub write_collection_file ($self, %args) {
    my $html_template = path($self->collection_template_file)->slurp_utf8;
    my $html          = $self->render_template(
        $html_template,
        {   collection_section => $args{data}{section},
            collection_group   => $args{data}{group} // '',
            collection_topic   => $args{data}{topic},
            problems_json      => $self->collection_as_json($args{data}{problems}),
        }
    );
    $args{dir}->mkpath;
    $self->write_file($args{dir}->child($args{file}), $html);
}

sub write_menus ($self) {
    my $html_template = path($self->index_template_file)->slurp_utf8;
    my $menu          = '';
    my sub topic_html ($topic) {
        return
          qq!<a href="collections/by_filter/$topic->{filename}.html">$topic->{text} ($topic->{count})</a>\n!;
    }
    my sub next_pseudo_group_id {
        our $id //= 0;
        $id++;
        return "pseudo-group $id";
    }
    my sub add_html_for_group (%group) {
        my $group_html =
          $group{name} ? qq!<span class="topic-group">$group{name}</span> ! : '';
        my $topics_html = join " |\n", map { topic_html($_) } $group{topics}->@*;
        $menu .= "<li>$group_html$topics_html</li>\n";
    }
    for my $section ($self->nav_tree->@*) {
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
                add_html_for_group(%current_group);
                $current_group{topics}->@* = ();
            }
            push $current_group{topics}->@*, $topic;
            $current_group{id}   = $this_group_id;
            $current_group{name} = $topic->{group};
        }

        # After the last topic, we still need to write out the last group.
        add_html_for_group(%current_group);
        $menu .= "</ul>\n";
    }
    my $html = $self->render_template($html_template, { menu => $menu });
    $self->write_file($self->dir->child('index.html'), $html);
}

sub render_template ($self, $template, $vars_href) {
    return $template =~ s/<% \s* (\w+) \s* %>/$vars_href->{$1}/rgex;
}
1;
