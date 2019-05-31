package GoGameTools::Porcelain::SiteWrite;
use GoGameTools::features;
use GoGameTools::Util;
use GoGameTools::JSON;
use List::Util qw(shuffle);
use Path::Tiny;
use GoGameTools::Class qw(
  new $site_dir $dir $viewer_delegate
  $index_template_file $collection_template_file
);

sub assert_path_accessor ($self, $accessor, $default) {
    $self->$accessor(path($self->$accessor // $default));
    unless ($self->$accessor->exists) { die "no $accessor, quitting\n" }
}

sub run ($self) {
    return (
        sub ($site_data) {
            $self->dir(path($self->dir));
            $self->assert_path_accessor('site_dir',
                "$ENV{HOME}/.local/share/gogametools/site/"
                  . $self->viewer_delegate->site_subdir);
            $self->assert_path_accessor('index_template_file',
                $self->site_dir->child('templates')->child('index.html'));
            $self->assert_path_accessor('collection_template_file',
                $self->site_dir->child('templates')->child('collection.html'));

            # perform the actions
            $self->write_by_filter($site_data);
            $self->write_by_id($site_data);
            $self->write_topic_index($site_data);
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

sub write_by_filter ($self, $site_data) {
    my @nav_tree;
    my $by_filter_dir = $self->collection_dir->child('by_filter');
    for my $section ($site_data->{menu}->@*) {
        my @result_topics;    # collects topics for current section
        for my $topic ($section->{topics}->@*) {
            $topic->{problems} //= [];
            next unless $topic->{problems}->@*;

            # Write the matching problems to a file, and store its filename
            # in the nav tree.
            my $data = {
                section => $section->{text},
                (exists $topic->{group} ? (group => $topic->{group}) : ()),
                topic    => $topic->{text},
                problems => [ shuffle $topic->{problems}->@* ],
            };
            $self->write_collection_file(
                dir  => $by_filter_dir,
                file => "$topic->{filename}.html",
                data => $data,
            );
            $topic->{count} = scalar($topic->{problems}->@*);
            delete $topic->{$_} for qw(filter problems);
            push @result_topics, $topic;
        }
        if (@result_topics) {
            push @nav_tree,
              { text   => $section->{text},
                topics => \@result_topics,
              };
        }
    }
    $self->write_index(
        file     => $self->dir->child('index.html'),
        nav_tree => \@nav_tree
    );
}

# for each id with more than one problem, write a file
sub write_by_id ($self, $site_data) {
    my $by_id_dir = $self->collection_dir->child('by_id');
    while (my ($id, $sgj_list) = each $site_data->{by_id}->%*) {
        next unless $sgj_list->@* > 1;
        my $data = {
            section  => 'Same tree',
            topic    => 'Variations',
            problems => [ shuffle $sgj_list->@* ],
        };

        # split by first two hex digits. E.g., 01/01234
        $self->write_collection_file(
            dir  => $by_id_dir,
            file => "$id.html",
            data => $data,
        );
    }
}

# use { pretty => 0 } to compact the JSON string
sub write_topic_index ($self, $site_data) {
    my $json = json_encode($site_data->{topic_index}, { pretty => 0 });
    $self->collection_dir->mkpath;
    $self->collection_dir->child('topic_index.js')
      ->spew_utf8("topicIndex = $json;");
}

sub write_collection_file ($self, %args) {
    my $html_template = path($self->collection_template_file)->slurp_utf8;
    my $html          = $self->render_template(
        $html_template,
        {   collection_section => $args{data}{section},
            collection_group   => $args{data}{group} // '',
            collection_topic   => $args{data}{topic},
            problems_json      => json_encode($args{data}{problems}, { pretty => 0 }),
        }
    );
    $args{dir}->mkpath;
    $args{dir}->child($args{file})->spew_utf8($html);
}

sub write_index ($self, %args) {
    my $html_template = path($self->index_template_file)->slurp_utf8;
    my $menu          = '';
    for my $section ($args{nav_tree}->@*) {
        $menu .= sprintf "\n<h3>%s</h3>\n", $section->{text};
        $menu .= "<ul>\n";
        for my $topic ($section->{topics}->@*) {
            my $group =
              $topic->{group} ? qq!<span class="topic-group">$topic->{group}</span> ! : '';
            $menu .= sprintf qq!<li>%s<a href="%s">%s (%d)</a></li>\n!,
              $group, "collections/by_filter/$topic->{filename}.html",
              $topic->{text}, $topic->{count};
        }
        $menu .= "</ul>\n";
    }
    my $html = $self->render_template($html_template, { menu => $menu });
    $args{file}->spew_utf8($html);
}

sub copy_support_files ($self) {
    my $iterator =
      $self->support_dir->iterator({ recurse => 1, follow_symlinks => 1 });
    while (my $path = $iterator->()) {
        next unless $path =~ /\.(css|js)$/o;
        my $dest_file = $self->dir->child($path->relative($self->site_dir));
        $dest_file->parent->mkpath;
        $path->copy($dest_file);
    }
}

sub render_template ($self, $template, $vars_href) {
    return $template =~ s/<% \s* (\w+) \s* %>/$vars_href->{$1}/rgex;
}
1;
