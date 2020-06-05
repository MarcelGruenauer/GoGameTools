# Introduction

## Description

GoGameTools is a set of low-level tools for manipulating SGF data.

Its main features are:

- A Unix-like pipeline through which a collection of tree objects flows. Each
  tree does not just contain the SGF data but also metadata such as the
  filename where the SGF came from, its game information and tags that
  semantically describe the SGF data

- Tree objects are serialized to and parsed from a JSON data structure called
  SGJ - "Smart Game JSON". Many pipe segments that an SGJ collection as their
  input and produce one as their output. You can also use generic JSON tools
  such as `jq` to rearrange, filter and extract the SGJ data.

- A pipe segment that takes an SGJ collection as its input and generates a set
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
such. These problems are packaged in a web page that uses the WGo JavaScript
library to let the user practice these problems.

~~~
gogame-cat joseki.sgf | gogame-gen-problems --viewer WGo | \
    gogame-filter -q 'correct_for_both' | gogame-site-gen-data | \
    gogame-site-write-static --viewer WGo -d www
cd www && python -m SimpleHTTPServer 8888
~~~

All of this is achieved in one shell pipeline by combining small and flexible
building blocks.
