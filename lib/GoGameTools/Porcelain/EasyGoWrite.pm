package GoGameTools::Porcelain::EasyGoWrite;
use GoGameTools::features;
use GoGameTools::Util;
use GoGameTools::JSON;
use GoGameTools::Porcelain::Subsets;
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);
use utf8;
use GoGameTools::Class qw($zip);

sub run ($self) {
    return (
        sub ($site_data) {
            my $zip = Archive::Zip->new;
            $Archive::Zip::UNICODE = 1;
            for my $section ($site_data->{menu}->@*) {
                for my $topic ($section->{topics}->@*) {
                    $topic->{problems} //= [];
                    next unless $topic->{problems}->@*;

                    # If there are subsets then only write the subsets, not the
                    # whole topic's problems. This assumes that there is an
                    # 'All' quasi-subset that contains the whole collection
                    # (presumably the first subset). Each subset gets its own
                    # subdirectory.
                    if (defined $topic->{subsets}) {
                        for my $subset ($topic->{subsets}->@*) {
                            my $subset_problems = get_problems_for_subset($subset, $topic->{problems});

                            # GoGameTools::Porcelain::SiteGenData already wrote
                            # the expected number of problems. Use it to check
                            # here.
                            if ($subset->{count} != $subset_problems->@*) {
                                die sprintf "expected %d problems but got %d. Aborting\n", $subset->{count},
                                  scalar($subset_problems->@*);
                            }
                            next unless $subset_problems->@*;
                            my $dir = sprintf '%s/%s/%s', $section->{text}, $topic->{text}, $subset->{text};
                            add_problems_for_dir($zip, $dir, $subset_problems);
                        }
                    } else {
                        my $dir = sprintf '%s/%s', $section->{text}, $topic->{text};
                        add_problems_for_dir($zip, $dir, $topic->{problems});
                    }
                }
            }
            unless ($zip->writeToFileNamed($self->zip) == AZ_OK) {
                die "zip write error\n";
            }
        },
    );
}

sub add_problems_for_dir ($zip, $dir, $problems) {
    while (my ($i, $sgj) = each $problems->@*) {
        utf8::encode $sgj->{sgf};
        my $string_member =
          $zip->addString($sgj->{sgf}, sprintf('%s/%04d.sgf', $dir, $i));
        $string_member->desiredCompressionMethod(COMPRESSION_DEFLATED);
    }
}
1;
