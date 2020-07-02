package GoGameTools::Porcelain::SiteGenData;
use GoGameTools::features;
use GoGameTools::Util;
use GoGameTools::JSON;
use GoGameTools::Parser::FilterQuery;
use Path::Tiny;
use Digest::SHA qw(sha1_hex);
use utf8;
use GoGameTools::Class qw($delete_metadata @menu);

sub run ($self) {
    return (
        sub ($collection) {

            # munge the SGJ objects so they look like eval_query() expects
            my (%problems_with_collection_id, %topic_index);
            for my $sgj_obj ($collection->@*) {
                $sgj_obj->{problem_id} = utf8_sha1_hex($sgj_obj->{sgf});
                $sgj_obj->{collection_id} =
                  utf8_sha1_hex(sprintf '%s %s', $sgj_obj->{metadata}->@{qw(filename index)});
                $sgj_obj->{topics} = [];
                $sgj_obj->{vars}   = query_vars_from_sgj($sgj_obj);
                push @{ $problems_with_collection_id{ $sgj_obj->{collection_id} } //= [] },
                  $sgj_obj;
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
                $sgj_obj->{related_positions} =
                  scalar($problems_with_collection_id{ $sgj_obj->{collection_id} }->@*);

                # delete things that the site doesn't need
                delete $sgj_obj->{$_} for qw(game_info vars);
                delete $sgj_obj->{metadata}{input_filename};
                delete $sgj_obj->{metadata} if $self->delete_metadata;
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

# sha1_hex() can't deal with Unicode, so this version converts it to bytes
sub utf8_sha1_hex ($data) {
    utf8::encode($data);
    return sha1_hex($data);
}

# For books and some other sources, we want a set of all problems and a set of
# problems without refutations, i.e., just the problems as they appear in the
# source. Even the 'no refutations' set could have more problems than appear in
# the source in case the opponent has several responses.
sub _all_and_some (%spec) {
    if (defined $spec{text}) {
        $spec{text} = ' - ' . $spec{text};
    } else {
        $spec{text} = '';
    }
    $spec{collate} //= '';
    return (
        {   %spec,
            filter  => "$spec{filter} and not #refute_bad_move",
            text    => 'Main' . $spec{text},
            collate => "0-$spec{collate}",
        },
        {   %spec,
            filter  => $spec{filter},
            text    => 'With refuting mistakes' . $spec{text},
            collate => "1-$spec{collate}",
        },
    );
}

sub get_basic_menu {
    my @levels = (
        {   tag           => '#ddk3',
            group         => '30k',
            group_collate => 'Level 0',
        },
        {   tag           => '#ddk2',
            group         => '29k-20k',
            group_collate => 'Level 1',
        },
        {   tag           => '#ddk1',
            group         => '19k-10k',
            group_collate => 'Level 2',
        },
        {   tag           => '#lowsdk',
            group         => '9k-5k',
            group_collate => 'Level 3',
        },
        {   tag           => '#highsdk',
            group         => '4k-1k',
            group_collate => 'Level 4',
        },
        {   tag           => '#lowdan',
            group         => '1d-4d',
            group_collate => 'Level 5',
        },
        {   tag           => '#highdan',
            group         => '5d-7d',
            group_collate => 'Level 6',
        },
    );
    my @menu = (
        {   text   => 'Books',
            topics => [

                # First, classic books. They don't have @p/ refs and so are
                # public.

                # Gokyo Shumyo
                {   text    => 'Living',
                    filter  => '@gokyo-shumyo/live',
                    collate => '00',
                    group   => 'Gokyo Shumyo'
                },
                {   group   => 'Gokyo Shumyo',
                    text    => 'Killing',
                    collate => '01',
                    filter  => '@gokyo-shumyo/kill'
                },
                {   group   => 'Gokyo Shumyo',
                    text    => 'Ko',
                    collate => '02',
                    filter  => '@gokyo-shumyo/ko'
                },
                {   text    => 'Capturing race',
                    filter  => '@gokyo-shumyo/semeai',
                    collate => '03',
                    group   => 'Gokyo Shumyo'
                },
                {   text    => 'Connect and die',
                    filter  => '@gokyo-shumyo/oiotoshi',
                    collate => '04',
                    group   => 'Gokyo Shumyo'
                },
                {   group   => 'Gokyo Shumyo',
                    text    => 'Connecting',
                    collate => '05',
                    filter  => '@gokyo-shumyo/watari'
                },
                {   group   => 'Gokyo Shumyo',
                    filter  => '@gokyo-shumyo/warikomi-nado',
                    collate => '06',
                    text    => 'Wedge and others'
                },
                {   filter  => '@gokyo-shumyo/tsuduki',
                    text    => "ツヅキ",
                    collate => '07',
                    group   => 'Gokyo Shumyo',
                },
                {   group   => 'Gokyo Shumyo',
                    filter  => '@gokyo-shumyo/kiri',
                    collate => '08',
                    text    => 'Cut'
                },
                {   text    => 'Ladder',
                    filter  => '@gokyo-shumyo/shichou',
                    collate => '09',
                    group   => 'Gokyo Shumyo'
                },
                {   group   => 'Gokyo Shumyo',
                    filter  => '@gokyo-shumyo/ and #separating',
                    collate => '10',
                    text    => 'Refuting connection mistakes'
                },

                # Kanzufu
                {   group   => 'Kanzufu',
                    filter  => '@kanzufu/attack-defense',
                    collate => '01',
                    text    => 'Attack and Defense'
                },
                {   group   => 'Kanzufu',
                    filter  => '@kanzufu/technique',
                    collate => '02',
                    text    => 'Technique'
                },
                {   group   => 'Kanzufu',
                    filter  => '@kanzufu/tesuji',
                    collate => '03',
                    text    => 'Tesuji'
                },
                {   group   => 'Kanzufu',
                    filter  => '@kanzufu/connection',
                    collate => '04',
                    text    => 'Connection'
                },
                {   group   => 'Kanzufu',
                    filter  => '@kanzufu/life-and-death',
                    collate => '05',
                    text    => 'Life-and-death'
                },
                {   group   => 'Kanzufu',
                    filter  => '@kanzufu/endgame',
                    collate => '06',
                    text    => 'Endgame'
                },

                # Other classic books
                {   filter => '@gengen-gokyo',
                    text   => 'Gengen Gokyo'
                },
                {   filter => '@shikatsu-myoki',
                    text   => 'Shikatsu Myoki'
                },
                {   text   => 'Igo Hatsuyoron',
                    filter => '@igo_hatsuyoron'
                },
                {   text   => 'Gokyo Seimyo',
                    filter => '@gokyo-seimyo'
                },
                {   text   => 'Genran',
                    filter => '@genran'
                },

                # Misc books
                _all_and_some(
                    filter => '@p/y18',
                    group  => 'Rescue and Capture',
                ),
                _all_and_some(
                    filter => '@p/k12',
                    group  => 'Tesuji (James Davies)',
                ),
                _all_and_some(
                    filter => '@p/k56',
                    group  => 'Get Strong at Tesuji',
                ),
                _all_and_some(
                    filter => '@p/tesuji-daijiten',
                    group  => '手筋大事典',
                ),
                _all_and_some(
                    filter => '@p/ishi-no-renraku-training-270/01-prologue',
                    group  => '石の連絡トレーニング２７０',
                    text   => 'プロローグ'
                ),
                _all_and_some(
                    filter => '@p/1-geup-eui-subeob',
                    group  => '1급의 수법',
                ),
                _all_and_some(
                    filter => '@p/hyeondae_jungban_sajeon/siljeon_gonggyeokui_maek',
                    group  => '현대 중반 사전',
                    text   => '2 - 실전 공격의 맥'
                ),
                _all_and_some(
                    filter => '@p/go-seigen-tsumego',
                    group  => '吳清源詰碁',
                ),
                _all_and_some(
                    filter => '@p/minna-no-tsumego',
                    group  => 'みんなの詰碁',
                ),

                # Dictionary of Basic Tesuji 1 - Attacking
                _all_and_some(
                    filter  => '@p/dictionary-of-basic-tesuji/1/separating',
                    group   => 'Dictionary of Basic Tesuji 1 - Attacking',
                    collate => '001',                                          # page number
                    text    => 'Separating'
                ),
                _all_and_some(
                    filter  => '@p/dictionary-of-basic-tesuji/1/probing',
                    group   => 'Dictionary of Basic Tesuji 1 - Attacking',
                    collate => '098',                                          # page number
                    text    => 'Probing'
                ),
                _all_and_some(
                    filter  => '@p/dictionary-of-basic-tesuji/1/making-double-threats',
                    group   => 'Dictionary of Basic Tesuji 1 - Attacking',
                    collate => '157',                                                  # page number
                    text    => 'Making Double Threats'
                ),
                _all_and_some(
                    filter  => '@p/dictionary-of-basic-tesuji/1/capturing',
                    group   => 'Dictionary of Basic Tesuji 1 - Attacking',
                    collate => '207',                                                  # page number
                    text    => 'Capturing'
                ),

                # Cho Chikun's Encyclopedia of Life and Death
                _all_and_some(
                    filter        => '@p/cho-chikun-encyclopedia-of-life-and-death/0',
                    group         => '趙治勲死活大百科０',
                    group_collate => 'p/cho-chikun-encyclopedia-of-life-and-death/0',
                ),
                _all_and_some(
                    filter        => '@p/cho-chikun-encyclopedia-of-life-and-death/1',
                    group         => '趙治勲死活大百科１',
                    group_collate => 'p/cho-chikun-encyclopedia-of-life-and-death/1',
                ),
                _all_and_some(
                    filter        => '@p/cho-chikun-encyclopedia-of-life-and-death/2',
                    group         => '趙治勲死活大百科２',
                    group_collate => 'p/cho-chikun-encyclopedia-of-life-and-death/2',
                ),
                _all_and_some(
                    filter        => '@p/cho-chikun-encyclopedia-of-life-and-death/3',
                    group         => '趙治勲死活大百科３',
                    group_collate => 'p/cho-chikun-encyclopedia-of-life-and-death/3',
                ),

                # Segoe Kensaku's 手筋事典
                _all_and_some(
                    filter  => '@p/segoe-kensaku-tesuji-jiten/rank/A',
                    group   => '手筋事典',
                    collate => '01',
                    text    => 'Rank A'
                ),
                _all_and_some(
                    filter  => '@p/segoe-kensaku-tesuji-jiten/rank/B',
                    group   => '手筋事典',
                    collate => '02',
                    text    => 'Rank B'
                ),
                _all_and_some(
                    filter  => '@p/segoe-kensaku-tesuji-jiten/rank/C',
                    group   => '手筋事典',
                    collate => '03',
                    text    => 'Rank C'
                ),
                _all_and_some(
                    filter  => '@p/segoe-kensaku-tesuji-jiten/atekomi',
                    group   => '手筋事典',
                    collate => '10',
                    text    => 'アテコミ'
                ),

                # 一手できまる手
                _all_and_some(
                    filter  => '@p/itte-de-kimaru-tesuji/01-sacrifice-two',
                    group   => '一手できまる手筋',
                    collate => '01',
                    text    => '二目にして捨てる'
                ),
                _all_and_some(
                    filter  => '@p/itte-de-kimaru-tesuji/02-kado',
                    group   => '一手できまる手筋',
                    collate => '02',
                    text    => '敵石のカドを攻める筋'
                ),
                _all_and_some(
                    filter  => '@p/itte-de-kimaru-tesuji/03-hasamitsuke-warikomi',
                    group   => '一手できまる手筋',
                    collate => '03',
                    text    => 'ハサミツケとワリ込みの筋'
                ),
                _all_and_some(
                    filter  => '@p/itte-de-kimaru-tesuji/04-tsukekoshi',
                    group   => '一手できまる手筋',
                    collate => '04',
                    text    => 'ツケコシの筋'
                ),
                _all_and_some(
                    filter  => '@p/itte-de-kimaru-tesuji/05-shibori',
                    group   => '一手できまる手筋',
                    collate => '05',
                    text    => 'シボリの作戦'
                ),

                # 李昌镐精讲围棋手筋
                (   map {
                        _all_and_some(
                            filter => "\@p/li-chang-ho-jingjiang-weiqi-shoujin/$_",
                            group  => "李昌镐精讲围棋手筋 $_",
                        )
                    } 1 .. 6
                ),

                # 李昌镐精讲围棋死活
                (   map {
                        _all_and_some(
                            filter => "\@p/li-chang-ho-jingjiang-weiqi-sihuo/$_",
                            group  => "李昌镐精讲围棋死活 $_",
                        )
                    } 1 .. 6
                ),

                # Weiqi Life-and-Death 1000 Problems
                {   text    => 'All',
                    filter  => '@p/weiqi-life-death-1000',
                    collate => '0',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Life-and-death: Making eyes',
                    filter  => '@p/weiqi-life-death-1000/1/01',
                    collate => '1-01',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Life-and-death: Destroying eyes',
                    filter  => '@p/weiqi-life-death-1000/1/02',
                    collate => '1-02',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Life-and-death: Killing eyes',
                    filter  => '@p/weiqi-life-death-1000/1/03',
                    collate => '1-03',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Life-and-death: Capturing race',
                    filter  => '@p/weiqi-life-death-1000/1/04',
                    collate => '1-04',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Life-and-death: seki',
                    filter  => '@p/weiqi-life-death-1000/1/05',
                    collate => '1-05',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Life-and-death: Vital point',
                    filter  => '@p/weiqi-life-death-1000/1/06',
                    collate => '1-06',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Life-and-death: Go theory',
                    filter  => '@p/weiqi-life-death-1000/1/07',
                    collate => '1-07',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Life-and-death: Common corner positions',
                    filter  => '@p/weiqi-life-death-1000/1/08',
                    collate => '1-08',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Life-and-death: Making ko',
                    filter  => '@p/weiqi-life-death-1000/1/09',
                    collate => '1-09',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Life-and-death: Interesting, unusual problems',
                    filter  => '@p/weiqi-life-death-1000/1/10',
                    collate => '1-10',
                    group   => 'Weiqi Life-and-Death 1000',
                },

                {   text    => 'Technique: Ladder',
                    filter  => '@p/weiqi-life-death-1000/2/01',
                    collate => '2-01',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Technique: Cut',
                    filter  => '@p/weiqi-life-death-1000/2/02',
                    collate => '2-02',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Technique: Net',
                    filter  => '@p/weiqi-life-death-1000/2/03',
                    collate => '2-03',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Technique: Hane',
                    filter  => '@p/weiqi-life-death-1000/2/04',
                    collate => '2-04',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Technique: Wedge',
                    filter  => '@p/weiqi-life-death-1000/2/05',
                    collate => '2-05',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Technique: Diagonal',
                    filter  => '@p/weiqi-life-death-1000/2/06',
                    collate => '2-06',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Technique: Bridge under',
                    filter  => '@p/weiqi-life-death-1000/2/07',
                    collate => '2-07',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Technique: Jump',
                    filter  => '@p/weiqi-life-death-1000/2/08',
                    collate => '2-08',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Technique: Pincer and clamp',
                    filter  => '@p/weiqi-life-death-1000/2/09',
                    collate => '2-09',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Technique: Descent and stand',
                    filter  => '@p/weiqi-life-death-1000/2/10',
                    collate => '2-10',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Technique: Vital point',
                    filter  => '@p/weiqi-life-death-1000/2/11',
                    collate => '2-11',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Technique: Throw-in',
                    filter  => '@p/weiqi-life-death-1000/2/12',
                    collate => '2-12',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Technique: Two-stone edge squeeze',
                    filter  => '@p/weiqi-life-death-1000/2/13',
                    collate => '2-13',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Technique: Double shortage of liberties',
                    filter  => '@p/weiqi-life-death-1000/2/14',
                    collate => '2-14',
                    group   => 'Weiqi Life-and-Death 1000',
                },
                {   text    => 'Technique: Under the stones',
                    filter  => '@p/weiqi-life-death-1000/2/15',
                    collate => '2-15',
                    group   => 'Weiqi Life-and-Death 1000',
                },

                # 어린이 바둑 수련장
                _all_and_some(
                    filter  => '@p/eorini-baduk-suryeonjang/2/poseok',
                    group   => '어린이 바둑 수련장 2',
                    collate => 0,
                    text    => '포석'
                ),
                _all_and_some(
                    filter  => '@p/eorini-baduk-suryeonjang/2/sahwal',
                    group   => '어린이 바둑 수련장 2',
                    collate => 1,
                    text    => '사활'
                ),
                _all_and_some(
                    filter  => '@p/eorini-baduk-suryeonjang/3/poseok',
                    group   => '어린이 바둑 수련장 3',
                    collate => 0,
                    text    => '포석'
                ),
                _all_and_some(
                    filter  => '@p/eorini-baduk-suryeonjang/3/sahwal',
                    group   => '어린이 바둑 수련장 3',
                    collate => 1,
                    text    => '사활'
                ),
                _all_and_some(
                    filter  => '@p/eorini-baduk-suryeonjang/4/poseok',
                    group   => '어린이 바둑 수련장 4',
                    collate => 0,
                    text    => '포석'
                ),
            ]
        },
        {   text   => 'Techniques',
            topics => [
                {   text   => 'Double atari',
                    filter => '#double_atari'
                },
                {   text   => 'Counter-atari',
                    filter => '#counteratari'
                },
                {   text   => 'Lining up',
                    filter => '#narabi'
                },
                {   text   => 'Dent',
                    filter => '#dent'
                },
                {   text   => 'Wedge',
                    filter => '#wedge'
                },
                {   text   => 'Bend-wedge',
                    filter => '#bend_wedge'
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
                {   text   => 'and hane',
                    filter => '#attach_and_hane',
                    group  => 'Attach'
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
                {   text   => 'All',
                    group  => 'Snapback',
                    filter => '#snapback'
                },
                {   text   => 'Double snapback',
                    group  => 'Snapback',
                    filter => '#double_snapback'
                },
                {   text   => 'Double hane edge squeeze',
                    filter => '#double_hane_edge_squeeze',
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
                {   filter => '#first_line_descent',
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
                {   text   => "Double knight's connection",
                    filter => '#double_knights_connection'
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
                {   filter => '#tombstone',
                    text   => 'Tombstone'
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
                    group  => 'Face',
                    text   => "Cat's face"
                },
                {   filter => '#dog_face',
                    group  => 'Face',
                    text   => "Dog's face"
                },
                {   filter => '#breaking_dog_face',
                    group  => 'Face',
                    text   => "Breaking the dog's face"
                },
                {   filter => '#horse_face',
                    group  => 'Face',
                    text   => "Horse's face"
                },
                {   filter => '#giraffe_face',
                    group  => 'Face',
                    text   => "Giraffe's face"
                },
                {   filter => '#bumping',
                    text   => 'Bumping'
                },
                {   filter => '#flying_double_clamp',
                    text   => 'Flying double clamp'
                },
                {   filter => '#throwing_in',
                    text   => 'Throwing in'
                },
                {   filter => '#crossing_the_lair',
                    text   => 'Crossing the Lair'
                },
                {   filter => '#pinch',
                    text   => 'Pinch'
                },
                {   filter => '#braid',
                    text   => 'Braid'
                },
                {   filter => '#first_line_empty_triangle',
                    text   => 'Empty triangle on the first line'
                },
                {   filter => '#across_attach',
                    text   => 'Across attach',
                },
                {   filter => '#rhombus_attach',
                    text   => 'Rhombus attach',
                },
                {   filter => '#diagonal_attachment',
                    text   => 'Diagonal attachment',
                },
                {   filter => '#tigers_mouth',
                    text   => "Tiger's mouth",
                },
                {   filter => '#nobikiri',
                    text   => 'Stretching in',
                },
                {   filter => '#bad_sente',
                    text   => 'Bad sente',
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
                {   filter => '#forcing_into_empty_triangle and not #forcing_into_farmers_hat',
                    text   => 'Empty triangle',
                    group  => 'Spoiling shape',
                },
                {   filter => '#forcing_into_farmers_hat',
                    text   => "Farmer's hat",
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
                {   text   => 'All',
                    filter => '#creating_weaknesses',
                    group  => 'Creating weaknesses',
                },
                {   text   => 'Cuts',
                    filter => '#creating_cuts',
                    group  => 'Creating weaknesses',
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
                {   text   => 'Indirect defense',
                    filter => '#indirect_defense'
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
                },
                {   filter => '#speculative_invasion',
                    text   => 'Speculative invasion'
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
                {   text   => 'Notchers, all',
                    filter => '@tsumego/real/side/notcher',
                    group  => 'Real-game sides'
                },
                {   text   => 'Notchers, status',
                    filter => '@tsumego/real/side/notcher and #status',
                    group  => 'Real-game sides'
                },
                {   text    => 'Notchers, one-space',
                    collate => 'Notchers, 1-space',
                    filter  => '@notcher/length/1',
                    group   => 'Real-game sides'
                },
                {   text    => 'Notchers, two-space',
                    collate => 'Notchers, 2-space',
                    filter  => '@notcher/length/2',
                    group   => 'Real-game sides'
                },
                {   text    => 'Notchers, three-space',
                    collate => 'Notchers, 3-space',
                    filter  => '@notcher/length/3',
                    group   => 'Real-game sides'
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
                    text   => 'Capturing race: All'
                },
                {   text   => 'Capturing race: Extending liberties',
                    filter => '#extending_liberties'
                },
                {   text   => 'Capturing race: Reducing liberties',
                    filter => '#reducing_liberties'
                },
                {   text   => 'Capturing race: Ko',
                    filter => '#capturing_race_ko'
                },
                {   text   => 'Capturing race: Seki',
                    filter => '#capturing_race_seki'
                },
                {   filter => '#one_eye_no_eye',
                    text   => 'Capturing race: Eye vs. no eye'
                },
                {   text   => 'Capturing race: Destroying one eye',
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
                {   group  => '4-4',
                    filter => '@joseki/44/1lap/1hp',
                    text   => "knight's approach, one-space high pincer"
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
                {   filter => '#question',
                    text   => 'Question-and-answer'
                },
                {   filter => '#show_choices',
                    text   => 'Show choices for the next move'
                },
                {   filter => '#rate_choices',
                    text   => 'Rate multiple choices'
                },
                {   filter => '#multiple_choice',
                    text   => 'Choose one of several moves'
                },
                {   filter => '#copy and @joseki',
                    group  => 'Copy shapes',
                    text   => 'Joseki',
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
                },
                {   text   => 'Debug',
                    filter => '#debug'
                }
            ],
            text => 'Tasks'
        },
        {   topics => [
                map {
                    (   {   %$_,
                            collate => 0,
                            filter  => $_->{tag},
                            text    => 'All',
                        },
                        {   %$_,
                            collate => 1,
                            filter  => $_->{tag} . ' and #opening',
                            text    => 'Opening',
                        },
                        {   %$_,
                            collate => 2,
                            filter  => $_->{tag} . ' and #attacking',
                            text    => 'Attacking',
                        },
                        {   %$_,
                            collate => 3,
                            filter  => $_->{tag} . ' and #defending',
                            text    => 'Defending',
                        },
                        {   %$_,
                            collate => 4,
                            filter  => $_->{tag} . ' and (#living or #killing)',
                            text    => 'Life-and-death',
                        },
                        {   %$_,
                            collate => 5,
                            filter  => $_->{tag} . ' and #endgame',
                            text    => 'Endgame',
                        },
                        {   %$_,
                            collate => 6,
                            filter  => $_->{tag} . ' and @joseki',
                            text    => 'Joseki',
                        },
                        {   %$_,
                            collate => 7,
                            filter  => $_->{tag} . ' and #capturing_race',
                            text    => 'Capturing race',
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
        {   text   => 'Yunguseng Dojang',
            topics => [
                {   text =>
                      "S09 lecture 1: Across attach; Break the dog's face; Indirect defense (Local Technique)",
                    rel_text => 'S09 lecture 1',
                    filter   => '@yunguseng-dojang/lectures/09/1'
                },
                {   text   => 'S26 lecture 1: Pinch (Local Technique)',
                    filter => '@yunguseng-dojang/lectures/26/1'
                },
                {   text   => 'S26 lecture 3: Kick and jump (Pattern)',
                    filter => '@yunguseng-dojang/lectures/26/3'
                },
            ]
        },
    );
    return @menu;
}
1;
