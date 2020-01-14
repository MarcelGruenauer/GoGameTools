package GoGameTools::Porcelain::SiteWrite::Dynamic;
use GoGameTools::features;
use GoGameTools::Util;
use GoGameTools::JSON;
use Path::Tiny;
use parent qw(GoGameTools::Porcelain::SiteWrite::Static);

# FIXME
#
# - this generates files for the gogamespace.com WordPress site and so should
# probably be called something more descriptive than ::Dynamic.
sub write_collection_file ($self, %args) {
    my sub js_escape ($s) {
        $s =~ s#'#\\'#g;
        return $s;
    }
    my $template = <<~EOTEMPLATE;
        var collection_section = '<% collection_section %>';
        var collection_group = '<% collection_group %>';
        var collection_topic = '<% collection_topic %>';
        let problems = <% problems_json %>;
    EOTEMPLATE
    my $js = $self->render_template(
        $template,
        {   collection_section => js_escape($args{data}{section}),
            collection_group   => js_escape($args{data}{group} // ''),
            collection_topic   => js_escape($args{data}{topic}),
            problems_json      => json_encode($args{data}{problems}, { pretty => 0 }),
        }
    );
    $args{dir}->mkpath;

    # FIXME kludge: we munge the filename; this should be more generic
    my $filename = $args{file} =~ s/\.html$/\.js/r;
    $args{dir}->child($filename)->spew_utf8($js);
}

sub write_menus ($self) {
    $self->write_menu(
        sections => $self->nav_tree,
        file   => $self->dir->child('menu-html-main.js'),
    );
    $self->write_menu(
        sections => [ grep { $_->{text} eq 'Yunguseng Dojang' } $self->nav_tree->@* ],
        file   => $self->dir->child('menu-html-yunguseng-dojang.js'),
    );
}

sub write_menu ($self, %args) {
    my $html_template = path($self->index_template_file)->slurp_utf8;
    my $menu          = '';
    my sub topic_html ($topic) {
        return
          qq!<a href="/training-module-collection/?collection=by_filter/$topic->{filename}">$topic->{text} ($topic->{count})</a>\n!;
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
    my $output = "var menuHTML = `\n$menu`;\n";            # a JS heredoc
    $args{file}->spew_utf8($output);
}
1;
