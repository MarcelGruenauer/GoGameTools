package GoGameTools::Porcelain::SiteWrite::Dynamic;
use GoGameTools::features;
use GoGameTools::Util;
use GoGameTools::JSON;
use List::Util qw(shuffle);
use Path::Tiny;
use parent qw(GoGameTools::Porcelain::SiteWrite::Static);

# FIXME
#
# - this generates files for the gogamespace.com WordPress site and so should
# probably be called something more descriptive than ::Dynamic.
#
# - for now this does pretty much the same as ::Static except for the menu, so
# we just inherit from ::Static.
#
# - later we'll change write_collection_file() and
# templates/dynamic/collection.html to use jQuery to load the problem JSON
# data.
sub default_collection_template_path ($self) {
    return $self->site_dir->child('templates')->child('dynamic')
      ->child('collection.html');
}

sub write_menu ($self) {
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
    my $output = "var menuHTML = `\n$menu`;\n";            # a JS heredoc
    my $file   = $self->dir->child('menu-html-main.js');
    $file->spew_utf8($output);
}
1;
