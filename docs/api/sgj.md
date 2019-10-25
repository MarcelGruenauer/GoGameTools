# Smart Game JSON (SGJ)

The data that is passed by the shell pipe between the building blocks is
JSON data that contains the SGF and metadata.

## The Smart Game JSON Format (SGJ)

A program that outputs SGJ only populated the `game_info` dictionary of a tree
if it parsed the input SGF data. Programs that use raw SGF data without parsing
it, output an empty `game_info` dictionary. On the other hand, programs that
parse SGF data never use the `gane_info` dictionary; rather they will have
better access to the game information via the SGF trees' game information node.
