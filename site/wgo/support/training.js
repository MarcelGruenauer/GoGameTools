// Fisher-Yates shuffle; see https://bost.ocks.org/mike/shuffle/ and Wikipedia
function shuffle(array) {
  var m = array.length, t, i;

  // While there remain elements to shuffle...
  while (m) {

    // Pick a remaining element...
    i = Math.floor(Math.random() * m--);

    // And swap it with the current element.
    t = array[m];
    array[m] = array[i];
    array[i] = t;
  }

  return array;
}

var currentIndex;
var tsumego;

function initTraining() {
    shuffleProblems();
    tsumego = new WGo.Tsumego(document.getElementById("tsumego_wrapper"), {
        sgf: getReorientedProblem(currentIndex),
        background: "../../support/wgo.js/textures/wood2.jpg",
        stoneHandler: WGo.Board.drawHandlers.NORMAL,
    });
    setProblemData();
}

function previousProblem() {
    currentIndex = (currentIndex - 1 + problems.length) % problems.length;
    tsumego.loadSgf(getReorientedProblem(currentIndex));
    setProblemData();
}

function nextProblem() {
    currentIndex = (currentIndex + 1) % problems.length;
    tsumego.loadSgf(getReorientedProblem(currentIndex));
    setProblemData();
}

function shuffleProblems() {
    shuffle(problems);
    currentIndex = 0;
    if (tsumego !== undefined) {
        tsumego.loadSgf(getReorientedProblem(currentIndex));
        setProblemData();
    }
}

function getReorientedProblem(problemIndex) {
    let reorientedSGF = SGFGrove.stringify(
            SGFGrove.parse(problems[problemIndex].sgf).map(function(gameTree) {
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

                if (gameInfo.hasOwnProperty("C")) {
                    if (commentParts.length) commentParts.push("");
                    commentParts.push(gameInfo.C);
                }

                console.log(commentParts);
                gameInfo.C = commentParts.join("\n");

                return gameTree;
            })
    );
    console.log(reorientedSGF);
    return reorientedSGF;
}

function setProblemData() {
    var currentProblem = problems[currentIndex];

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
            link: '../by_id/' + currentProblem.id + '.html'
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

    var problemNumberDiv = document.getElementById('problem_number');
    problemNumberDiv.innerHTML = (currentIndex+1) + " of " + problems.length;
};

