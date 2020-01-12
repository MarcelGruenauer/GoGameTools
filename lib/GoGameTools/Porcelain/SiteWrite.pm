package GoGameTools::Porcelain::SiteWrite;
use GoGameTools::features;
use GoGameTools::Util;
use GoGameTools::JSON;
use Path::Tiny;
use GoGameTools::Class qw(
  $site_dir $dir $viewer_delegate
  $index_template_file $collection_template_file
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
            $self->assert_path_accessor('index_template_file',
                $self->default_index_template_path);
            $self->assert_path_accessor('collection_template_file',
                $self->default_collection_template_path);

            # perform the actions
            $self->write_by_filter;
            $self->write_by_id;

            # After write_by_filters() has created $self->nav_tree, we can
            # write the menu.
            $self->write_menu;
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

# use { pretty => 0 } to compact the JSON string
sub write_topic_index ($self) {
    my $json = json_encode($self->site_data->{topic_index}, { pretty => 0 });
    $self->collection_dir->mkpath;
    $self->collection_dir->child('topic_index.js')
      ->spew_utf8("topicIndex = $json;");
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
