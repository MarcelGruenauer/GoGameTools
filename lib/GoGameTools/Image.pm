package GoGameTools::Image;
use GoGameTools::features;
use GoGameTools::Color;
use GoGameTools::Coordinate;
use Imager;
use GoGameTools::Class
  qw($image @white_stones @black_stones %markup @ownership $best_move
  $next_move @candidates $dimension $_stone_size $_border $_distance);

sub pre_calc ($self) {
    my $dimension = $self->dimension // die "GoGameTools::Imager: no dimension";
    my $stone_size =
      int(($dimension / (40 + 5 / 7)) + 0.5);    # + 0.5 for rounding
    $self->_stone_size($stone_size);
    $self->_border($stone_size * 1.5);
    $self->_distance($stone_size * 2 + 1);
}

sub render ($self) {
    $self->pre_calc;
    $self->image(
        Imager->new(
            xsize    => $self->dimension,
            ysize    => $self->dimension,
            channels => 4
        )
    );
    $self->draw_board_backgroud;
    $self->draw_grid;
    $self->draw_star_points;
    $self->draw_stones;
    $self->draw_candidates;
    $self->draw_best_move;
    $self->draw_next_move;
    $self->draw_ownership;
    return $self;    # for chaining
}

sub get_coords_for_intersection ($self, $x, $y) {
    my $border   = $self->_stone_size * 1.5;
    my $distance = $self->_stone_size * 2 + 1;
    return ($border + ($x - 1) * $distance, $border + ($y - 1) * $distance);
}

sub draw_board_backgroud ($self) {
    $self->image->box(
        color  => $self->get_color('board'),
        xmin   => 0,
        ymin   => 0,
        xmax   => $self->dimension - 1,
        ymax   => $self->dimension - 1,
        filled => 1
    );
}

sub draw_grid ($self) {
    for my $x (1 .. 18) {
        for my $y (1 .. 18) {
            my ($ul_x, $ul_y) = $self->get_coords_for_intersection($x,     $y);
            my ($lr_x, $lr_y) = $self->get_coords_for_intersection($x + 1, $y + 1);
            $self->image->box(
                color => $self->get_color('offset_grid'),
                xmin  => $ul_x + 1,
                ymin  => $ul_y + 1,
                xmax  => $lr_x + 1,
                ymax  => $lr_y + 1
            );
            $self->image->box(
                color => $self->get_color('grid'),
                xmin  => $ul_x,
                ymin  => $ul_y,
                xmax  => $lr_x,
                ymax  => $lr_y
            );
        }
    }
}

sub draw_star_points ($self) {
    for my $x (4, 10, 16) {
        for my $y (4, 10, 16) {
            my ($cx, $cy) = $self->get_coords_for_intersection($x, $y);
            $self->image->circle(
                color => $self->get_color('star_point'),
                r     => 3,
                x     => $cx,
                y     => $cy,
                aa    => 1
            );
        }
    }
}

sub draw_stones ($self) {
    my sub _draw ($x, $y, $color) {
        my ($cx, $cy) = $self->get_coords_for_intersection($x, $y);
        $self->image->circle(
            color => $self->get_color('black_stone'),
            r     => $self->_stone_size,
            x     => $cx,
            y     => $cy,
            aa    => 1
        );

        # For white stones, draw a smaller white circle on top of the black
        # circle so they appear to have an outline.
        if ($color eq WHITE) {
            $self->image->circle(
                color => $self->get_color('white_stone'),
                r     => $self->_stone_size - 2,
                x     => $cx,
                y     => $cy,
                aa    => 1
            );
        }
    }
    _draw(@$_, BLACK) for $self->black_stones->@*;
    _draw(@$_, WHITE) for $self->white_stones->@*;
}

sub draw_ownership ($self) {
    return if $self->ownership->@* == 0;
    my $ownership_img = Imager->new(
        xsize    => $self->dimension,
        ysize    => $self->dimension,
        channels => 4
    );
    for my $x (1 .. 19) {
        for my $y (1 .. 19) {
            my $ownership = $self->ownership->[ 19 * ($y - 1) + $x - 1 ];
            my $alpha     = int(255 * abs($ownership));
            my $color;
            if ($ownership < 0) {
                $color = Imager::Color->new(255, 255, 255, $alpha);
            } else {
                $color = Imager::Color->new(0, 0, 0, $alpha);
            }
            my ($cx, $cy) = $self->get_coords_for_intersection($x, $y);
            $ownership_img->box(
                color  => $color,
                xmin   => $cx - 7,
                ymin   => $cy - 7,
                xmax   => $cx + 6,
                ymax   => $cy + 6,
                filled => 1,
                alpha  => 1,
            );
        }
    }
    $self->image->rubthrough(src => $ownership_img);
}
use constant ALPHA => 170;

sub draw_candidates ($self) {

    # default KaTrain colors: [ up-to score diff, [ R, G, B ] ]
    my @thresholds = (
        [ -0.5,  [ 30,  150, 0 ] ],      # green
        [ -1.5,  [ 171, 229, 46 ] ],     # light green
        [ -3,    [ 242, 242, 0 ] ],      # yellow
        [ -6,    [ 229, 102, 25 ] ],     # orange
        [ -12,   [ 204, 0,   0 ] ],      # red
        [ -1000, [ 114, 33,  107 ] ],    # purple
    );
    for ($self->candidates->@*) {
        my ($cx, $cy) = $self->get_coords_for_intersection(coord_sgf_to_xy($_->{move}));
        my $color;
        for my $t (@thresholds) {
            next if $_->{score_diff} < $t->[0];
            $color = Imager::Color->new($t->[1]->@*, ALPHA);
            last;
        }
        $self->image->circle(
            color => $color,
            r     => $self->_stone_size,
            x     => $cx,
            y     => $cy,
            aa    => 1,
        );
    }
}

sub draw_best_move ($self) {
    my $best_move = $self->best_move or return;
    my ($cx, $cy) =
      $self->get_coords_for_intersection(coord_sgf_to_xy($best_move));
    $self->image->circle(
        color => Imager::Color->new(10, 195, 243, ALPHA),    # blue
        r     => $self->_stone_size,
        x     => $cx,
        y     => $cy,
        aa    => 1,
    );
}

sub draw_next_move ($self) {
    my $next_move = $self->next_move or return;
    my ($cx, $cy) =
      $self->get_coords_for_intersection(coord_sgf_to_xy($next_move));
    $self->image->circle(
        color => Imager::Color->new(255, 0, 0, ALPHA),
        r     => $self->_stone_size * 0.4,
        x     => $cx,
        y     => $cy,
        aa    => 1,
    );
}

sub get_color ($self, $name) {
    our $colors //= {
        white_stone => Imager::Color->new(233, 233, 233),
        black_stone => Imager::Color->new(0,   0,   0),
        board       => Imager::Color->new(222, 182, 111),
        grid        => Imager::Color->new(136, 98,  54),
        offset_grid => Imager::Color->new(194, 154, 92),
        star_point  => Imager::Color->new(89,  49,  9),
    };
    return $colors->{$name} // die "no color '$name'\n";
}

sub png_data ($self) {
    my $data;
    $self->image->write(data => \$data, type => 'png')
      or die $self->image->errstr;
    return $data;
}

sub to_stdout ($self) {
    binmode STDOUT;
    $self->image->write(fd => fileno(STDOUT), type => 'png')
      or die $self->image->errstr;
}

sub to_file ($self, $filename) {
    $self->image->write(file => $filename, type => 'png')
      or die $self->image->errstr;
}

sub add_stones_from_board ($self, $board) {
    for my $y (1 .. 19) {
        for my $x (1 .. 19) {
            my $stone = $board->stone_at_coord(chr(96 + $x) . chr(96 + $y));
            if ($stone eq BLACK) {
                push $self->black_stones->@*, [ $x, $y ];
            } elsif ($stone eq WHITE) {
                push $self->white_stones->@*, [ $x, $y ];
            }
        }
    }
}

sub add_markup_from_node ($self, $node) {
}

sub add_ownership_from_analysis ($self, $analysis) {
    $self->ownership->@* = split /\s+/, $analysis->ownership;
}

sub setup_dummy ($self) {

    sub _make_board {
        use GoGameTools::Board;
        my $board        = GoGameTools::Board->new;
        my @black_stones = (
            [ 3, 3 ], [ 3, 4 ], [ 3,  6 ], [ 6,  2 ], [ 6,  3 ], [ 7, 2 ],
            [ 7, 4 ], [ 8, 2 ], [ 10, 3 ], [ 16, 4 ], [ 16, 16 ]
        );
        for (@black_stones) {
            my ($x, $y) = @$_;
            $board->place_stone_at_coord(chr(96 + $x) . chr(96 + $y), BLACK);
        }
        my @white_stones = (
            [ 4, 4 ], [ 5, 2 ], [ 5, 3 ], [ 6, 4 ], [ 6, 5 ], [ 7, 3 ],
            [ 8, 3 ], [ 9, 2 ], [ 9, 3 ], [ 9, 4 ], [ 4, 16 ]
        );
        for (@white_stones) {
            my ($x, $y) = @$_;
            $board->place_stone_at_coord(chr(96 + $x) . chr(96 + $y), WHITE);
        }
        return $board;
    }
    my $board = _make_board;
    $self->add_stones_from_board($board);
    use GoGameTools::KataGo::Analysis;
    my $analysis = GoGameTools::KataGo::Analysis->new;
    $analysis->ownership(
        join ' ',
        (   0.469736,    0.319004,    0.199453,    -0.287182,   -0.65177,    -0.788426,
            -0.771461,   -0.780513,   -0.667932,   -0.501708,   -0.252172,   -0.148058,
            -0.0216664,  0.0723944,   0.156184,    0.211289,    0.246865,    0.252797,
            0.258752,    0.582947,    0.58761,     0.396016,    0.430114,    -0.936529,
            -0.69923,    -0.685071,   -0.703318,   -0.950318,   -0.104104,   -0.232715,
            -0.129753,   -0.0353037,  0.0593854,   0.189225,    0.228318,    0.256883,
            0.265088,    0.260553,    0.631928,    0.681603,    0.795612,    0.109814,
            -0.929041,   -0.719996,   -0.954569,   -0.954005,   -0.95653,    0.120408,
            -0.159638,   -0.162199,   -0.0854053,  0.169594,    0.319592,    0.297314,
            0.317727,    0.265821,    0.252399,    0.636745,    0.688356,    0.800097,
            -0.833785,   -0.782116,   -0.939733,   -0.523173,   -0.661693,   -0.948584,
            -0.23752,    -0.186646,   -0.132635,   -0.144945,   0.143521,    0.197252,
            0.79602,     0.315389,    0.261998,    0.195315,    0.549911,    0.616786,
            0.378892,    0.041012,    -0.117799,   -0.936266,   -0.559186,   -0.398998,
            -0.348349,   -0.217768,   -0.123048,   -0.0973438,  -0.0473824,  0.0616588,
            0.0831935,   0.150962,    0.322902,    0.157875,    0.108423,    0.380122,
            0.459882,    0.787689,    0.133547,    -0.0502994,  -0.135493,   -0.250574,
            -0.232462,   -0.229874,   -0.139565,   -0.080141,   -0.0739643,  -0.0528219,
            -0.0309547,  -0.0386848,  -0.111243,   -0.256903,   -0.0532968,  -0.00437505,
            0.158306,    0.168392,    -0.24244,    0.0206427,   -0.0573759,  -0.136487,
            -0.141929,   -0.149136,   -0.140751,   -0.106318,   -0.0755909,  -0.0626009,
            -0.051371,   -0.0537537,  -0.0362272,  -0.0835904,  -0.104136,   -0.113877,
            -0.0582882,  -0.0135073,  -0.110473,   -0.2008,     -0.135424,   -0.136191,
            -0.124395,   -0.118731,   -0.10589,    -0.0965835,  -0.0775474,  -0.0568094,
            -0.0456242,  -0.0394178,  -0.0337315,  -0.023085,   -0.0451471,  -0.0280499,
            -0.0519543,  -0.0574804,  -0.097121,   -0.126737,   -0.124614,   -0.105008,
            -0.112339,   -0.0935925,  -0.0847682,  -0.0734206,  -0.0656327,  -0.0529157,
            -0.0413146,  -0.0285978,  -0.0171494,  0.00128615,  0.00980605,  -0.0153868,
            0.00813475,  -0.0325082,  -0.037763,   -0.117217,   -0.129722,   -0.113909,
            -0.0787503,  -0.0755812,  -0.0650356,  -0.0612875,  -0.0562659,  -0.0513257,
            -0.0435782,  -0.0322879,  -0.0170287,  0.00404857,  0.0373571,   0.0595799,
            0.0687994,   0.0526125,   -0.00856813, -0.0520983,  -0.118698,   -0.121582,
            -0.102612,   -0.0691825,  -0.0713046,  -0.0565035,  -0.0509107,  -0.0457869,
            -0.0413147,  -0.0345209,  -0.024113,   -0.00957439, 0.00897531,  0.02684,
            0.0477335,   0.01324,     -0.00294927, -0.0717521,  -0.0918301,  -0.114711,
            -0.11561,    -0.127311,   -0.0320139,  -0.0885465,  -0.0716228,  -0.0515236,
            -0.0392577,  -0.0319799,  -0.0250841,  -0.016036,   -0.00638964, 0.0113832,
            0.0318127,   0.0430728,   0.00595484,  0.0851523,   -0.13704,    -0.159311,
            -0.0955099,  -0.115189,   -0.126617,   -0.133596,   -0.124737,   -0.0984223,
            -0.0633277,  -0.0438187,  -0.0299431,  -0.0178985,  -0.00973557, 0.000781498,
            0.014406,    0.0421322,   0.114527,    0.0190445,   -0.0501218,  -0.247888,
            -0.204987,   -0.0705059,  -0.0670285,  -0.134338,   -0.267831,   -0.187638,
            -0.181072,   -0.0871881,  -0.0479789,  -0.0255662,  -0.0127536,  -0.00197576,
            0.0167726,   0.036292,    0.123187,    0.0833939,   -0.105131,   -0.203437,
            -0.253783,   -0.235855,   -0.00170909, -0.192073,   -0.346599,   -0.360141,
            -0.258726,   -0.158503,   -0.158172,   -0.0942267,  -0.0345644,  -0.0118246,
            0.00773991,  0.0350164,   0.0743226,   0.137221,    0.151549,    0.721993,
            0.515176,    -0.180765,   0.055328,    0.205698,    0.186621,    -0.703907,
            -0.747871,   -0.695571,   -0.265448,   -0.0960398,  -0.0625216,  -0.0148467,
            -0.00178049, -0.00311043, 0.0368549,   0.0538582,   0.146412,    0.381814,
            0.861684,    0.53433,     0.689703,    0.309108,    0.435098,    0.483996,
            0.689125,    0.660665,    0.66983,     -0.638348,   -0.096132,   -0.0484686,
            -0.0519644,  -0.0495685,  -0.0178924,  0.041824,    0.0334179,   0.120068,
            0.360331,    0.756552,    0.456773,    0.682322,    0.413904,    0.515734,
            0.610424,    0.438315,    0.429461,    0.191328,    0.251901,    -0.0507531,
            -0.00287909, -0.0585365,  -0.0305025,  -0.0167828,  -0.00162298, 0.0248071,
            -0.0059008,  0.325528,    0.522748,    0.500917,    0.493212,    0.421082,
            0.537256,    0.55269,     0.532926,    0.444251,    0.295263,    0.112385,
            0.0352945,   -0.0186264,  -0.0226987,  -0.0408812,  -0.0240074,  -0.00465503,
            0.0235804,   0.118896,    0.25042,     0.431211,    0.473934,    0.46535,
            0.430415,
        )
    );
    $self->add_ownership_from_analysis($analysis);
    return $self;    # for chaining
}
1;

=pod

dummy class that just runs a proof-of-concept

    perl -MGoGameTools::Image -e'
        GoGameTools::Image->new(dimension => 800)->setup_dummy->render->to_stdout
        ' >out.png && open out.png

=cut
