package GoGameTools::Porcelain::SiteGenData;
use GoGameTools::features;
use GoGameTools::Util;
use GoGameTools::JSON;
use GoGameTools::Parser::FilterQuery;
use Path::Tiny;
use Digest::SHA qw(sha1_hex);
use utf8;
use GoGameTools::Class qw(new @menu);

sub run ($self) {
    return (
        sub ($collection) {

            # munge the SGJ objects so they look like eval_query() expects
            my (%problems_with_id, %topic_index);
            for my $sgj_obj ($collection->@*) {
                $sgj_obj->{id} =
                  utf8_sha1_hex(sprintf '%s %s', $sgj_obj->{metadata}->@{qw(filename index)});
                $sgj_obj->{topics} = [];
                $sgj_obj->{vars}   = query_vars_from_sgj($sgj_obj);
                push @{ $problems_with_id{ $sgj_obj->{id} } //= [] }, $sgj_obj;
            }

            # concatenate the lists from all menu locations
            my @sections = (
                get_basic_menu(), map { json_decode(path($_)->slurp_utf8)->@* } $self->menu->@*
            );

            # For each topic, find the problems matching the topic's filter
            # expression. Store them with the topic.
            #
            # @result_sections and @result_topics_for_section are intermediate variables so
            # we can only take those sections and topics that actually contain problems.
            my @result_sections;
            for my $section (@sections) {
                my @result_topics_for_section;
                for my $topic ($section->{topics}->@*) {
                    my $expr = parse_filter_query($topic->{filter})
                      // die "can't parse filter query $topic->{filter}\n";
                    $topic->{problems} =
                      [ grep { eval_query(expr => $expr, vars => $_->{vars}) } $collection->@* ];
                    next unless $topic->{problems}->@*;

                    # The filename that the topic's problem collection will be written to.
                    $topic->{filename} = $topic->{filter} =~ s/\W+/-/gr =~ s/^-|-$//gr;

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
                $sgj_obj->{related_positions} = scalar($problems_with_id{ $sgj_obj->{id} }->@*);

                # delete things that the site doesn't need
                delete $sgj_obj->{$_} for qw(game_info metadata vars);
            }

            # delete entries from the topic index that don't have problems
            my @empty_topic_index_keys;
            while (my ($k, $v) = each %topic_index) {
                push @empty_topic_index_keys, $k if $v->{count} == 0;
            }
            delete @topic_index{@empty_topic_index_keys};
            return +{
                menu        => \@result_sections,
                by_id       => \%problems_with_id,
                topic_index => \%topic_index,
            };
        }
    );
}

# sha1_hex() can't deal with Unicode, so this version converts it to bytes
sub utf8_sha1_hex ($data) {
    utf8::encode($data);
    return sha1_hex($data);
}

sub get_basic_menu {
    my @levels = (
        {   tag   => '#ddk3',
            group => '30k',
        },
        {   tag   => '#ddk2',
            group => '29k-20k',
        },
        {   tag   => '#ddk1',
            group => '19k-10k',
        },
        {   tag   => '#lowsdk',
            group => '9k-5k',
        },
        {   tag   => '#highsdk',
            group => '4k-1k',
        },
        {   tag   => '#lowdan',
            group => '1d-4d',
        },
        {   tag   => '#highdan',
            group => '5d-7d',
        },
    );
    my @menu = (
        {   text   => 'Techniques',
            topics => [
                {   filter => '#ate',
                    text   => 'Atari'
                },
                {   text   => 'Counter-atari',
                    filter => '#ategaeshi'
                },
                {   text   => 'Dent',
                    filter => '#hekomi'
                },
                {   text   => 'Wedge',
                    filter => '#wedge'
                },
                {   text   => 'Clamp',
                    filter => '#clamp'
                },
                {   filter => '#counterclamp',
                    text   => 'Counter-clamp'
                },
                {   text   => 'Hane and cut',
                    filter => '#hane_and_cut'
                },
                {   filter => '#hane_and_nakade',
                    text   => 'Hane and nakade',
                },
                {   filter => '#peep_and_cut',
                    text   => 'Peep and cut'
                },
                {   filter => '#push_and_cut',
                    text   => 'Push and cut'
                },
                {   filter => '#push_and_backtrack',
                    text   => 'Push and backtrack',
                },
                {   filter => '#jumping_over_wall',
                    text   => 'Jumping over the wall',
                },
                {   group  => 'Attach',
                    text   => 'and draw back',
                    filter => '#attach_and_draw_back'
                },
                {   group  => 'Attach',
                    text   => 'and extend',
                    filter => '#attach_and_extend'
                },
                {   text   => 'and crosscut',
                    filter => '#attach_and_crosscut',
                    group  => 'Attach'
                },
                {   group  => 'Attach',
                    filter => '#attach_and_block',
                    text   => 'and block'
                },
                {   text   => 'and bulge',
                    filter => '#attach_and_bulge',
                    group  => 'Attach'
                },
                {   filter => '#push_and_placement',
                    text   => 'Push and placement'
                },
                {   text   => 'Clamp against an attachment',
                    filter => '#clamp_against_attachment'
                },
                {   filter => '#elephant_eye',
                    text   => "Elephant's eye",
                },
                {   text   => 'Diagonal cover',
                    filter => '#diagonal_cover'
                },
                {   filter => '#knights_cover',
                    text   => "Knight's cover"
                },
                {   filter => '#large_knights_cover',
                    text   => "Large knight's cover"
                },
                {   filter => '#shoulder_hit',
                    text   => 'Shoulder hit'
                },
                {   text   => 'Shoulder cut',
                    filter => '#shoulder_cut'
                },
                {   filter => '#jump_attachment',
                    text   => 'Jump-attachment'
                },
                {   text   => 'Nose attachment',
                    filter => '#nose_attachment'
                },
                {   text   => 'Table attachment',
                    filter => '#table_attachment'
                },
                {   text   => 'Anti tower peep placement',
                    filter => '#anti_tower_peep_placement'
                },
                {   text   => 'Belly attachment',
                    filter => '#belly_attachment',
                },
                {   text   => 'Armpit',
                    filter => '#armpit'
                },
                {   filter => '#ankle_hook',
                    text   => 'Ankle hook'
                },
                {   filter => '#breaking_the_wing',
                    text   => 'Breaking the wing'
                },
                {   filter => '#cap',
                    text   => 'Cap'
                },
                {   text   => 'Caterpillar connection',
                    filter => '#caterpillar_connection'
                },
                {   filter => '#cave',
                    text   => 'Cave',
                },
                {   filter => '#cranes_nest',
                    text   => "Crane's nest",
                },
                {   text   => 'Driving',
                    filter => '#driving'
                },
                {   text   => 'Dog leg',
                    filter => '#dogleg'
                },
                {   text   => 'Crawling under the door',
                    filter => '#crawling_under_the_door'
                },
                {   text   => 'Double snapback',
                    filter => '#double_snapback'
                },
                {   text   => 'Edge wrap-around',
                    filter => '#edge_wrap_around',
                },
                {   text   => 'Eiffel tower',
                    filter => '#eiffel_tower',
                },
                {   filter => '#eternal_life',
                    text   => 'Eternal life'
                },
                {   filter => '#eye_in_the_stomach',
                    text   => 'Eye in the stomach'
                },
                {   filter => '#flower_six',
                    text   => 'Flower six',
                },
                {   filter => '#grappling_hook',
                    text   => 'Grappling hook'
                },
                {   filter => '#hane_at_the_head',
                    text   => 'Hane at the head'
                },
                {   text   => 'Ladder',
                    filter => '#ladder'
                },
                {   filter => '#spiral_ladder',
                    text   => 'Spiral ladder'
                },
                {   filter => '#double_ladder',
                    text   => 'Double ladder'
                },
                {   text   => 'Squeezing',
                    filter => '#squeezing'
                },
                {   text   => 'Loose ladder',
                    filter => '#loose_ladder'
                },
                {   filter => '#mouse_stealing_oil',
                    text   => 'Mouse stealing oil',
                },
                {   text   => 'Monkey jump',
                    filter => '#monkey_jump'
                },
                {   text   => 'Net',
                    filter => '#net'
                },
                {   filter => '#knights_net',
                    text   => "Knight's net"
                },
                {   filter => '#orikiri',
                    text   => 'Descending to the first line'
                },
                {   text   => 'Parallel bars',
                    filter => '#parallel_bars',
                },
                {   filter => '#rooster_on_one_leg',
                    text   => 'Rooster on one leg'
                },
                {   filter => '#sacrifice_two',
                    text   => 'Sacrifice two stones'
                },
                {   filter => '#shimetsuke',
                    text   => 'Tightening'
                },
                {   text   => 'Stick connection',
                    filter => '#stick_connection'
                },
                {   text   => 'Symmetry',
                    filter => '#symmetry'
                },
                {   filter => '#tanuki_belly',
                    text   => 'Tanuki drumming his belly',
                },
                {   filter => '#three_is_one',
                    text   => 'Three is one'
                },
                {   filter => '#two_stone_edge_squeeze',
                    text   => 'Two-stone edge squeeze'
                },
                {   filter => '#pushing_twice_then_keima',
                    text   => 'Pushing twice, then keima'
                },
                {   text   => 'then cut',
                    filter => '#cut_under_the_stones',
                    group  => 'Under the stones'
                },
                {   text   => 'then placement',
                    filter => '#placement_under_the_stones',
                    group  => 'Under the stones'
                },
                {   text   => 'Windmill',
                    filter => '#windmill'
                },
                {   text   => 'Ko lock',
                    filter => '#ko_lock'
                },
                {   text   => 'Connect and die',
                    filter => '#connect_and_die'
                },
                {   text   => 'Elbow lock',
                    filter => '#elbow_lock',
                },
                {   filter => '#carpenters_connection',
                    text   => "Carpenter's square connection"
                },
                {   filter => '#guzumi',
                    text   => 'Good empty triangle'
                },
                {   text   => 'Cork in the bottle',
                    filter => '#cork_in_the_bottle',
                },
                {   text   => 'Angle play',
                    filter => '#kado'
                },
                {   filter => '#crosscut',
                    text   => 'Crosscut'
                },
                {   filter => '#peep',
                    text   => 'Peep'
                },
                {   text   => 'Resisting a peep',
                    filter => '#resisting_peep'
                },
                {   filter => '#preventing_bamboo',
                    text   => 'Preventing the bamboo'
                },
                {   text   => 'Cut to defend against a cut',
                    filter => '#cut_to_defend_cut',
                },
                {   text   => "Extra-large knight's move",
                    filter => '#daidaigeima',
                },
                {   text   => '1-2-3 principle',
                    filter => '#123_principle'
                },
                {   text   => 'Pushing from behind',
                    filter => '#pushing_from_behind'
                },
                {   filter => '#second_line_kosumi',
                    text   => 'Diagonal move on the second line'
                },
                {   text   => 'Capturing two stones, recapturing one',
                    filter => '#two_recapture_one'
                },
                {   text   => 'Capturing two stones, getting two eyes',
                    filter => '#capturing_two_for_two_eyes'
                },
                {   text   => 'Wedge to separate',
                    filter => '#wedge_separate'
                },
                {   filter => '#invading_3_extension',
                    text   => 'Invading a three-space extension'
                },
                {   filter => '#trumpet_connection',
                    text   => 'Trumpet connection'
                },
                {   filter => '#unstable_connection',
                    text   => 'Unstable connections'
                },
                {   filter => '#cat_face',
                    text   => 'Cat face'
                },
                {   filter => '#dog_face',
                    text   => 'Dog face'
                },
                {   filter => '#horse_face',
                    text   => 'Horse face'
                },
                {   filter => '#dragon_face',
                    text   => 'Dragon face'
                },
                {   text   => 'Bad sente',
                    filter => '#bad_sente'
                }
            ]
        },
        {   text   => 'Opening',
            topics => [
                {   filter => '#making_a_position',
                    text   => 'Making a position'
                },
                {   text   => 'Extending',
                    filter => '#extending'
                },
                {   filter => '#drawing_near',
                    text   => 'Drawing near'
                },
                {   text   => 'Checking extension',
                    filter => '#checking_extension'
                },
                {   filter => '#enlarging',
                    text   => 'Enlarging'
                },
                {   text   => 'Making a triangular framework',
                    filter => '#making_a_triangular_framework'
                },
                {   text   => 'Preventing a triangular framework',
                    filter => '#preventing_a_triangular_framework'
                },
                {   text   => 'Making a rectangular framework',
                    filter => '#making_a_rectangular_framework'
                },
                {   text   => 'Enlarging while limiting',
                    filter => '#enlarging_while_limiting'
                },
                {   text   => 'Reducing from above',
                    filter => '#reducing_from_above'
                },
                {   filter => '#surrounding',
                    text   => 'Surrounding'
                },
                {   text   => 'Low chinese fuseki',
                    filter => '@fuseki/low-chinese'
                },
                {   filter => '@fuseki/high-chinese',
                    text   => 'High chinese fuseki'
                },
                {   filter => '@fuseki/mini-chinese',
                    text   => 'Mini chinese fuseki'
                },
                {   text   => 'Micro chinese fuseki',
                    filter => '@fuseki/micro-chinese'
                },
                {   filter => '#kobayashi_fuseki',
                    text   => '@fuseki/kobayashi'
                },
                {   text   => 'Facing 3-4 points',
                    filter => '@fuseki/facing-34'
                },
                {   filter => '@fuseki/opposing-34',
                    text   => 'Opposing 3-4 points'
                },
                {   filter => '@fuseki/nirensei',
                    text   => 'Nirensei'
                },
                {   text   => 'Sanrensei',
                    filter => '@fuseki/sanrensei'
                }
            ]
        },
        {   topics => [
                {   text   => 'Separating',
                    filter => '#separating'
                },
                {   filter => '#pressing_down',
                    text   => 'Pressing down'
                },
                {   filter => '#sealing_in',
                    text   => 'Sealing in'
                },
                {   text   => 'All',
                    filter => '#spoiling_shape',
                    group  => 'Spoiling shape'
                },
                {   filter => '#forcing_into_empty_triangle',
                    text   => 'Empty triangle',
                    group  => 'Spoiling shape',
                },
                {   text   => 'Dumpling',
                    filter => '#forcing_into_dumpling',
                    group  => 'Spoiling shape'
                },
                {   text   => 'Probing',
                    filter => '#probing'
                },
                {   filter => '#making_heavy',
                    text   => 'Making heavy'
                },
                {   filter => '#overconcentrating',
                    text   => 'Overconcentrating'
                },
                {   text   => 'Creating weaknesses',
                    filter => '#creating_weaknesses'
                },
                {   text   => 'Making double threats',
                    filter => '#making_double_threats'
                },
                {   text   => 'Taking away the base',
                    filter => '#taking_away_base'
                },
                {   filter => '#capturing',
                    text   => 'Capturing'
                },
                {   text   => 'Making territory',
                    filter => '#making_territory'
                },
                {   filter => '#intimidating_with_ko',
                    text   => 'Intimidating with ko'
                },
                {   text   => 'Making a fist',
                    filter => '#making_fist'
                },
                {   filter => '#invading',
                    text   => 'Invading'
                },
                {   text   => 'Kikashi',
                    filter => '#kikashi'
                },
                {   text   => 'Bullying',
                    filter => '#bullying'
                },
                {   filter => '#capping',
                    text   => 'Capping'
                },
                {   text   => 'Leaning attack',
                    filter => '#leaning_attack'
                },
                {   filter => '#splitting_attack',
                    text   => 'Splitting attack'
                }
            ],
            text => 'Attacking'
        },
        {   topics => [
                {   text   => 'Connecting',
                    filter => '#connecting'
                },
                {   filter => '#capturing_key_stones',
                    text   => 'Capturing key stones'
                },
                {   text   => 'Developing',
                    filter => '#developing'
                },
                {   text   => 'Escaping',
                    filter => '#escaping'
                },
                {   text   => 'Making shape',
                    filter => '#making_shape'
                },
                {   filter => '#taking_sente',
                    text   => 'Taking sente'
                },
                {   text   => 'Handling weak stones',
                    filter => '#sabaki'
                },
                {   filter => '#striking_back',
                    text   => 'Striking back'
                },
                {   text   => 'Defending against multiple threats',
                    filter => '#defending_against_multiple_threats'
                },
                {   text   => 'Solidifying the base',
                    filter => '#solidifying_base'
                },
                {   filter => '#defending_base',
                    text   => 'Defending the base'
                },
                {   filter => '#linking_up',
                    text   => 'Linking up'
                },
                {   text   => 'Resisting with ko',
                    filter => '#resisting_with_ko'
                },
                {   text   => 'Forcing before defending',
                    filter => '#forcing_before_defending'
                },
                {   filter => '#refuting_overplay',
                    text   => 'Refuting an overplay'
                },
                {   text   => 'Trick play',
                    filter => '#trick_play'
                },
                {   text   => 'Denying kikashi',
                    filter => '#deny_kikashi'
                }
            ],
            text => 'Defending'
        },
        {   topics => [
                {   filter => '#sacrificing_junk_stones',
                    text   => 'Sacrificing junk stones'
                },
                {   filter => '#chasing_junk_stones',
                    text   => 'Chasing junk stones'
                },
                {   filter => '#walking_ahead',
                    text   => 'Walking ahead'
                },
                {   text   => 'Pushing from weakness',
                    filter => '#pushing_from_weak_area'
                },
                {   text   => 'Choice of joseki',
                    filter => '#joseki_choice'
                },
                {   text   => 'Direction of attack',
                    filter => '#direction_of_attack'
                },
                {   text   => 'Value of sides',
                    filter => '#value_of_sides'
                },
                {   filter => '#playing_away_from_thickness',
                    text   => 'Playing away from thickness'
                },
                {   filter => '#avoiding_being_enclosed',
                    text   => 'Avoiding being enclosed'
                },
                {   filter => '#leaving_aji',
                    text   => 'Leaving aji'
                },
                {   filter => '#good_ugly_keima_cut',
                    text   => 'Good ugly keima cut'
                },
                {   filter => '#tenuki',
                    text   => 'Tenuki'
                },
                {   filter => '#running_battle',
                    text   => 'Running battle'
                },
                {   text   => 'Commanding high point',
                    filter => '#tennouzan'
                },
                {   text   => 'Four cut groups',
                    filter => '#crossfight'
                }
            ],
            text => 'Strategy'
        },
        {   topics => [
                {   filter => '#solidifying_base and #taking_away_base',
                    text   => 'Base of both sides'
                },
                {   filter => '#handling_invasion',
                    text   => 'Handling an invasion'
                }
            ],
            text => 'Multiple objectives'
        },
        {   topics => [
                {   text   => 'Breaking in',
                    filter => '#breaking_in'
                },
                {   text   => 'Encroaching on territory',
                    filter => '#encroaching'
                },
                {   filter => '#stopping_encroachments',
                    text   => 'Stopping encroachments'
                },
                {   text   => 'Large yose',
                    filter => '#large_yose'
                },
                {   text   => 'Threatening to kill',
                    filter => '#threatening_to_kill'
                },
                {   filter => '#forcing_removal',
                    text   => 'Forcing removal'
                },
                {   text   => 'Double endgame attacks',
                    filter => '#double_endgame_attacks'
                },
                {   filter => '#double_endgame_defenses',
                    text   => 'Double endgame defenses'
                },
                {   filter => '#closing_in_sente',
                    text   => 'Closing boundaries in sente'
                }
            ],
            text => 'Endgame'
        },
        {   text   => 'Life-and-death',
            topics => [
                {   group  => 'Real-game corners',
                    filter => '@tsumego/real/corner',
                    text   => 'All'
                },
                {   text   => 'Small pig snout',
                    filter => '@tsumego/real/corner/small-pig-snout',
                    group  => 'Real-game corners'
                },
                {   filter => '@tsumego/real/corner/big-pig-snout',
                    text   => 'Big pig snout',
                    group  => 'Real-game corners',
                },
                {   text   => 'Rectangular six in the corner',
                    filter => '@tsumego/real/corner/rectangular-six',
                    group  => 'Real-game corners'
                },
                {   filter => '@tsumego/real/corner/l-group',
                    text   => 'L-group',
                    group  => 'Real-game corners',
                },
                {   group  => 'Real-game corners',
                    filter => '@tsumego/real/corner/long-l-group',
                    text   => 'Long L-group'
                },
                {   filter => '@tsumego/real/corner/carpenters-square',
                    text   => "Carpenter's square",
                    group  => 'Real-game corners',
                },
                {   text   => 'All',
                    filter => '@tsumego/real/side',
                    group  => 'Real-game sides'
                },
                {   text   => 'Notcher',
                    filter => '@tsumego/real/side/notcher',
                    group  => 'Real-game sides'
                },
                {   group  => 'Real-game sides',
                    filter => '@tsumego/real/side/door',
                    text   => 'Door group'
                },
                {   group  => 'Real-game sides',
                    filter => '@tsumego/real/side/comb',
                    text   => 'Comb formation'
                },
                {   group  => 'Making one eye',
                    filter => '@tsumego/making-one-eye/second-line-shape',
                    text   => 'Second-line shapes'
                },
                {   group  => 'Making one eye',
                    filter => '@tsumego/making-one-eye/other',
                    text   => 'Other'
                },
                {   group  => 'Living',
                    text   => 'All',
                    filter => '#living'
                },
                {   text   => 'Securing eye shape',
                    filter => '#securing_eye_shape',
                    group  => 'Living'
                },
                {   filter => '#enlarging_eye_space',
                    text   => 'Enlarging eye space',
                    group  => 'Living',
                },
                {   group  => 'Living',
                    text   => 'by capturing',
                    filter => '#living_by_capturing'
                },
                {   group  => 'Living',
                    filter => '#living_with_false_eyes',
                    text   => 'with false eyes'
                },
                {   group  => 'Living',
                    filter => '#living_with_seki',
                    text   => 'Seki'
                },
                {   group  => 'Living',
                    filter => '#squashing',
                    text   => 'Squashing'
                },
                {   group  => 'Living',
                    text   => 'Ko',
                    filter => '#living_with_ko'
                },
                {   group  => 'Living',
                    text   => 'Double ko',
                    filter => '#living_with_double_ko'
                },
                {   group  => 'Killing',
                    filter => '#killing',
                    text   => 'All'
                },
                {   filter => '#nakade',
                    text   => 'Nakade',
                    group  => 'Killing',
                },
                {   text   => 'Bent four',
                    filter => '#bent_four_in_the_corner',
                    group  => 'Killing'
                },
                {   group  => 'Killing',
                    filter => '#making_a_false_eye',
                    text   => 'Making a false eye'
                },
                {   filter => '#killing_with_ko',
                    text   => 'Ko',
                    group  => 'Killing',
                },
                {   group  => 'Killing',
                    filter => '#killing_with_double_ko',
                    text   => 'Double ko'
                },
                {   filter => '#ten_thousand_year_ko',
                    text   => '10,000 year ko',
                    group  => 'Killing',
                }
            ]
        },
        {   text   => 'Capturing race',
            topics => [
                {   filter => '#capturing_race',
                    text   => 'All'
                },
                {   text   => 'Extending liberties',
                    filter => '#extending_liberties'
                },
                {   text   => 'Reducing liberties',
                    filter => '#reducing_liberties'
                },
                {   text   => 'Ko',
                    filter => '#capturing_race_ko'
                },
                {   text   => 'Seki',
                    filter => '#capturing_race_seki'
                },
                {   filter => '#one_eye_no_eye',
                    text   => 'Eye vs. no eye'
                },
                {   text   => 'Destroying one eye',
                    filter => '#destroying_one_eye'
                }
            ]
        },
        {   topics => [
                {   filter => '@joseki/33/44',
                    text   => '4-4 cover',
                    group  => '3-3',
                },
                {   text   => 'side approach',
                    filter => '@joseki/33/approach',
                    group  => '3-3'
                },
                {   text   => "knight's approach, Shusaku's kosumi, three-space low extension",
                    filter => '@joseki/34/1lap/diag/3lxt',
                    group  => '3-4'
                },
                {   group  => '3-4',
                    filter => '@joseki/34/1lap/1kxt and not @1kxt/attach-inside-to-corner',
                    text   => "knight's approach, knight's defense, not 3-3"
                },
                {   group  => '3-4',
                    filter => '@joseki/34/1lap/1kxt/attach-inside-to-corner',
                    text   => "knight's approach, knight's defense, 3-3"
                },
                {   filter => '@joseki/34/1lap/1hp',
                    text   => "knight's approach, one-space high pincer",
                    group  => '3-4',
                },
                {   group  => '3-4',
                    text   => "knight's approach, one-space low pincer",
                    filter => '@joseki/34/1lap/1lp'
                },
                {   group  => '3-4',
                    text   => "knight's approach, two-space high pincer",
                    filter => '@joseki/34/1lap/2hp'
                },
                {   text   => "knight's approach, tenuki, three-space low approach",
                    filter => '@joseki/34/1lap/tenuki/3lap',
                    group  => '3-4'
                },
                {   text   => 'one-space approach, one-space high pincer',
                    filter => '@joseki/34/1hap/1hp',
                    group  => '3-4'
                },
                {   text   => 'one-space approach, one-space low pincer, 3-3, wedge',
                    filter => '@joseki/34/1hap/1lp/attach-inside-to-corner/wedge',
                    group  => '3-4'
                },
                {   group  => '3-4',
                    filter => '@joseki/34/1hap/1lp/attach-inside-to-corner/hane',
                    text   => 'one-space approach, one-space low pincer, 3-3, hane'
                },
                {   filter => '@joseki/34/1hap/1lp/attach-inside-to-corner/2lxt',
                    text   => 'one-space approach, one-space low pincer, 3-3, two-space extension',
                    group  => '3-4',
                },
                {   text   => 'one-space approach, one-space low pincer, kosumi',
                    filter => '@joseki/34/1hap/1lp/diag-to-pincer',
                    group  => '3-4'
                },
                {   group  => '3-4',
                    filter => '@joseki/34/1hap/1lp/jump-descent',
                    text   => 'one-space approach, one-space low pincer, jump descent'
                },
                {   text   => "one-space approach, one-space low pincer, knight's cover",
                    filter => '@joseki/34/1hap/1lp/knight-to-corner',
                    group  => '3-4'
                },
                {   filter => '@joseki/34/1hap/1lxt',
                    text   => 'one-space approach, one-space extension',
                    group  => '3-4',
                },
                {   group  => '3-4',
                    filter => '@joseki/34/1hap/2hp',
                    text   => 'one-space approach, one-space high pincer'
                },
                {   group  => '3-4',
                    filter => '@joseki/34/1hap/attach-inside/hane',
                    text   => 'one-space approach, inside attachment, hane'
                },
                {   group  => '3-4',
                    filter => '@joseki/34/1hap/attach-inside/avalanche/small',
                    text   => 'small avalanche'
                },
                {   filter => '@joseki/34/1hap/attach-inside/avalanche/large',
                    text   => 'large avalanche',
                    group  => '3-4',
                },
                {   filter => '@joseki/34/2lap/1hs',
                    text   => "large knight's approach, high shimari",
                    group  => '3-4',
                },
                {   group  => '3-4',
                    filter => '@joseki/34/2lap/1lp',
                    text   => "large knight's approach, one-space low pincer"
                },
                {   text   => 'two-space approach, tenuki, 3-3',
                    filter => '@joseki/34/2hap/tenuki/attach-inside-to-corner',
                    group  => '3-4'
                },
                {   group  => '4-4',
                    filter => '@joseki/44/1lap/1lp',
                    text   => "knight's approach, one-space low pincer"
                },
                {   text   => '3-3 invasion',
                    filter => '@joseki/44/33',
                    group  => '4-4'
                },
                {   group  => '4-4',
                    text   => "knight's approach, knight's extension",
                    filter => '@joseki/44/1lap/1hxt'
                },
                {   group  => '4-4',
                    filter => '@joseki/44/1lap/1lxt',
                    text   => "knight's approach, one-space extension"
                },
                {   text   => "knight's approach, two-space high pincer",
                    filter => '@joseki/44/1lap/2hp',
                    group  => '4-4'
                },
                {   group => '4-4',
                    text  => "double knight's approach",
                    filter =>
                      '@joseki/44/1lap/tenuki/1lap or @joseki/44/1lap/1lp/1lap or @joseki/44/1lap/2hp/1lap'
                },
                {   text   => "knight's approach, attach-extend",
                    filter => '@joseki/44/1lap/attach-extend',
                    group  => '4-4'
                },
                {   group  => '4-4',
                    text   => "knight's approach, Takemiya kosumi",
                    filter => '@joseki/44/1lap/diag'
                },
                {   filter => '@joseki/54/34/attach-inside-to-corner',
                    text   => '3-4, 3-3 attachment',
                    group  => '5-4',
                },
                {   group  => '3-5',
                    text   => "3-4, knight's cover",
                    filter => '@joseki/53/34/knights-cover'
                },
                {   group  => '3-5',
                    text   => "3-4, large knight's cover",
                    filter => '@joseki/53/34/large-knights-cover'
                }
            ],
            text => 'Joseki'
        },
        {   topics => [
                {   text   => 'one-space shimari',
                    filter => '@enclosure/34/1hs',
                    group  => '3-4'
                },
                {   group  => '3-4',
                    filter => '@enclosure/34/2ls',
                    text   => "large knight's shimari"
                },
                {   group  => '4-4',
                    text   => "knight's shimari",
                    filter => '@enclosure/44/1ls'
                },
                {   filter => '@enclosure/44/1ls/6lxt',
                    text   => "knight's shimari plus six-space low extension",
                    group  => '4-4',
                },
                {   filter => '@enclosure/44/2ls',
                    text   => "large knight's shimari",
                    group  => '4-4',
                },
                {   group  => '4-4',
                    filter => '@enclosure/44/5hxt',
                    text   => 'five-space high wing'
                },
                {   group  => '4-4',
                    text   => 'five-space low wing',
                    filter => '@enclosure/44/5lxt'
                }
            ],
            text => 'Enclosures'
        },
        {   topics => [
                {   text   => 'Living',
                    filter => '@gokyo-shumyo/live',
                    group  => 'Gokyo Shumyo'
                },
                {   group  => 'Gokyo Shumyo',
                    text   => 'Killing',
                    filter => '@gokyo-shumyo/kill'
                },
                {   group  => 'Gokyo Shumyo',
                    text   => 'Ko',
                    filter => '@gokyo-shumyo/ko'
                },
                {   text   => 'Capturing race',
                    filter => '@gokyo-shumyo/semeai',
                    group  => 'Gokyo Shumyo'
                },
                {   text   => 'Connect and die',
                    filter => '@gokyo-shumyo/oiotoshi',
                    group  => 'Gokyo Shumyo'
                },
                {   group  => 'Gokyo Shumyo',
                    text   => 'Connecting',
                    filter => '@gokyo-shumyo/watari'
                },
                {   group  => 'Gokyo Shumyo',
                    filter => '@gokyo-shumyo/warikomi-nado',
                    text   => 'Wedge and others'
                },
                {   filter => '@gokyo-shumyo/tsuduki',
                    text   => "ツヅキ",
                    group  => 'Gokyo Shumyo',
                },
                {   group  => 'Gokyo Shumyo',
                    filter => '@gokyo-shumyo/kiri',
                    text   => 'Cut'
                },
                {   text   => 'Ladder',
                    filter => '@gokyo-shumyo/shichou',
                    group  => 'Gokyo Shumyo'
                },
                {   group  => 'Gokyo Shumyo',
                    filter => '@gokyo-shumyo/ and #separating',
                    text   => 'Refuting connection mistakes'
                },
                {   filter => '@gengen-gokyo',
                    text   => 'Gengen Gokyo'
                },
                {   filter => '@shikatsu-myoki',
                    text   => 'Shikatsu Myoki'
                },
                {   filter => '@kanzufu',
                    text   => 'Kanzufu'
                },
                {   text   => 'Igo Hatsuyoron',
                    filter => '@igo_hatsuyoron'
                },
                {   text   => 'Gokyo Seimyo',
                    filter => '@gokyo-seimyo'
                },
                {   text   => 'Genran',
                    filter => '@genran'
                }
            ],
            text => 'Classic books'
        },
        {   topics => [
                {   filter => '#question',
                    text   => 'Question-and-answer'
                },
                {   filter => '#show_choices',
                    text   => 'Select one of multiple choices'
                },
                {   filter => '#rate_choices',
                    text   => 'Rate multiple choices'
                },
                {   filter => '#status',
                    text   => 'Life-and-death status'
                },
                {   text   => 'Sujiba theory',
                    filter => '#sujiba'
                },
                {   text   => 'Count the score',
                    filter => '#counting_score'
                },
                {   text   => "Calculate a move's value",
                    filter => '#calculating_move_value'
                }
            ],
            text => 'Tasks'
        },
        {   topics => [
                map {
                    (   {   group  => $_->{group},
                            filter => $_->{tag},
                            text   => 'All',
                        },
                        {   group  => $_->{group},
                            filter => $_->{tag} . ' and #opening',
                            text   => 'Opening',
                        },
                        {   group  => $_->{group},
                            filter => $_->{tag} . ' and #attacking',
                            text   => 'Attacking',
                        },
                        {   group  => $_->{group},
                            filter => $_->{tag} . ' and #defending',
                            text   => 'Defending',
                        },
                        {   group  => $_->{group},
                            filter => $_->{tag} . ' and (#living or #killing)',
                            text   => 'Life-and-death',
                        },
                        {   group  => $_->{group},
                            filter => $_->{tag} . ' and #endgame',
                            text   => 'Endgame',
                        },
                        {   group  => $_->{group},
                            filter => $_->{tag} . ' and @joseki',
                            text   => 'Joseki',
                        },
                        {   group  => $_->{group},
                            filter => $_->{tag} . ' and #capturing_race',
                            text   => 'Capturing race',
                        },
                    )
                } @levels
            ],
            text => 'By Level'
        },
        {   text   => 'Games',
            topics => [
                {   text   => 'Professional games',
                    filter => '#progame'
                },
                {   text   => 'Any real game',
                    filter => '#game'
                }
            ]
        },
        {   text   => 'Books',
            topics => [
                {   filter => '@p/y18',
                    text   => 'Rescue and Capture',
                },
                {   filter => '@p/k56',
                    group  => 'Get Strong at Tesuji',
                    text   => 'All'
                },
                {   filter => '@p/tesuji-daijiten',
                    group  => '手筋大事典',
                    text   => 'All'
                },
                {   filter => '@p/cho-chikun-encyclopedia-of-life-and-death/1',
                    group  => "Cho Chikun's Encyclopedia of Life and Death",
                    text   => 'Elementary'
                },
                {   filter => '@p/cho-chikun-encyclopedia-of-life-and-death/2',
                    group  => "Cho Chikun's Encyclopedia of Life and Death",
                    text   => 'Intermediate'
                },
                {   filter => '@p/cho-chikun-encyclopedia-of-life-and-death/3',
                    group  => "Cho Chikun's Encyclopedia of Life and Death",
                    text   => 'Advanced'
                },
                {   filter => '@p/cho-chikun-encyclopedia-of-life-and-death/0',
                    group  => "Cho Chikun's Encyclopedia of Life and Death",
                    text   => 'Other'
                },
                {   filter => '@p/itte-de-kimaru-tesuji/01-sacrifice-two',
                    group  => '一手できまる手筋',
                    text   => '二目にして捨てる'
                },
                {   filter => '@p/itte-de-kimaru-tesuji/02-kado',
                    group  => '一手できまる手筋',
                    text   => '敵石のカドを攻める筋'
                },
                {   filter => '@p/itte-de-kimaru-tesuji/03-hasamitsuke-warikomi',
                    group  => '一手できまる手筋',
                    text   => 'ハサミツケとワリ込みの筋'
                },
                {   filter => '@p/itte-de-kimaru-tesuji/04-tsukekoshi',
                    group  => '一手できまる手筋',
                    text   => 'ツケコシの筋'
                },
                {   filter => '@p/itte-de-kimaru-tesuji/05-shibori',
                    group  => '一手できまる手筋',
                    text   => 'シボリの作戦'
                },
                {   filter => '@p/li-chang-ho-jingjiang-weiqi-shoujin/1',
                    group  => '李昌镐精讲围棋手筋',
                    text   => 'Volume 1'
                },
                {   filter => '@p/li-chang-ho-jingjiang-weiqi-shoujin/2',
                    group  => '李昌镐精讲围棋手筋',
                    text   => 'Volume 2'
                },
                {   filter => '@p/li-chang-ho-jingjiang-weiqi-shoujin/3',
                    group  => '李昌镐精讲围棋手筋',
                    text   => 'Volume 3'
                },
                {   filter => '@p/li-chang-ho-jingjiang-weiqi-shoujin/4',
                    group  => '李昌镐精讲围棋手筋',
                    text   => 'Volume 4'
                },
                {   filter => '@p/li-chang-ho-jingjiang-weiqi-shoujin/5',
                    group  => '李昌镐精讲围棋手筋',
                    text   => 'Volume 5'
                },
                {   filter => '@p/li-chang-ho-jingjiang-weiqi-shoujin/6',
                    group  => '李昌镐精讲围棋手筋',
                    text   => 'Volume 6'
                },
                {   filter => '@p/li-chang-ho-jingjiang-weiqi-sihuo/1',
                    group  => '李昌镐精讲围棋死活',
                    text   => 'Volume 1'
                },
                {   filter => '@p/li-chang-ho-jingjiang-weiqi-sihuo/2',
                    group  => '李昌镐精讲围棋死活',
                    text   => 'Volume 2'
                },
                {   filter => '@p/li-chang-ho-jingjiang-weiqi-sihuo/3',
                    group  => '李昌镐精讲围棋死活',
                    text   => 'Volume 3'
                },
                {   filter => '@p/li-chang-ho-jingjiang-weiqi-sihuo/4',
                    group  => '李昌镐精讲围棋死活',
                    text   => 'Volume 4'
                },
                {   filter => '@p/li-chang-ho-jingjiang-weiqi-sihuo/5',
                    group  => '李昌镐精讲围棋死活',
                    text   => 'Volume 5'
                },
                {   filter => '@p/li-chang-ho-jingjiang-weiqi-sihuo/6',
                    group  => '李昌镐精讲围棋死活',
                    text   => 'Volume 6'
                },
                {   filter => '@p/1-geup-eui-subeob',
                    group  => '1급의 수법',
                    text   => 'All'
                },
                {   filter => '@p/eorini-baduk-suryeonjang/2/poseok',
                    group  => '어린이 바둑 수련장',
                    text   => '2 - 포석'
                },
                {   filter => '@p/eorini-baduk-suryeonjang/2/sahwal',
                    group  => '어린이 바둑 수련장',
                    text   => '2 - 사활'
                },
                {   filter => '@p/eorini-baduk-suryeonjang/3/poseok',
                    group  => '어린이 바둑 수련장',
                    text   => '3 - 포석'
                },
                {   filter => '@p/eorini-baduk-suryeonjang/3/sahwal',
                    group  => '어린이 바둑 수련장',
                    text   => '3 - 사활'
                },
                {   filter => '@p/eorini-baduk-suryeonjang/4/poseok',
                    group  => '어린이 바둑 수련장',
                    text   => '4 - 포석'
                },
                {   filter => '@p/go-seigen-tsumego',
                    group  => 'Go Seigen Tsumego Collection',
                    text   => 'All'
                }
            ]
        }
    );
    return @menu;
}
1;
