package GoGameTools::Porcelain::SiteWrite::Dynamic;
use GoGameTools::features;
use GoGameTools::Util;
use GoGameTools::JSON;
use List::Util qw(shuffle);
use Path::Tiny;
use parent qw(GoGameTools::Porcelain::SiteWrite);

sub default_index_template_path ($self) {
    return $self->site_dir->child('templates')->child('dynamic')
      ->child('index.html');
}

sub default_collection_template_path ($self) {
    return $self->site_dir->child('templates')->child('dynamic')
      ->child('collection.html');
}

sub write_by_filter ($self, $site_data) {
}

# for each id with more than one problem, write a file
sub write_by_id ($self, $site_data) {
}

sub write_collection_file ($self, %args) {
}

sub write_index ($self, %args) {
}
1;
