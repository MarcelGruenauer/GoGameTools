package GoGameTools::Porcelain::SiteGenData;
use GoGameTools::features;
use GoGameTools::Util;
use GoGameTools::JSON;
use GoGameTools::Porcelain::Subsets;
use GoGameTools::Parser::FilterQuery;
use utf8;
use GoGameTools::Class qw($no_permalinks @menu);

sub run ($self) {
    return (
        sub ($collection) {

            # munge the SGJ objects so they look like eval_query() expects
            my (%problems_with_collection_id, %topic_index);
            for my $sgj_obj ($collection->@*) {
                $sgj_obj->{problem_id} = utf8_sha1_hex($sgj_obj->{sgf})
                  unless $self->no_permalinks;
                $sgj_obj->{collection_id} =
                  utf8_sha1_hex(sprintf '%s %s', $sgj_obj->{metadata}->@{qw(filename index)});
                $sgj_obj->{topics} = [];
                $sgj_obj->{vars}   = query_vars_from_sgj($sgj_obj);
                push @{ $problems_with_collection_id{ $sgj_obj->{collection_id} } //= [] },
                  $sgj_obj;
            }

            # concatenate the lists from all menu locations
            my @sections = map { read_menu($_)->@* } $self->menu->@*;

            # For each topic, find the problems matching the topic's filter
            # expression. Store them with the topic.
            #
            # @result_sections and @result_topics_for_section are intermediate variables so
            # we can only take those sections and topics that actually contain problems.
            my @result_sections;
            for my $section (@sections) {
                my @result_topics_for_section;
                handle_computed_properties_for_section($section);
                for my $topic ($section->{topics}->@*) {

                    # find problems for this topic
                    my $problems = get_problems_for_subset($topic, $collection);
                    next unless $problems->@*;
                    $topic->{problems} = $problems;

                    # Handle subsets: determine how many problems are in each
                    # subset; skip subsets without problems.
                    if (defined $topic->{subsets}) {
                        for my $subset ($topic->{subsets}->@*) {
                            my $subset_problems = get_problems_for_subset($subset, $problems);
                            $subset->{count} = $subset_problems->@*;    # we only want the count
                        }

                        # remove subsets without problems
                        $topic->{subsets} = [ grep { $_->{count} > 0 } $topic->{subsets}->@* ];
                    }

                    # The filename that the topic's problem collection will be written to.
                    $topic->{filename} = $topic->{id};

                    # When a problem is displayed, we want to show links to topics where
                    # this problem occurs. So build up a topic index that contains the
                    # button title and the topic's collection filename.
                    my %topic_for_index = $topic->%*;
                    $topic_for_index{count} = scalar($topic_for_index{problems}->@*);
                    delete $topic_for_index{problems};
                    $topic_index{ $topic->{filename} } = \%topic_for_index;

                    # For each problem in the current topic's collection, remember that
                    # these problems occurred in this topic. So at the end of the loop each
                    # problem contains a list of all the topics it occurs in.
                    push $_->{topics}->@*, $topic->{filename} for $topic->{problems}->@*;
                    push @result_topics_for_section, $topic;
                }
                if (@result_topics_for_section) {
                    $section->{topics} = \@result_topics_for_section;
                    push @result_sections, $section;
                }
            }
            for my $sgj_obj ($collection->@*) {
                $sgj_obj->{related_positions} =
                  scalar($problems_with_collection_id{ $sgj_obj->{collection_id} }->@*);

                # include refs and tags so that subset filtering can work
                $sgj_obj->{$_} = $sgj_obj->{metadata}{$_} for qw(refs tags);
            }

            # delete entries from the topic index that don't have problems
            my @empty_topic_index_keys;
            while (my ($k, $v) = each %topic_index) {
                push @empty_topic_index_keys, $k if $v->{count} == 0;
            }
            delete @topic_index{@empty_topic_index_keys};
            return +{
                menu             => \@result_sections,
                by_collection_id => \%problems_with_collection_id,
                topic_index      => \%topic_index,
                full_collection  => $collection,
            };
        }
    );
}

# support some computed properties to avoid duplication and clutter
sub handle_computed_properties_for_section ($section) {
    for my $topic ($section->{topics}->@*) {
        $topic->{id} = get_topic_id($topic);
        if (defined($topic->{collate}) && $topic->{collate} eq '$filter') {
            $topic->{collate} = $topic->{id};
        }
        if (($topic->{thumbnail} // '$filter') eq '$filter') {

            # e.g., '@joseki/33/approach' becomes 'joseki-33-approach.png'
            $topic->{thumbnail} = "$topic->{id}.png";
        }
        if (defined $topic->{subsets}) {
            for my $subset ($topic->{subsets}->@*) {
                my $s = sprintf '%s %s %s %s',
                  map { $_ // 'undef' }
                  $subset->@{qw(with_ref without_ref with_tag without_tag)};
                $subset->{id} = utf8_sha1_hex($s);
            }
        }
    }
}

sub read_menu ($path) {
    -e $path or die "menu $path does not exist\n";
    -f $path or die "menu $path is not a file\n";
    my ($json, $data);
    eval { $json = slurp($path) };
    $@ && die "can't read menu $path: $@\n";
    eval { $data = json_decode($json) };
    $@ && die "can't decode JSON from menu $path\n";
    return $data;
}

# Generate an id that can be used for the collection filename, thumbnail
# filename and topic collation. Construct something that looks like a filter
# corresponding to the with/without spec.
sub get_topic_id ($topic) {
    my $id =
      join ' and ' => (defined $topic->{with_tag} ? ($topic->{with_tag}) : ()),
      (defined $topic->{without_tag} ? ('not', $topic->{without_tag}) : ()),
      (defined $topic->{with_ref}    ? ($topic->{with_ref})           : ()),
      (defined $topic->{without_ref} ? ('not', $topic->{without_ref}) : ()),
      (defined $topic->{filter}      ? ($topic->{filter})             : ());
    $id =~ s/[\#\@]//g;
    $id =~ s![ _/]!-!g;
    return $id;
}
1;
