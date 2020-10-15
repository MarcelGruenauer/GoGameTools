# Cookbook

## Clean up a list of games

Take a list of SGF files. Extract only the main line (discarding variations),
then clear all comments.

```bash
ls *.sgf | \
    gogame-each -e '$_->extract_main_line' | \
    gogame-traverse -e '$_->del("C")' | \
    gogame-write
```

`gogame-each`, like most programs, reads [SGJ](api/sgj.md) on STDIN or turns a
list of filenames into SGJ. It runs the given commands on each tree. In this
case, `$_->extract_main_line` removes all variations, leaving only the main
line moves. It then outputs SGJ again.

`$_` contains a reference to the tree object. See `GoGameTools::Tree` for
methods you can use on the tree. You can get the tree's root node (also known
as the "game info node") with `$::g` or `$_->get_node(0)`.

The results are piped to `gogame-traverse`. This program also iterates over all
trees but executes the commands for each node, not just for each tree. So here
we clear the `C[]` SGF property - the comment - from each node. The results are
output as SGJ again. Here `$_` contains a reference to the node object. See
`GoGameTools::Node` for methods you can use on the tree.

`gogame-write` then writes the resulting SGF files. It takes the SGJ, which for
each tree contains, among other things, the input filename and the SGF. It
simply writes that SGF to that file.
