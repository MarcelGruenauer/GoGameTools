package GoGameTools::TagHandler;
use GoGameTools::features;
use GoGameTools::Util;
use GoGameTools::JSON;
use GoGameTools::Log;
use utf8;

sub import {
    my $caller = caller();
    no strict 'refs';
    *{"${caller}::$_"} = *{$_}{CODE} for qw(
      register_tags
      validate_tag
      expand_tag_name
      tag_name_is_or_does
      get_phony_tags
    );
}
my $internal_tags = [
    {   tag   => 'tactics',
        phony => 1
    },
    {   tag     => 'lining_up',
        does    => ['tactics'],
        comment => 'narabi'
    },
    {   tag  => 'anti_tower_peep_placement',
        does => ['tactics']
    },
    {   does => ['tactics'],
        tag  => 'belly_attachment'
    },
    {   does => ['tactics'],
        tag  => 'jump_attachment'
    },
    {   does => ['tactics'],
        tag  => 'armpit'
    },
    {   does => ['tactics'],
        comment =>
          'attaching behind a second-line move, aiming to connect back with hane-connect',
        tag => 'ankle_hook'
    },
    {   tag  => 'breaking_the_wing',
        does => ['clamp']
    },
    {   tag  => 'cap',
        does => ['tactics']
    },
    {   does => ['tactics'],
        tag  => 'caterpillar_connection'
    },
    {   tag  => 'cave',
        does => ['tactics']
    },
    {   tag  => 'cranes_nest',
        does => ['tactics']
    },
    {   does => ['tactics'],
        tag  => 'driving'
    },
    {   tag  => 'dogleg',
        does => ['tactics']
    },
    {   comment =>
          'connecting to a stone inside an opponent group by crawling on the first line; the opponent cannot block the connection because his blocking stones would be captured due to a cut',
        does => ['tactics'],
        tag  => 'crawling_under_the_door'
    },
    {   does => [ 'tactics', 'double_hane', 'squeezing' ],
        tag  => 'double_hane_edge_squeeze'
    },
    {   tag  => 'eiffel_tower',
        does => ['tactics']
    },
    {   does => ['tactics'],
        tag  => 'eternal_life'
    },
    {   does => ['tactics'],
        tag  => 'eye_in_the_stomach'
    },
    {   does => ['tactics'],
        tag  => 'flower_six'
    },
    {   tag  => 'grappling_hook',
        does => ['tactics']
    },
    {   comment => 'of two or three stones',
        does    => ['tactics'],
        tag     => 'hane_at_the_head'
    },
    {   tag  => 'ladder',
        does => [ 'tactics', 'capturing_key_stones' ]
    },
    {   does => ['tactics'],
        tag  => 'unstable_connection'
    },
    {   tag  => 'bad_sente',
        does => ['tactics']
    },
    {   tag   => 'spiral_ladder',
        does  => [ 'ladder', 'capturing_key_stones' ],
        links => ['http://www.ntkr.co.jp/igoyogo/yogo_299.html'],
    },
    {   does => [ 'ladder', 'capturing_key_stones' ],
        tag  => 'double_ladder'
    },
    {   does => ['tactics'],
        tag  => 'squeezing'
    },
    {   does => [ 'tactics', 'squeezing', 'capturing_key_stones' ],
        tag  => 'loose_ladder'
    },
    {   tag  => 'mouse_stealing_oil',
        does => ['tactics']
    },
    {   tag  => 'stealing_eye',
        does => ['tactics']
    },
    {   tag  => 'jumping_over_wall',
        does => ['tactics']
    },
    {   tag  => 'monkey_jump',
        does => ['tactics']
    },
    {   tag  => 'net',
        does => [ 'tactics', 'capturing_key_stones' ]
    },
    {   does => ['net'],
        tag  => 'knights_net'
    },
    {   tag   => 'orikiri',
        links => ['http://www.ntkr.co.jp/igoyogo/yogo_180.html'],
        does  => ['tactics']
    },
    {   tag  => 'parallel_bars',
        does => ['tactics']
    },
    {   does => ['tactics'],
        tag  => 'rooster_on_one_leg'
    },
    {   does => ['tactics'],
        tag  => 'sacrifice_two'
    },
    {   tag   => 'shimetsuke',
        does  => [ 'tactics', 'squeezing' ],
        links => ['http://www.ntkr.co.jp/igoyogo/yogo_435.html'],
    },
    {   does => ['tactics'],
        tag  => 'stick_connection'
    },
    {   does => [ 'tactics', 'linking_up' ],
        tag  => 'double_knights_connection',
        comment =>
          "a knight's move on the second line connecting stones on the third and fourth lines"
    },
    {   does => ['tactics'],
        tag  => 'symmetry'
    },
    {   does => ['tactics'],
        tag  => 'tanuki_belly'
    },
    {   does => ['tactics'],
        tag  => 'three_is_one'
    },
    {   does => ['tactics'],
        tag  => 'two_stone_edge_squeeze'
    },
    {   does => ['tactics'],
        tag  => 'pushing_twice_then_keima'
    },
    {   does => ['tactics'],
        tag  => 'under_the_stones'
    },
    {   does    => ['under_the_stones'],
        comment => 'After the stones have been captured, cut to recapture',
        tag     => 'cut_under_the_stones'
    },
    {   does => ['under_the_stones'],
        comment =>
          'After the stones have been captured, play inside to make a false eye',
        tag => 'placement_under_the_stones'
    },
    {   tag  => 'windmill',
        does => [ 'tactics', 'crossfight' ]
    },
    {   does => ['tactics'],
        tag  => 'ko_lock'
    },
    {   tag     => 'connect_and_die',
        does    => ['tactics'],
        comment => 'oiotoshi'
    },
    {   does => [ 'tactics', 'stealing_eye' ],
        tag  => 'elbow_lock'
    },
    {   does => ['tactics'],
        tag  => 'carpenters_connection'
    },
    {   does => ['tactics'],
        tag  => 'nose_attachment'
    },
    {   does => ['tactics'],
        tag  => 'table_attachment'
    },
    {   does => ['tactics'],
        tag  => 'cork_in_the_bottle'
    },
    {   does => ['tactics'],
        tag  => 'guzumi'
    },
    {   does => ['tactics'],
        tag  => 'kado'
    },
    {   tag  => 'peep',
        does => ['tactics']
    },
    {   does => ['tactics'],
        tag  => 'resisting_peep'
    },
    {   does => ['tactics'],
        tag  => 'preventing_bamboo'
    },
    {   does => ['tactics'],
        tag  => 'snapback'
    },
    {   does => ['tactics'],
        tag  => 'double_snapback',
        does => ['snapback'],
    },
    {   tag  => 'cut_to_defend_cut',
        does => ['tactics']
    },
    {   tag  => 'daidaigeima',
        does => ['tactics']
    },
    {   does => ['tactics'],
        tag  => '123_principle'
    },
    {   comment =>
          'Applied to both good and bad pushes, by yourself or the opponent. This gives you a feeling for this tactic.',
        does => ['tactics'],
        tag  => 'pushing_from_behind'
    },
    {   tag  => 'second_line_kosumi',
        does => ['tactics']
    },
    {   tag  => 'two_recapture_one',
        does => ['tactics']
    },
    {   tag  => 'capturing_two_for_two_eyes',
        does => ['tactics']
    },
    {   tag  => 'trapezium',
        does => ['tactics']
    },
    {   tag  => 'cutting_the_trapezium',
        does => ['tactics']
    },
    {   tag  => 'wedge_separate',
        does => [ 'tactics', 'wedge' ]
    },
    {   does    => ['tactics'],
        comment => 'rappatsugi',
        tag     => 'trumpet_connection'
    },
    {   comment =>
          'Can be for the attacker or the defender; also as a result of encroachment.',
        does => ['tactics'],
        tag  => 'seki'
    },
    {   tag  => 'double_atari',
        does => ['tactics']
    },
    {   tag  => 'counteratari',
        does => ['tactics']
    },
    {   does => ['tactics'],
        tag  => 'dent'
    },
    {   tag     => 'wedge',
        does    => ['tactics'],
        comment => 'warikomi'
    },
    {   tag     => 'bend_wedge',
        does    => ['tactics'],
        comment => 'hanekomi'
    },
    {   does => ['tactics'],
        tag  => 'clamp'
    },
    {   tag  => 'counterclamp',
        does => [ 'tactics', 'clamp' ]
    },
    {   tag  => 'ko',
        does => ['tactics']
    },
    {   does => ['tactics'],
        tag  => 'double_hane'
    },
    {   does => ['tactics'],
        tag  => 'hane_and_cut'
    },
    {   tag  => 'hane_and_nakade',
        does => ['tactics']
    },
    {   tag  => 'peep_and_cut',
        does => [ 'tactics', 'peep' ]
    },
    {   tag  => 'crosscut',
        does => ['tactics']
    },
    {   comment => 'tsukehiki',
        does    => ['tactics'],
        tag     => 'attach_and_draw_back'
    },
    {   tag     => 'attach_and_extend',
        does    => ['tactics'],
        comment => 'tsukenobi'
    },
    {   tag     => 'attach_and_crosscut',
        comment => 'tsukegiri',
        does    => ['tactics']
    },
    {   does    => ['tactics'],
        comment => 'tsukeosae',
        tag     => 'attach_and_block'
    },
    {   comment => 'tsukefukure',
        does    => ['tactics'],
        tag     => 'attach_and_bulge'
    },
    {   tag     => 'push_and_cut',
        does    => ['tactics'],
        comment => 'degiri'
    },
    {   does => ['tactics'],
        tag  => 'push_and_backtrack'
    },
    {   does => ['tactics'],
        tag  => 'push_and_placement'
    },
    {   does => ['tactics'],
        tag  => 'clamp_against_attachment'
    },
    {   does => ['tactics'],
        tag  => 'elephant_eye'
    },
    {   does => ['tactics'],
        tag  => 'diagonal_cover'
    },
    {   tag  => 'knights_cover',
        does => ['tactics']
    },
    {   tag  => 'large_knights_cover',
        does => ['tactics']
    },
    {   tag  => 'shoulder_hit',
        does => ['tactics']
    },
    {   tag     => 'shoulder_cut',
        comment => 'katagiri',
        does    => ['tactics']
    },
    {   comment => 'atekomi',
        does    => ['tactics'],
        tag     => 'angle_wedge'
    },
    {   does => ['tactics'],
        tag  => 'compromised_diagonal'
    },
    {   does    => ['tactics'],
        comment => 'yurumi. A nobi against a push or peep, not blocking its path.',
        links   => [
            'https://www.ntkr.co.jp/igoyogo/yogo_962.html',
            'https://senseis.xmp.net/?JapaneseGoTerms'
        ],
        tag => 'loosening'
    },
    {   does  => ['tactics'],
        links => [
            'https://www.ntkr.co.jp/igoyogo/yogo_766.html',
            'https://ja.wikipedia.org/wiki/ノビ'
        ],
        tag => 'nobikiri'
    },
    {   tag  => 'trick_play',
        does => ['tactics']
    },
    {   tag  => 'table',
        does => ['tactics']
    },
    {   tag  => 'double_table',
        does => ['tactics']
    },
    {   tag  => 'cat_face',
        does => ['tactics']
    },
    {   tag  => 'dog_face',
        does => ['tactics']
    },
    {   tag  => 'horse_face',
        does => ['tactics']
    },
    {   tag  => 'dragon_face',
        does => ['tactics']
    },
    {   tag     => 'bumping',
        does    => ['tactics'],
        comment => 'butsukari',
    },
    {   tag  => 'flying_double_clamp',
        does => ['tactics']
    },
    {   tag  => 'throwing_in',
        does => ['tactics']
    },
    {   tag  => 'crossing_the_lair',
        does => [ 'tactics', 'connecting' ],
        comment =>
          "To cross the dragon's lair, throw him some gold to busy him while you cross."
    },
    {   tag  => 'braid',
        does => ['tactics']
    },
    {   tag  => 'first_line_empty_triangle',
        does => ['orikiri']
    },
    {   tag     => 'across_attach',
        does    => ['tactics'],
        comment => "Cutting across the knight's waist; tsukekoshi"
    },
    {   tag   => 'objective',
        phony => 1
    },
    {   does => ['objective'],
        tag  => 'opening'
    },
    {   does => ['opening'],
        tag  => 'making_a_position'
    },
    {   tag  => 'extending',
        does => ['opening'],
    },
    {   tag  => 'drawing_near',
        does => ['opening']
    },
    {   does => ['extending'],
        tag  => 'checking_extension'
    },
    {   does => ['opening'],
        tag  => 'pincering'
    },
    {   tag  => 'enlarging',
        does => ['opening']
    },
    {   tag  => 'making_a_triangular_framework',
        does => [ 'extending', 'enlarging' ]
    },
    {   tag  => 'making_a_rectangular_framework',
        does => ['making_a_triangular_framework']
    },
    {   does => ['checking_extension'],
        tag  => 'preventing_a_triangular_framework'
    },
    {   tag     => 'enlarging_while_limiting',
        does    => ['enlarging'],
        comment => 'The border of two moyos; pivot'
    },
    {   tag  => 'reducing_from_above',
        does => ['opening']
    },
    {   tag  => 'surrounding',
        does => ['opening']
    },
    {   does => ['objective'],
        tag  => 'attacking'
    },
    {   tag  => 'separating',
        does => ['attacking']
    },
    {   tag  => 'pressing_down',
        does => ['attacking']
    },
    {   tag  => 'sealing_in',
        does => ['attacking']
    },
    {   does => ['attacking'],
        tag  => 'spoiling_shape'
    },
    {   does => ['spoiling_shape'],
        tag  => 'forcing_into_empty_triangle'
    },
    {   does => ['forcing_into_empty_triangle'],
        tag  => 'forcing_into_farmers_hat'
    },
    {   tag  => 'forcing_into_dumpling',
        does => ['spoiling_shape']
    },
    {   tag  => 'probing',
        does => ['attacking']
    },
    {   tag  => 'making_heavy',
        does => ['attacking']
    },
    {   tag  => 'overconcentrating',
        does => ['attacking']
    },
    {   tag  => 'creating_weaknesses',
        does => ['attacking']
    },
    {   tag  => 'making_double_threats',
        does => ['attacking']
    },
    {   tag  => 'taking_away_base',
        does => ['attacking'],
    },
    {   tag  => 'capturing',
        does => ['attacking']
    },
    {   does => ['attacking'],
        tag  => 'making_territory'
    },
    {   does => [ 'attacking', 'ko' ],
        tag  => 'intimidating_with_ko'
    },
    {   does => ['attacking'],
        tag  => 'making_fist'
    },
    {   does => ['attacking'],
        tag  => 'invading'
    },
    {   does => ['invading'],
        tag  => 'invading_3_extension'
    },
    {   does => ['invading'],
        tag  => 'invading_side_framework'
    },
    {   does => ['attacking'],
        tag  => 'kikashi'
    },
    {   does => ['attacking'],
        tag  => 'bullying'
    },
    {   tag  => 'capping',
        does => ['attacking']
    },
    {   does => ['attacking'],
        tag  => 'leaning_attack'
    },
    {   does => ['attacking'],
        tag  => 'splitting_attack'
    },
    {   does    => ['attacking'],
        comment => 'Erasing eyespace on the side to attack, not necessarily to kill.',
        tag     => 'erasing_eyespace'
    },
    {   tag  => 'defending',
        does => ['objective']
    },
    {   does    => ['defending'],
        comment => "If linking up along the side, use the 'linking_up' tag instead.",
        tag     => 'connecting'
    },
    {   tag  => 'capturing_key_stones',
        does => ['defending']
    },
    {   tag  => 'developing',
        does => ['defending']
    },
    {   tag  => 'escaping',
        does => ['defending']
    },
    {   tag  => 'making_shape',
        does => ['defending']
    },
    {   does => ['defending'],
        tag  => 'taking_sente'
    },
    {   does => ['defending'],
        tag  => 'sabaki'
    },
    {   does => ['defending'],
        tag  => 'shinogi',
        comment =>
          "SL: avoiding death skilfully, often with a big dragon, by a process of making life while not damaging one's other groups or territory too seriously",
    },
    {   tag  => 'deny_kikashi',
        does => ['defending']
    },
    {   tag  => 'striking_back',
        does => ['defending']
    },
    {   tag  => 'defending_against_multiple_threats',
        does => ['defending']
    },
    {   does    => ['defending'],
        comment => "Not in response to an attack. Compare with 'defending_base'.",
        tag     => 'solidifying_base'
    },
    {   tag  => 'defending_base',
        does => ['defending'],
        comment =>
          "In response to an attack. For example, keeping an extension connected. Compare with 'solidifying_base'."
    },
    {   tag => 'linking_up',
        comment =>
          "watari; linking up two seemingly cut-apart groups along the side on the first to third lines. Compare with 'connecting' and 'defending_base'.",
        does => ['defending']
    },
    {   does => ['defending'],
        tag  => 'resisting_with_ko'
    },
    {   does => ['defending'],
        tag  => 'forcing_before_defending'
    },
    {   tag  => 'refuting_overplay',
        does => ['defending']
    },
    {   does => [ 'attacking', 'defending' ],
        tag  => 'handling_invasion'
    },
    {   tag  => 'strategy',
        does => ['objective']
    },
    {   tag  => 'sacrificing_junk_stones',
        does => ['strategy']
    },
    {   tag  => 'chasing_junk_stones',
        does => ['strategy']
    },
    {   tag  => 'walking_ahead',
        does => ['strategy']
    },
    {   does => ['strategy'],
        tag  => 'pushing_from_weak_area'
    },
    {   tag  => 'joseki_choice',
        does => ['strategy']
    },
    {   does => ['strategy'],
        tag  => 'direction_of_attack'
    },
    {   does => ['strategy'],
        tag  => 'value_of_sides'
    },
    {   tag  => 'playing_away_from_thickness',
        does => ['strategy']
    },
    {   does => ['strategy'],
        tag  => 'avoiding_being_enclosed'
    },
    {   does => ['strategy'],
        tag  => 'leaving_aji'
    },
    {   does => ['strategy'],
        tag  => 'good_ugly_keima_cut'
    },
    {   does => ['strategy'],
        tag  => 'tenuki'
    },
    {   does => ['strategy'],
        tag  => 'running_battle'
    },
    {   does => ['strategy'],
        tag  => 'tennouzan'
    },
    {   does    => ['strategy'],
        comment => 'Four cut groups that must all be saved',
        tag     => 'crossfight'
    },
    {   tag  => 'endgame',
        does => ['objective']
    },
    {   does => ['endgame'],
        tag  => 'offensive_endgame'
    },
    {   tag  => 'defensive_endgame',
        does => ['endgame']
    },
    {   does => ['defensive_endgame'],
        tag  => 'stopping_encroachments'
    },
    {   does => ['endgame'],
        tag  => 'large_yose'
    },
    {   does => ['offensive_endgame'],
        tag  => 'breaking_in'
    },
    {   tag  => 'encroaching',
        does => ['offensive_endgame']
    },
    {   tag  => 'threatening_to_kill',
        does => ['offensive_endgame']
    },
    {   tag  => 'forcing_removal',
        does => ['offensive_endgame']
    },
    {   does => ['offensive_endgame'],
        tag  => 'double_endgame_attacks'
    },
    {   tag  => 'double_endgame_defenses',
        does => ['defensive_endgame']
    },
    {   does => [ 'offensive_endgame', 'taking_sente' ],
        tag  => 'closing_in_sente'
    },
    {   tag  => 'living',
        does => ['objective']
    },
    {   does => ['living'],
        tag  => 'securing_eye_shape'
    },
    {   tag  => 'enlarging_eye_space',
        does => ['living']
    },
    {   does => ['living'],
        tag  => 'living_by_capturing'
    },
    {   does => ['living'],
        tag  => 'living_with_false_eyes'
    },
    {   tag  => 'living_with_seki',
        does => [ 'living', 'seki' ]
    },
    {   tag     => 'squashing',
        comment => 'oshitsubushi',
        does    => ['living']
    },
    {   tag  => 'living_with_ko',
        does => [ 'living', 'ko' ]
    },
    {   tag  => 'living_with_double_ko',
        does => ['living']
    },
    {   does => ['objective'],
        tag  => 'killing'
    },
    {   does => ['killing'],
        tag  => 'nakade'
    },
    {   tag  => 'bent_four_in_the_corner',
        does => ['killing']
    },
    {   does => ['killing'],
        tag  => 'making_a_false_eye'
    },
    {   tag  => 'killing_with_ko',
        does => [ 'killing', 'ko' ]
    },
    {   does => ['killing'],
        tag  => 'killing_with_double_ko'
    },
    {   tag  => 'ten_thousand_year_ko',
        does => ['killing']
    },
    {   tag  => 'capturing_race',
        does => ['objective']
    },
    {   does => ['capturing_race'],
        tag  => 'extending_liberties'
    },
    {   does => ['capturing_race'],
        tag  => 'reducing_liberties'
    },
    {   tag  => 'capturing_race_ko',
        does => ['capturing_race']
    },
    {   tag  => 'capturing_race_seki',
        does => [ 'capturing_race', 'seki' ]
    },
    {   does => ['capturing_race'],
        tag  => 'one_eye_no_eye'
    },
    {   does => ['capturing_race'],
        tag  => 'destroying_one_eye'
    },
    { tag => 'task' },
    {   tag  => 'question',
        does => ['task']
    },
    {   tag  => 'show_choices',
        does => ['task']
    },
    {   tag  => 'rate_choices',
        does => ['task']
    },
    {   tag  => 'multiple_choice',
        does => ['task']
    },
    {   does => ['task'],
        tag  => 'status'
    },
    {   does => ['task'],
        tag  => 'copy'
    },
    {   tag  => 'sujiba',
        does => ['task']
    },
    {   tag  => 'counting_score',
        does => ['task']
    },
    {   tag  => 'calculating_move_value',
        does => ['task']
    },
    {   tag   => 'level',
        phony => 1
    },
    {   comment => '30k; just learned the rules',
        does    => ['level'],
        tag     => 'ddk3'
    },
    {   comment => '29k-20k',
        does    => ['level'],
        tag     => 'ddk2'
    },
    {   comment => '19k-10k',
        does    => ['level'],
        tag     => 'ddk1'
    },
    {   comment => '9k-5k',
        does    => ['level'],
        tag     => 'lowsdk'
    },
    {   comment => '4k-1k',
        does    => ['level'],
        tag     => 'highsdk'
    },
    {   does    => ['level'],
        comment => '1d-3d',
        tag     => 'lowdan'
    },
    {   does    => ['level'],
        comment => '4d-7d',
        tag     => 'highdan'
    },
    {   comment => 'For problems extracted from a real game',
        tag     => 'game'
    },
    {   tag     => 'progame',
        comment => 'For problems extracted from a real game between two professionals',
        does    => ['game']
    },
    {   comment =>
          'for a game where at least one player is an AI. Or for new moves by AI',
        tag => 'ai'
    },
    { tag => 'correct_for_both' },
    { tag => 'debug' }
];

sub register_tags {
    our @tags = $internal_tags->@*;
    if (my $user_tags_file = $ENV{BADUKSPACE_TAGS}) {
        my $user_tags = json_decode(slurp($user_tags_file));
        push @tags, $user_tags->@*;
    }
    my %first_pass;
    our (%tag_spec, @phony_tags);

    # first pass: just remember the tags
    for my $spec (@tags) {
        my $tag = $spec->{tag};
        fatal("tag [$tag] already exists") if $tag_spec{$tag};
        fatal("tag [$tag] contains invalid characters") unless $tag =~ /^[\w\+\-]+$/;
        $first_pass{$tag} = $spec->{does} // [];
        push @phony_tags, $spec->{tag} if $spec->{phony};
    }

    # second pass: expand tag relationships
    while (my ($tag, $does) = each %first_pass) {
        my @to_expand    = $does->@*;
        my %is_expansion = map { $_ => 1 } ($tag, @to_expand);
        my %did_expand   = ($tag => 1);
        while (@to_expand) {
            my $rel      = shift @to_expand;
            my $rel_spec = $first_pass{$rel}
              // fatal("relationship tag [$rel] does not exist");
            for my $does ($rel_spec->@*) {
                next if $did_expand{$does}++;
                $is_expansion{$does}++;
                push @to_expand, $first_pass{$does}->@*;
            }
        }
        $tag_spec{$tag} = [ sort keys %is_expansion ];
    }
}

sub validate_tag ($tag) {
    our %tag_spec;
    $tag =~ s/:.*//;    # remove flags
    fatal("unknown tag $tag") unless exists $tag_spec{$tag};
}

sub expand_tag_name ($tag) {
    our %tag_spec;
    my $expansion = $tag_spec{$tag} // fatal("unknown tag [$tag]");
    return ($expansion->@*);
}

sub tag_name_is_or_does ($candidate, $wanted) {
    our %tag_name_is_or_does;
    $tag_name_is_or_does{$candidate} //=
      { map { $_ => 1 } expand_tag_name($candidate) };
    return $tag_name_is_or_does{$candidate}{$wanted};
}

# Like Makefile phony targets, GoGameTools phony tags don't represent an actual
# technique or objective but are used for grouping. When finalizing tags in
# GoGameTools::GenerateProblems, phony tags are removed.
sub get_phony_tags { our @phony_tags }
1;
