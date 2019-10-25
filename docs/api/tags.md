# SGF semantic tags

This file describes a proposal for SGF semantic tags.

Tags add queryable semantics to SGF data. The objective is to create advanced
training tools. We want to enable queries such as:

- select games that have crosscuts that occur before move 30
- select games that feature the small avalanche joseki also have spiral ladders
- select games with good empty triangles
- select dan-level problems where the key concept is connecting on the first
  line
- select problems where I have to separate opponent groups and the key
  technique is tsukekoshi

Each node in an SGF tree can have one or more tags, including the root node.
Tags defined in the root node apply to the whole tree, much like game
information properties such as `PW[]`. Tags defined in other nodes only apply
to that node.

Tags might be stored in a new SGF property such as `sags[foo][bar]`. Editors
usually don't allow custom SGF properties such as `sags[]`. So we need another
way of easily adding tags to nodes. One idea is to use hashtags in comments.
Tools can extract those tags, convert them to `sags[]` properties and remove
them from the comments.

Each definition takes the following form:

    tagX [, ... ] [ : tagY [, ... ] ];

There is a left-hand side and an optional right-hand side; they are separated
by a colon. Each side can contain one or several tags separated by commas.

If there is no right-hand side, this declares top-level tags. For example, to
declare that there is a tag called 'endgame', simply write:

    endgame;

If there is a right-hand side, then each tag from the left-hand side has a
"is-a" or "does" relationship with each tag on the right-hand side. For
example, to declare two tags, `microendgame` and `macroendgame` and to
simultaenously specify that they are part of the `endgame` tag, write:

    macroendgame, microendgame : endgame;

Tags must be declared before they can be used on the right-hand side.

Comments start with a hash character and are ignored to the end of the line.
Whitespace is ignored as well.

## Adding tags to SGF files

When adding tags to games and problems, be as specific as possible. For
example, instead of just `pincer`, use the more specific
`one_space_low_pincer`. Tools can expand Tags automatically to include more
generic variants. So when you search for `pincer`, you will also find nodes you
tagged with `one_space_low_pincer`.

When choosing tag names, avoid filler words such as "a" or "the" as far as
possible. Use the "-ing" form in tag names. Example: `forcing_into_dumpling`,
`taking_away_base`.

It is recommended that you only use the official, canonical tags to avoid
confusion. Tools should verify this and warn about unrecognized tags.

Tags will normally be added manually, but for certain basic move types and
patterns it should be possible to add tags automatically.

## Running queries

One way to run queries that involve tags might be using the `smartgo://` URL
scheme. [Link](https://smartgo.com/blog/smartgo-url-scheme.html). For example:

   smartgo://problems?tags=pincer&tags=avalanche

## Tag explanations

- 'function' is an objective. 'form' is a technique to achieve the objective.
It's not so clear-cut though. For example, squeezing is a form, but achieves
the 'spoiling_shape' objective.

- Fujisawa Shuko's "Dictionary of Basic Tesuji" categorizes moves by function,
not form. Tags that do 'function' are largely taken from that book.

- connecting: can be 'connecting by capturing cutting stones' or connecting
two groups that aren't yet clearly separated because they have empty space in
bettwen them such as 'connecting along the first line'.

- loose_ladder: ユルミシチョウ

- oiotoshi: means the opponent has two groups that have a cutting point. One
group has to be able to escape, but if he connects the other, trapped group,
both will be captured. If both groups can't escape to begin with, it's
not oiotoshi. After the opponent connected, the now single group cannot
escape. Also, during the course of a squeeze, an oiotoshi may appear,
but I only use the 'oiotoshi' tag if it appears at the beginning of the
problem. The captured stones aren't necessarily cutting stones; oiotoshi
can also occur in life-and-death.

- encroaching_on_enemy_territory is more endgame;
'laying_waste_to_enemy_territory' is more middle-game, like breaking into
something that's more than a framework but less than settled territory. It's
still different from 'invading', which is more like starting a group from
scratch in an enemy sphere of influence.

forcing_removal: 'semedori'

- rooster_on_one_leg: a split group that can't atari from either side. Also
  known as "golden chicken standing on one leg" and "ryou osu te nashi".

- 'enclosing' means sealing in an opponent's group and building influence. It
does not mean killing. E.g., filter 'joseki' + 'enclosing'; will probably also
have 'bad_move'.

- kikasare means being kikashi'd.

- wrong_timing: can mean playing an endgame move in the opening or middle game

- bad_strategy: Because we don't want the student to play bad moves, the
'bad_strategy' hierarchy of tags will be applied to problems where the opponent
makes such mistakes.

- direction_of_attack is more middle game than 'joseki_choice'

- keima_net: http://senseis.xmp.net/?KnightsMoveNet +
http://senseis.xmp.net/?NetExample12

- game_resolution, game_strategy: Game records can use the problem-related tags
such as 'chinese_fuseki' or 'walking_ahead' etc., as well, but there are some
tags that are really only useful for game records.

- classic_book: for out-of-copyright sources

- question: for tags automatically added by GoGameTools::GenerateProblems

- jidorigo: both take territory; no middle game fight

- ippoji: having just one framework, which, if invaded, leaves you without
compensation

- ryou_ippoji: both sides have just one framework

- ryoujimari: one or both players have two shimari

- invading_with_third_line_keima: against a stone on the fourth line

- invading_with_kado: invading at an incomplete tiger's mouth angle point

- splitting_daidaigeima_extension: from the fourth line

- first_line_descent: a sagari to the first line that has an effect on life-and-death.
  - ref 実力五段囲碁読本：コウのねばり p. 112
  - ref http://www.ntkr.co.jp/igoyogo/yogo_180.html
  - ref https://ja.wikipedia.org/wiki/サガリ_(囲碁)
  - ref https://hebogo.jimdo.com/星-1/問題/

- monkey_jump: is not just used in endgame; also for killing

- makuri: giving atari in a case where the opponent can immediately take one of
the stones involved in the atari, but you can then pull out the stone giving
atari http://senseis.xmp.net/?Makuri . Does it mean making an eye false by
threatening capture?

- jump35-keima34-tsume4: a move sequence that occurs in 34-1lap-1lp-jump and
34-1lap-1hp: a jump from the 3rd to the 5th line, followed by a keima from the
3rd to the 4th line, followed by a tsume on the 4th line.

- 34-2hap-1hs: 1-space high shimari

- anti_tower_peep_placement: http://senseis.xmp.net/?PlacementPreventingTheTowerPeep

- spiral_ladder: guru guru mawashi. combines sacrifice, squeezing and ladder.

- crosscut_extend: Like the proverb.

- crosscut_atari: There is another proverb about playing atari after a crosscut if there are stones around.
