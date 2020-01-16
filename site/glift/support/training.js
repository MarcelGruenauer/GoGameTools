// cache lines
var gliftWidget;
var fullAxis = [ "a", "b", "c", "d", "e", "f", "g", "h", "i",
    "j", "k", "l", "m", "n", "o", "p", "q", "r", "s" ];
var lines = {
    "aj:sj": fullAxis.map(function(el) {
        return [ el + "j", String.fromCharCode(0x23BB) ];
    }),
    "ja:js": fullAxis.map(function(el) {
        return [ "j" + el, "|" ];
    }),
    "as:sa": fullAxis.map(function(el) {
        var mirror = String.fromCharCode(115 + 97 - el.charCodeAt(0));
        return [ mirror + el, String.fromCharCode(0x27CB) ];
    }),
    "aa:ss": fullAxis.map(function(el) {
        return [ el + el, String.fromCharCode(0x27CD) ];
    }),
};

// Fisher-Yates shuffle; see https://bost.ocks.org/mike/shuffle/ and Wikipedia
function shuffle(array) {
  var m = array.length, t, i;

  // While there remain elements to shuffle…
  while (m) {

    // Pick a remaining element…
    i = Math.floor(Math.random() * m--);

    // And swap it with the current element.
    t = array[m];
    array[m] = array[i];
    array[i] = t;
  }

  return array;
}

function initTraining() {

    /* "problem-explanation" action is taken from glift's src/api/icon_actions.js;
        I've removed the "jump-left-arrow" and "jump-right-arrow" icons because
        apart from assembly there are no branches in our problems, and the icons
        took up screen space, moving the "undo" icon off the div.
    */

    glift.api.iconActionDefaults["problem-explanation"] = {
        click: function(event, widget, icon, iconBar) {
            widget.manager.createTemporaryWidget({
                widgetType: glift.WidgetType.GAME_VIEWER,
                initialPosition: widget.controller.initialPosition,
                sgfString: widget.controller.originalSgf(),
                showVariations: glift.enums.showVariations.ALWAYS,
                problemConditions: glift.util.simpleClone(
                widget.sgfOptions.problemConditions),
                icons: [
                    "arrowleft",
                    "arrowright",
                    "undo"
                ],
                statusBarIcons: [
                    "fullscreen"
                ],
                rotation: widget.sgfOptions.rotation,
                boardRegion: widget.sgfOptions.boardRegion
            });
        },
        tooltip: "Explore the solution"
    };

    glift.widgets.WidgetManager.prototype.getCurrentSgfObj = function() {
        var currentIndex = this.sgfColIndex;
        var currentProblem = problemData[currentIndex];

        // Each problem has a list of topics that it occurs in. These are
        // numeric indices into the topicIndex.

        var relatedData = currentProblem.topics
            .map(function(el) {
                var entry = topicIndex[el];
                entry.link = "../by_filter/" + entry.filename + ".html";
                return entry;
            })
            .sort(function(a, b) {
                if (a.html < b.html) return -1;
                if (a.html > b.html) return 1;
                return 0; });

        // Show a link if the current problem has more than one - i.e., the
        // currently shown - variation in the SGF tree that it came from.

        var related_positions = currentProblem.related_positions;
        if (related_positions > 1) {
            relatedData.unshift({
                text: 'Same tree',
                count: related_positions,
                link: '../by_collection_id/' + currentProblem.collection_id + '.html'
            });
        }

        var related_ul = document.getElementById('related');
        related_ul.innerHTML = '';

        relatedData.forEach(function(el) {
            li = document.createElement('li');

            var text = '';
            if (el.group) {
                text = el.group + ' ';
            }
            li.innerHTML = text + '<a href=' + el.link + '>' + el.text + ' (' + el.count + ')</a>';

            related_ul.appendChild(li);
        });

        // do what the original function did
        return this.getSgfObj(currentIndex);
    };

problemData = shuffle(problems);

var sgfData = problemData.map(function(sgfentry) {
    // parse() => [collection of GameTree objects]
    return SGFGrove.stringify(
        SGFGrove.parse(sgfentry.sgf).map(function(gameTree) {
            SGFReorienter()
                .mirrorHorizontally(Math.random() < 0.5)
                .mirrorVertically(Math.random() < 0.5)
                .swapAxes(Math.random() < 0.5)
                .swapColors(Math.random() < 0.5)
                .reorientGameTree(gameTree);

            // FIXME: don't swap colors for full-screen problems,
            // especially real games and fuseki

            /* Add a comment whose turn it is to play. On devices with
               touch input there would be no way to know otherwise. The
               problem generator can set MN[-1] to omit the message.
               This is useful for tasks such as questions, rating
               choices, showing choices and tsumego status problems; in
               these problems the user is not supposed to play a move
               as Black or White; the intersection to be played is
               simply the impetus to show the answer.

               gameTree[0] are the nodes; [1] are the descendant game trees
               Then the game info node is the first node.
            */

            var gameInfo = gameTree[0][0];
            var commentParts = [];

            if (gameInfo.hasOwnProperty("PW")) {
                var giWhite = gameInfo.PW;
                if (gameInfo.hasOwnProperty("WR")) {
                    giWhite += " (" + gameInfo.WR + ")";
                }
                commentParts.push("White: " + giWhite);
            }

            if (gameInfo.hasOwnProperty("PB")) {
                var giBlack = gameInfo.PB;
                if (gameInfo.hasOwnProperty("BR")) {
                    giBlack += " (" + gameInfo.BR + ")";
                }
                commentParts.push("Black: " + giBlack);
            }

            if (gameInfo.hasOwnProperty("DT")) {
                commentParts.push("Date: " + gameInfo.DT);
            }

            if (gameInfo.hasOwnProperty("KM")) {
                commentParts.push("Komi: " + gameInfo.KM);
            }

            if (gameInfo.hasOwnProperty("RE")) {
                commentParts.push("Result: " + gameInfo.RE);
            }

            if (gameInfo.hasOwnProperty("EV")) {
                commentParts.push("Event: " + gameInfo.EV);
            }

            if (gameInfo.hasOwnProperty("RO")) {
                commentParts.push("Round: " + gameInfo.RO);
            }

            if (gameInfo.hasOwnProperty("PC")) {
                commentParts.push("Place: " + gameInfo.PC);
            }

            if (!gameInfo.hasOwnProperty("MN") || gameInfo.MN !== -1) {
                commentParts.push("");
                commentParts.push('<h2>' + (gameInfo.PL === "W" ? "White" : "Black")
                    + " to play.</h2>");
            }

            if (gameInfo.hasOwnProperty("C")) {
                commentParts.push("");
                commentParts.push(gameInfo.C);
            }

            gameInfo.C = commentParts.join("\n");

            /* Glift doesn't understand the LN[] property generated by
               the GoGameTools's 'copy' directive. So replace it with a
               pseudo-line of triangles (TR[]). This is not a general
               soluation for all lines, just the lines that 'copy'
               generates and that separate the board quadrants.
            */

            traverseGameTree(gameTree, function(node) {
                if (node.hasOwnProperty("LN")) {
                    var ln = node.LN[0].sort().join(":");
                    if (lines.hasOwnProperty(ln)) {
                        if (!node.hasOwnProperty("LB")) {
                            node.LB = [];
                        }
                        node.LB.push.apply(node.LB, lines[ln]);
                    }
                }

                /* FIXME disabled because the smileys look weird on iOS

                if (node.hasOwnProperty("LB")) {
                    var label_map = {
                        "?": String.fromCharCode(0x2639),  // frowning face
                        "!": String.fromCharCode(0x263A)   // smiling face
                    };
                    node.LB = node.LB.map(function(el) {
                        if (label_map.hasOwnProperty(el[1])) {
                            el[1] = label_map[el[1]];
                        }
                        return el;
                    });
                }

                */

            });

            return gameTree;
        })
    );
});

gliftWidget = glift.create({
    sgfCollection: sgfData,
    sgfDefaults: {
        widgetType: "STANDARD_PROBLEM",
        boardRegion: glift.enums.boardRegions.AUTO,
        // accept on both GB[1] and GW[1]; GW[1] occurs if calors have been swapped
        problemConditions: { GB: "1", GW: "1" },
        keyMappings: {
            ARROW_LEFT: 'iconActions.chevron-left.click',
            ARROW_RIGHT: 'iconActions.chevron-right.click',
            '/': 'iconActions.undo-problem-move.click'
        }
    },
    statusBarIcons: [
        "fullscreen"
    ],
    divId: "glift_main_display",
    allowWrapAround: 1
});
}

window.addEventListener('resize', function(event){
  gliftWidget && gliftWidget.redraw();
});
