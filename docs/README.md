# gogame-manual - about GoGameTools

## Description

GoGameTools is a set of low-level tools for manipulating SGF data.

Its main features are:

* A Unix-like pipeline through which a collection of tree objects flows. Each
  tree does not just contain the SGF data but also metadata such as the
  filename where the SGF came from, its game information and tags that
  semantically describe the SGF data

* Tree objects are serialized to and parsed from a JSON data structure called
  SGJ - "Smart Game JSON". Many pipe segments that an SGJ collection as their
  input and produce one as their output. You can also use generic JSON tools
  such as `jq` to rearrange, filter and extract the SGJ data.

* A pipe segment that takes an SGJ collection as its input and generates a set
  of Go problems, each containing just one main line and no variations.

The tools follow the Unix philosophy that each command should just do one thing
and if possible be a filter that reads data from STDIN, processes it and prints
the results on STDOUT.

"In a very loose sense, the programs are orthogonal, spanning the space of jobs
to be done.". (from "Program design in the UNIX environment" by Rob Pike and
Brian W. Kernighan). Hence, "GoGameTools".

GoGameTools is flexible and powerful. This flexibility requires that you
understand the shell, especially pipes. Furthermore, some programs like
`gogame-each` and `gogame-traverse` let you manipulate SGF nodes in arbitrary
ways, so they are aimed at users with at least basic programming skills.

One disadvantage of using small tools connected by pipes is that SGF data is
passed between the pipe elements and each pipe element has to parse and then
print the SGF collection anew. This leads to duplicated effort. See
`gogame-pipe` for how to avoid this.

## Overview

Here is an example of what GoGameTools can do.

Suppose you an SGF file that contains joseki variations. Some of these
variations contain bad moves and follow-ups on how the opponent can refute
those joseki mistakes. Some moves are ladder-dependant; some show correct
variations for both.

With the following command-line you can create a series of individual problems
that each explore exactly one line. Problems start at various points in the
joseki tree. At the end of a problem, any bad move by the opponent is marked as
such. These problems are packaged in a web page that uses the Glift JavaScript
library to let the user practice these problems.

    gogame-cat joseki.sgf | gogame-gen-problems --gb | \
        gogame-filter -q 'correct_for_both' | gogame-glift-problems | browser

All of this is achieved in one shell pipeline by combining small and flexible
building blocks.

`browser` is a small tool I wrote which copies STDIN to a temporary file and
then opens that file in the default browser.

## Smart Game JSON (SGJ)

The data that is passed by the shell pipe between the building blocks is JSON
data that contains the SGF and metadata.

## Installation

At this time, this software is not available on the CPAN. To use it, clone the
[GitHub repo](https://github.com/base64tokyo/GoGameTools).

You will need perl 5.20 or newer. GoGameTools only depends on modules that come
with perl, so you don't have to install any dependencies.

To install GoGameTools:

    perl Build.PL
    ./Build
    ./Build install

## Reorientation

When reorienting a tree, the following words and phrases in comment properties
(C[]) are changed as well.

- upper left corner
- upper right corner
- lower left corner
- lower right corner
- left side
- right side
- upper side
- lower side
- white
- black
- White
- Black

E.g., "upper left corner" might become "upper right corner". "Black" might
become "White".

Only "black" and "white" have alternate forms that start with an uppercase
letter, because the other words won't appear at the start of a sentence.

## gogame-gen-problems

Suppose you have a complex variation tree for a particular shape, for example,
a joseki or a common corner shape. At certain points, the opponent can
choose between responses, so there are different variations you need to
know. You can either hope to find a problem viewer that loops through
all the variations, or you can preprocess the variation tree to create
a set of problems that each teaches exactly one variation.

The `gen_problems` command is such a preprocessor. It saves you from having to
create a series of problems, all with the same or similar board setups and all
including the same or similar responses to your mistakes.

### The GoGameTools philosophy of creating problems

- While solving a problem, the student will never be asked to play a bad move.

- Each problem teaches exactly one variation. If there are several possible
  responses by the opponent, they will be shown in different problems. If there
  are several possible moves by the student, it will be indicated which move to
  play or which moves not to play or under which condition a move should be
  played.

### The algorithm for generating problems

We will call the problem tree from which the problems will be generated the
"problem set".

To generate problems, we visit every leaf node in the set and work our way
backwards.

### Notes on directives

#### {{ tenuki <text> }}

Is replaced by a list of variations for all points considered a tenuki; all
those points are considered "correct". Each move gets the <text>. For the
<text>, you might use something like "Tenuki is right. White is already alive."

The {{ tenuki }} directive must occur in a leaf node; it doesn’t make sense for
that node to have children.

Discouraged. Use {{ status }} instead.

#### {{ show_choices }}

Assumes that all reasonable good follow-ups are defined. Adds a problem with
the current situation and the question “What are Black’s choices?”. In the
answer, the choices are marked with a circle (CR[]). The answer text is "The
circled positions are good."

This creates a new problem with the board position at the current node. If you
need the user to play moves leading up to the question, use the more explicit
{{ answer }} markup instead.

#### {{ rate_choices }}

Assumes that all reasonable good follow-ups are defined. Also assumes that
there are variations for bad-follow-ups. Adds a problem with the current
situation and the question “Which moves are good and which are bad?”. In the
answer, bad moves are marked with a cross (MA[]), while good moves get a circle
(CR[]). The answer text is "The circled positions are good; the crossed
positions are bad."

This creates a new problem with the board position at the current node. If you
need the user to play moves leading up to the question, use the more explicit
{{ answer }} markup instead.

#### {{ deter }}

Assumes that all reasonable good follow-ups are defined. Without this
directive, generated problems will have a guide at that node because the user
needs to know which of the reasonable moves to play in order to advance in the
problem. With this directive, there is no guide but there are crosses (MA[]) at
the positions we don’t want the user to play.

Another way to prevent a guide is to use {{ condition }} on all child nodes
that contain reasonable moves.

#### {{ assemble }}

All generated trees that pass include that node and have non-bad children will
be assembled into one finished tree. Use this with tsumego and semeai where
there are several ways to achieve the same thing, but they are not so different
that you want to generate multiple problems with guides or deterrants.

Don't use guides or deterrants on nodes below a node marked with {{ assemble }}
because they would prevent the problems from being properly assembled.
Actually, descendant guides are removed automatically.

#### {{ num 1 }}

Stops numbering one move back from the node that contains the directive. Use in
kifu when you don’t want to number all moves all the way back to the start of
the game.

#### {{ has_all_good_responses }}

This is an exanple of a higher-level directive. These are semantically more
specific than lower-level directives. They are converted to lower-level
directives.

Use this higher-level directive when you want to use {{ deter }} and {{
show_choices }} on the same node. It is converted to those two lower-level
directives. It also has the advantage that if there are child nodes marked as
{{ bad_move }}, the node automatically gets a {{ rate_choices }} directive as
well. If you later don't want to see so many problems, you can always filter by
the tags that are added by these lower-level directives.

This directive even works if there is only one good response but there is at
least one bad response as well; in this case, the node will get {{ rate_choices
}}, but not {{ show_choices }}.

### Barrier nodes

Use a barrier node if, in order to get to that node, the student would have to
make bad moves. For example, suppose it is Black to play at the root of a
life-and-death problem. If five moves later, Black might make a mistake and now
White should refute it, then in order to get to that subproblem, White would
have to respond to Black’s original correct moves. But in reality when Black
makes the initial correct move, White should assume that Black would play the
remaining moves correctly as well and should not continue to play locally,
saving those moves as ko threats.

### Tags

There are tags that only apply to individual nodes, called "node tags", and
there are tags that apply to the whole tree, called "tree tags".

Enter the most specific tags as hashtags in nodes. E.g.,

    #pressing_down #kikashi

Add node tags to nodes to which they apply.

When generating problems, they also get all the ancestor's tree tags. Tree tags
are collected in the game info node.

When a problem has an objective tag, it means that this is the expected result
if the opponent responds with good moves. It could turn into something else if
the opponent makes mistakes. For example, problems tagged "#killing_with_ko"
also includes problems where, when the opponent makes a bad response, he gets
killed unconditionally.

## Cookbook

### Recipes for authoring problems

Each leaf node is interpreted as the correct last move for a problem; this is
the node that is usually marked `RIGHT`. Its move color determines whose turn
it is to play first in the problem.

Starting with the leaf node, the tree is walked back up until a suitable
problem setup node is found. This is a node which either doesn't contain `B[]`
or `W[]`, so it could be an empty node or a node containing the stone setup
properties `AB[]` or `AW[]`, such as the root node.

There is one other kind of node that is considered the start of a problem. If a
node has a move of the same color as the leaf node, that is, it contains a move
by the color for which to solve the problem, and it is marked as a "bad move"
with `BM[1]`, then that node won't be part of the problem. That is because we
don't want the student to play a bad move.

If there are sibling nodes that also contain a move of the same color and which
isn't marked as a "bad move", that move's location is marked with a circle.
This means that if there are several moves that a student could play at a
junction, a guide is given as to which move this particular problem expects.
Moves marked as "bad moves" are never considered as alternatives, so if all
other variations are "bad", no guide is generated for the only "correct" move.

Every variation will result in a problem, even those marked as "bad move"; they
will be a problem for the opponent about how to answer that bad move. So if the
refutation is obvious, don't include it. If it is non-obvious, it deserves its
own problem.

### Ladders

If you have a move like "Black needs the ladder to play this", you can add a
variation after that move with a node that adds a White ladder breaker using
`AW[]`. Then play out the variation starting with White refuting Black's move.

### Bad moves

If you add a "bad move" for Black, you can follow it with a White refutation.
The leaf nodes for the variations in this sequence, then, should all be White
moves. The generated problems will go back beyong Black's "bad move" as far as
possible, as long White is playing "correct" moves.

### Requiring a final response by the opponent

In some problems, when the player who needs to solve the problem can play the
final move in sente, it is a good idea to show the appropriate response by the
opponent. This will stabilize the situation. To show where the opponent should
play, you can add `SL[]` markup for the desired response. `SL[]` is a
standard SGF property for selecting points on the board. Exactly one
intersection needs to be selected. `pipe_gen_problems()` will then add a node
showing this response to the generated problem.

### Questions and answers

The problem node can pose a question that the user has to answer. For example,
"which of the marked moves are good and which are bad?". For the answer node,
the problem author can choose an intersection, add a move there and add a
directive to the comment: `{{ answer This is the answer. }}` Then
`pipe_gen_problems()` will add a question mark on the intersection to indicate
where the user should play to see the answer. It will also add a node that
erases the move just played and contains all the relevant markup, for example,
the comment that contains the answer. By erasing the answer pseudo-move,
the answer diagram will look clean.

### Best practices

To show why a move is sente, add a move where the opponent tenuki and show how
to carry out the threat.

Don't use comments; use guides. There are no words on the go board during a
real game either, says Chizu-sensei.

Just because we only accept one move, it doesn't mean that other choices are
completely bad. They may not be optimal, or maybe the author simply only wants
to teach the given variation.

Also, in capturing races, where there are many combinations of taking
liberties, only one such sequence is tested in the problem. Generally, in
capturing races the convention should be to take liberties from the outside.
If necessary, modify the problem setup so that taking liberties from the
outside makes sense.

As a problem author, try to construct problems that have a unique solution. If
you really need to, use a guide.

Solving a problem doesn't mean clicking on points until a response appears, but
thinking about all variations before playing the first move. In a way, the
automated responses should only confirm what you have already read out
beforehand.

## Recipes for combining commands

(See examples/bashrc functions.)

## Studying locally with Glift

## Preparing a problem collection for EasyGo

# History

The design of the GoGameTools tools has undergone quite a few changes. In the
beginning, they were rather monolithic and different programs did similar
things in somewhat different circumstances, leading to a lot of duplicated code
and functionality.

For example, there was no `gogame-traverse` command, but there was a program to
remove comment nodes - `C[]` - from SGF files, but only in-place; it did not
work with pipes. There was another program that extracted the main line of an
SGF file, one that removed all annotations such as comments, markers and
labels, and so on. Each specialized traversal tool had to be implemented in its
own command.

The programs did more or less what I wanted, but they were still coupled too
tightly and were not elegant. I was hesitant to distribute them at that stage.
Then I saw a documentary on YouTube called "AT&T Archives - The UNIX Operating
System", in which Brian W. Kernighan said this:

"What you can do is to think of these UNIX system programs basically as in some
sense the building blocks with which you can create things. And the thing that
distinguishes the UNIX system from many other systems is the degree to which
those building blocks can be glued together in a variety of different ways -
not just obvious ways, but in many cases very unobvious ways - to get different
jobs done. The system is very flexible in that respect.

I think the notion of pipelining is the fundamental contribution of the system.
You can take a bunch of programs - two or more programs - and stick them
together end-to-end so that the data simply flows from the one on the left to
the one on the right and the system itself looks after all the connections, all
the synchronization, making sure that the data goes from the one into the
other. The programs themselves don't know anything about the connection. As far
as they are concerned, they're just talking to the terminal."

That was the inspiration to rewrite GoGameTools.

# The Smart Game JSON Format (SGJ)

A program that outputs SGJ only populated the `game_info` dictionary of a tree
if it parsed the input SGF data. Programs that use raw SGF data without parsing
it, output an empty `game_info` dictionary. On the other hand, programs that
parse SGF data never use the `gane_info` dictionary; rather they will have
better access to the game information via the SGF trees' game information node.

# Speed

You can speed up decoding and encoding JSON by installing the
C<Cpanel::JSON::XS> module or the C<JSON::XS> module. The C<Cpanel::JSON::XS>
module is preferred. If neither of these modules is installed, GoGameTools will
fall back to using the core C<JSON::PP> module, which is very slow.

# Internals

Flow of plugin calls in GoGameTools::GenerateProblems

- for each node in the source tree:
    - `handle_higher_level_directive()`
    - `preprocess_node()`
    - for each cloned node:
        - `handle_cloned_node_for_problem()`
        - `is_pseudo_node()`
        - `is_pseudo_node()` for the parent node
- for each problem:
    - `finalize_problem_1()`
    - for each node in the problem:
        - `finalize_node()`
- for the problem collection:
    - `finalize_problem_collection()`
- for each problem:
    - `finalize_problem_2()`

