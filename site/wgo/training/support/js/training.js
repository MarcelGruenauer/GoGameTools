/**
 * Tsumego (go problems) viewer for WGo.js.
 * It requires files: wgo.js, player.js, sgfparser.js, kifu.js
 */

const EV_UNKNOWN = -1;
const EV_WRONG = 0;
const EV_CORRECT = 1;

var config = {};

// copied from wgo/sgfparser.js
function to_num(str, i) { return str.charCodeAt(i)-97; }

// add support for LN.

WGo.SGF.properties["LN"] = function(kifu, node, value, ident) {
    node.addMarkup({
        x: to_num(value[0],0),
        y: to_num(value[0],1),
        x1: to_num(value[0],3),
        y1: to_num(value[0],4),
        type: "LN"
    });
};

// adapted from Board.drawHandlers.LB. LN draws on the grid layer.
WGo.Board.drawHandlers.LN = {
    grid: {
        draw: function(args, board) {
            if(!args._nodraw) {
                var xr  = board.getX(args.x),
                    yr  = board.getY(args.y),
                    x1r = board.getX(args.x1),
                    y1r = board.getY(args.y1);

                this.beginPath();
                this.lineWidth = 10;
                this.moveTo(xr, yr);
                this.lineTo(x1r, y1r);
                this.stroke();
            }
        },
        clear: function(args, board) {
            args._nodraw = true;
            board.redraw();
            delete args._nodraw;
        }
    }
};


(function(WGo){

"use strict";

// decide whether variation is good or bad
let evaluate_variation_rec = function(node) {
    let tmp, val = 0;

    if(node.children.length) {
        // node has descendants
        for(var i = 0; i < node.children.length; i++) {
            // extract the best variation
            tmp = evaluate_variation_rec(node.children[i]);
            if(tmp > val) val = tmp;
        }
    }
    else {
        // node is a leaf
        if(node.GB) val = EV_CORRECT;
        else if(node.GW) val = EV_CORRECT;
    }

    // store in the node as integer
    node._ev = val;

    return val;
}

let get_coordinates = function(sgf_cords) {
    return [sgf_cords.charCodeAt(0)-97, sgf_cords.charCodeAt(1)-97];
}

// function extending board clicks
let board_click = function(x,y) {
    // if(this.frozen || this.turn != this.kifuReader.game.turn || this.kifuReader.node.children.length == 0 || !this.kifuReader.game.isValid(x, y)) return;
    if(this.frozen || !this.kifuReader.game.isValid(x, y)) return;
    this.kifuReader.node.appendChild(new WGo.KNode({
        move: {
            x: x,
            y: y,
            c: this.kifuReader.game.turn
        },
        _ev: EV_UNKNOWN,
        _edited: 1    // _edited nodes will be removed on undo(), q.v.
    }));
    this.next(this.kifuReader.node.children.length-1);
}

/**
 * Class containing logic for tsumego mode (backend).
 */
let TsumegoApi = WGo.extendClass(WGo.Player, function(config) {
    this.config = config;

    // add default configuration of TsumegoApi
    for(var key in TsumegoApi.default) if(this.config[key] === undefined && TsumegoApi.default[key] !== undefined) this.config[key] = TsumegoApi.default[key];

    // add default configuration of Player class
    for(var key in WGo.Player.default) if(this.config[key] === undefined && WGo.Player.default[key] !== undefined) this.config[key] = WGo.Player.default[key];

    // create element with board - it can be inserted to DOM
    this.boardElement = document.getElementById("tsumego");

    this.board = new WGo.Board(this.boardElement, this.config);

    // Player object has to contain element.
    this.element = this.element || this.boardElement;

    this.upper_left = [0,0];
    this.lower_right = [18,18];

    this.init();
    this.board.addEventListener("click", board_click.bind(this));
    this.listeners.variationEnd = [];
    this.listeners.nextMove = [];
    // this.listeners.variationEnd = [function(e){console.log(e)}];
    // this.listeners.nextMove = [function(e){console.log(e)}];
});


/**
 * Overrides loading of kifu, we must decide correct and incorrect variations and whose turn it is.
 */
TsumegoApi.prototype.loadKifu = function(kifu, path) {
    // analyze kifu
    if(kifu.root.children.length && kifu.root.children[0].move) {
        this.turn = kifu.root.children[0].move.c;
    }
    else {
        console.log("invalid kifu");
    }

    for(var i = 0; i < kifu.root.children.length; i++) {
        evaluate_variation_rec(kifu.root.children[i]);
    }

    this.kifu = kifu;
    this.kifuReader = new WGo.KifuReader(this.kifu, this.config.rememberPath, this.config.allowIllegalMoves);

    // fire kifu loaded event
    this.dispatchEvent({
        type: "kifuLoaded",
        target: this,
        kifu: this.kifu,
    });

    this.update("init");

    if(path) {
        this.goTo(path);
    }

    // execute VW property
    if(kifu.info.VW) {
        let cords = kifu.info.VW.split(":");

        this.upper_left = get_coordinates(cords[0]);
        this.lower_right = get_coordinates(cords[1]);

        let upper_left = [this.upper_left[0], this.upper_left[1]];
        let lower_right = [this.lower_right[0], this.lower_right[1]];

        if(this.coordinates) {
            if(this.upper_left[0] == 0) upper_left[0] = -0.5;
            if(this.upper_left[1] == 0) upper_left[1] = -0.5;
            if(this.lower_right[0] == 18) lower_right[0] = 18.5;
            if(this.lower_right[1] == 18) lower_right[1] = 18.5;
        }

        this.board.setSection(upper_left[1], this.board.size-1-lower_right[0], this.board.size-1-lower_right[1], upper_left[0]);
    }
}

/**
 * Overrides player's next() method. We must play 1 extra move
 */
TsumegoApi.prototype.next = function(i) {
    if(this.frozen || !this.kifu || this.kifuReader.node.children.length == 0) return;

    try {
        this.kifuReader.next(i);
        this.playSound();
        this.update();

        this.dispatchEvent({
            type: "nextMove",
            target: this,
            node: this.kifuReader.node,
            evaluation: this.kifuReader.node._ev
        });

        if(this.kifuReader.node.move.c == this.turn && this.kifuReader.node.children.length) {
            let _this = this;
            window.setTimeout(function(){
                if(_this.kifuReader.node.move.c == _this.turn) {
                    try {
                        _this.kifuReader.next(0);
                        _this.playSound();
                        _this.update();
                    }
                    catch(err) {
                        console.log(err);
                        _this.error(err);
                        return;
                    }

                    if(_this.kifuReader.node.children.length == 0) {
                        _this.dispatchEvent({
                            type: "variationEnd",
                            target: _this,
                            node: _this.kifuReader.node,
                            evaluation: _this.kifuReader.node._ev
                        });
                    }
                }
            }, this.config.answerDelay);
        }
        else if(this.kifuReader.node.children.length == 0) {
            this.dispatchEvent({
                type: "variationEnd",
                target: this,
                node: this.kifuReader.node,
                evaluation: this.kifuReader.node._ev
            });
        }
    }
    catch(err) {
        this.error(err);
    }
}

TsumegoApi.prototype.setCoordinates = function(b) {
    if(!this.coordinates && b) {
        let upper_left = [this.upper_left[0], this.upper_left[1]];
        let lower_right = [this.lower_right[0], this.lower_right[1]];

        if(this.upper_left[0] == 0) upper_left[0] = -0.5;
        if(this.upper_left[1] == 0) upper_left[1] = -0.5;
        if(this.lower_right[0] == 18) lower_right[0] = 18.5;
        if(this.lower_right[1] == 18) lower_right[1] = 18.5;

        this.board.setSection(upper_left[0], this.board.size-1-lower_right[0], this.board.size-1-lower_right[1], upper_left[1]);
        this.board.setWidth(this.board.width);
        this.board.addCustomObject(WGo.Board.coordinates);
    }
    else if(this.coordinates && !b) {
        this.board.setSection(this.upper_left[0], this.board.size-1-this.lower_right[0], this.board.size-1-this.lower_right[1], this.upper_left[1]);
        this.board.removeCustomObject(WGo.Board.coordinates);
    }
    this.coordinates = b;
}

let sounds, stoneSoundIndex;

TsumegoApi.prototype.playSound = function() {
    if (sounds === undefined) {
        sounds = [
            new Howl({ src: [url_for_support_dir() + 'sounds/play0.mp3'] }),
            new Howl({ src: [url_for_support_dir() + 'sounds/play1.mp3'] }),
            new Howl({ src: [url_for_support_dir() + 'sounds/correct.mp3'] }),
            new Howl({ src: [url_for_support_dir() + 'sounds/wrong.mp3'] }),
        ];
        stoneSoundIndex = 0;
    }

    const node = this.kifuReader.node;

    if (node._ev == EV_CORRECT && node.children.length == 0) {
        sounds[2].play();
    } else if (node._ev == EV_UNKNOWN && node.parent && node.parent._ev != EV_UNKNOWN) {
        sounds[3].play();
    } else {
        sounds[stoneSoundIndex].play();
    }
    stoneSoundIndex = 1 - stoneSoundIndex;  // alternate stone sounds
}

TsumegoApi.default = {
    movePlayed: undefined, // callback function of move played by a player
    endOfVariation: undefined, // callback function for end of a variation (it can be solution of the problem or incorrect variation)
    answerDelay: 500, // delay of the answer (in ms)
    enableWheel: false, // override player's setting
    lockScroll: false, // override player's setting
    enableKeys: true, // override player's setting
    rememberPath: false, // override player's setting
    displayVariations: false, // override player's setting
}

WGo.TsumegoApi = TsumegoApi;

/**
 * Simple front end for TsumegoApi. It provides all html but isn't very adjustable.
 */
let Tsumego = WGo.extendClass(WGo.TsumegoApi, function(elem, config) {
    this.element = elem;

    this.super.call(this, config);

    // add default configuration of Tsumego
    for(var key in Tsumego.default) if(config[key] === undefined && Tsumego.default[key] !== undefined) this.config[key] = Tsumego.default[key];

    let board_el = document.getElementById("tsumego");

    // Tocca.js
    board_el.addEventListener('swipeleft',  function(e) { nextProblem(); });
    board_el.addEventListener('swiperight', function(e) { previousProblem(); });

    // no scrolling inside the board
    // board_el.addEventListener('touchmove', function(e) { e.preventDefault(); });

    this.shuffleButton = document.getElementById("shuffle-btn");
    this.shuffleButton.addEventListener("click", orderProblemsRandomly.bind(this));

    this.treeOrderButton = document.getElementById("tree-order-btn");
    this.treeOrderButton.addEventListener("click", orderProblemsByTree.bind(this));

    this.prevButton = document.getElementById("prev-btn");
    this.prevButton.addEventListener("click", previousProblem.bind(this));

    this.nextButton = document.getElementById("next-btn");
    this.nextButton.addEventListener("click", nextProblem.bind(this));

    this.retryButton = document.getElementById("retry-btn");
    this.retryButton.addEventListener("click", this.reset.bind(this));

    this.undoButton = document.getElementById("undo-btn");
    this.undoButton.addEventListener("click", this.undo.bind(this));

    this.hintButton = document.getElementById("hint-btn");
    this.hintButton.addEventListener("click", this.hint.bind(this));

    this.listeners.update.push(this.updateTsumego.bind(this));
    this.listeners.variationEnd.push(this.variationEnd.bind(this));

    this.commentBox = document.getElementById("tsumego-comment");
    window.addEventListener("resize", this.updateDimensions.bind(this));

    // show variations
    if(this.config.debug) {
        this.variationLetters = [];
        this.listeners.update.push(this.showVariations.bind(this));
    }

    this.initGame();

    this.updateDimensions();
});

Tsumego.prototype.updateTsumego = function(e) {
    if(e.node.comment) {
        this.setComment(WGo.filterHTML(e.node.comment));
        this.addCommentClass('comment');
    } else {
        this.setComment("", "");
        this.removeCommentClasses();
    }

    // Unicode medium black or white circle
    document.getElementById('color-to-play').innerHTML = (this.turn == WGo.B ? "&#x26AB;" : "&#x26AA;");

    // disable the "Hint" button if there are only 'edited' children nodes
    if(e.node.children.length > 0 && e.node.children.filter(node => !node.edited)) this.hintButton.disabled = "";
    else this.hintButton.disabled = "disabled";

    if(!e.node.parent) {
        this.retryButton.disabled = "disabled";
        this.undoButton.disabled = "disabled";
    }
    else {
        this.retryButton.disabled = "";
        this.undoButton.disabled = "";
    }
}

Tsumego.prototype.setComment = function(msg) {
    let formatted = msg.replace(new RegExp('\n', 'g'), "<br />");
    formatted = formatted.replace(new RegExp("'([A-Z])'", 'g'), "<em>$1</em>");
    this.commentBox.innerHTML = formatted;
}

Tsumego.prototype.addCommentClass = function(className) {
    this.commentBox.classList.add(className);
}

Tsumego.prototype.removeCommentClasses = function() {
    this.commentBox.className = '';
}

Tsumego.prototype.reset = function() {
    // If the user adds 'edited' moves after the 'correct' variation end, then
    // resets the problem, the player would respond with the 'edited' moves. So
    // first undo any 'edited' moves.
    while (this.kifuReader.node._edited) {
        this.previous();
        this.kifuReader.node.children =
            this.kifuReader.node.children.filter(node => !node._edited);
    }
    this.first();
}

Tsumego.prototype.undo = function() {
    let edited = this.kifuReader.node._edited;
    this.previous();
    if (edited) {
        // remove all 'edited' nodes - well, there should only be one
        this.kifuReader.node.children =
            this.kifuReader.node.children.filter(node => !node._edited);
        this.update();   // for the "Hint" button
    } else if (this.kifuReader.node.move && this.kifuReader.node.move.c == this.turn) {
        // This branch implies _edited was not set; when editing,
        // we don't want to undo the opponent's move as well.
        this.previous();
    }
}

Tsumego.prototype.hint = function(e) {
    for(var i in this.kifuReader.node.children) {
        if(this.kifuReader.node.children[i]._ev == EV_CORRECT) {
            this.next(i);
            return;
        }
    }
    this.setComment('Already wrong variation. Retry.');
}

Tsumego.prototype.variationEnd = function(e) {
    if(!e.node.comment) {
        switch(e.node._ev){
            case EV_WRONG: this.setComment('Wrong. Retry.'); break;
            case EV_CORRECT: this.setComment('Correct.'); break;
            default: this.setComment('Wrong. Retry.'); break;
        }
    }

    switch(e.node._ev){
        case EV_WRONG: this.addCommentClass('incorrect'); break;
        case EV_CORRECT: this.addCommentClass('correct'); break;
        default: this.addCommentClass('unknown'); break;
    }
}

Tsumego.prototype.showVariations = function(e) {
    // remove old variations
    this.board.removeObject(this.variationLetters);

    // show variations
    this.variationLetters = [];
    for(var i = 0; i < e.node.children.length; i++) {
        if(e.node.children[i].move && e.node.children[i].move.c == this.turn && !e.node.children[i].move.pass) this.variationLetters.push({
            type: "LB",
            text: String.fromCharCode(65+i),
            x: e.node.children[i].move.x,
            y: e.node.children[i].move.y,
            c: e.node.children[i]._ev == EV_CORRECT ? "rgba(0,128,0,0.8)" : "rgba(196,0,0,0.8)"
        });
    }
    this.board.addObject(this.variationLetters);
}

// Set right width of board.
Tsumego.prototype.updateDimensions = function() {
    this.board.setWidth(document.getElementById("tsumego").offsetWidth);
}

const KEY_ARROW_LEFT = 37;
const KEY_ARROW_UP   = 38;
const KEY_ARROW_RIGHT= 39;

Tsumego.prototype.setKeys = function(b) {
    var that = this;
    if(b) {
        document.onkeydown = function(e) {
            switch(e.keyCode){
                case KEY_ARROW_LEFT: previousProblem(); break;
                case KEY_ARROW_RIGHT: nextProblem(); break;
                case KEY_ARROW_UP: that.undo(); break;
                default: return true;
            }
            if(e.preventDefault) e.preventDefault()
        };
    }
    else {
        document.onkeydown = null;
    }
}

// Tsumego viewer settings
Tsumego.default = {
    debug: false
}

WGo.Tsumego = Tsumego;

})(WGo);


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

function url_for_collection_by_id(id) {
    return '/training-module-collection?collection=by_collection_id/' + id;
}

function url_for_collection_by_filter (filter) {
    return '/training-module-collection?collection=by_filter/' + filter;
}

function url_for_problem_by_id(problem_id) {
    let sub_dir = problem_id.substring(0, 2);
    return '/training-module-collection?collection=by_problem_id/' + sub_dir + '/' + problem_id;
}

function url_for_support_dir() {
    return '/training/support/';
}

/*

The collection page is called like
"http://gogamespace.com/training-module-collection/?collection=by_filter/attach_and_crosscut"

The code uses the value of the "collection" query parameter and reads the JSON
file that contains the collection. Upon success it sets some titles and
initiates the training code.

*/

let tsumego, urlParams;

function initTraining() {
    urlParams = new URLSearchParams(window.location.search);
    const url = "/training/collections/" + urlParams.get('collection') + ".json";
    fetch(url)
        .then(function(response) {
            return response.json();
        })
        .then(function(data) {
            config = data;
            initLayout();
            initSubsets();
            orderProblemsRandomly();

            // Don't use images for background and stoneHandler so that the canvas can
            // render on mobile devices that have canvas size limits
            tsumego = new WGo.Tsumego(document.getElementById("tsumego"), {
                sgf: getReorientedProblem(config.currentIndex),
                background: "#DAB575",
                stoneHandler: WGo.Board.drawHandlers.MONO,
            });
            tsumego.updateDimensions();

            setProblemData();
        })
}

function initLayout() {
    document.getElementById('collection-section').innerHTML = config.section;
    document.getElementById('collection-topic').innerHTML = config.topic;
}

// The user gets the full problem collection if there are no subsets or there
// is no subset id in the query string or there is no subset with that id.
function initSubsets() {
    if (config.subsets !== undefined) {
        let wantedSubset = urlParams.get('subset');

        // If there are subsets but there is no subset query parameter, the
        // user gets the first subset, which is assumed to be the 'All'
        // quasi-subset.
        if (!wantedSubset) wantedSubset = config.subsets[0].id;

        let subset = config.subsets.find(s => s.id == wantedSubset);
        if (subset !== undefined) {
            var remainingProblems = config.problems;

            // for every problem: Does any ref start with the wanted ref?
            if (subset.with_ref) {
                remainingProblems = remainingProblems.filter(problem =>
                    problem.refs.find(ref => ref.startsWith(subset.with_ref))
                );
            }

            if (subset.without_ref) {
                remainingProblems = remainingProblems.filter(problem =>
                    !problem.refs.find(ref => ref.startsWith(subset.without_ref))
                );
            }

            if (subset.with_tag) {
                remainingProblems = remainingProblems.filter(problem =>
                    problem.tags.includes(subset.with_tag)
                );
            }

            if (subset.without_tag) {
                remainingProblems = remainingProblems.filter(problem =>
                    !problem.tags.includes(subset.without_tag)
                );
            }

            if (remainingProblems.length > 0) {
                config.activeProblems = remainingProblems;
                config.activeSubset = wantedSubset;
            }
        }
    }
    if (config.activeProblems === undefined) {
        config.activeProblems = config.problems;
    }
}

function previousProblem() {
    config.currentIndex = (config.currentIndex - 1 + config.activeProblems.length) % config.activeProblems.length;
    loadProblemForIndex(config.currentIndex);
}

function nextProblem() {
    config.currentIndex = (config.currentIndex + 1) % config.activeProblems.length;
    loadProblemForIndex(config.currentIndex);
}

function orderProblemsRandomly() {
    shuffle(config.activeProblems);
    config.currentIndex = 0;
    if (tsumego !== undefined) loadProblemForIndex(config.currentIndex);
}

function orderProblemsByTree() {
    config.activeProblems = config.activeProblems.sort( (a,b) => a.order - b.order );
    config.currentIndex = 0;
    if (tsumego !== undefined) loadProblemForIndex(config.currentIndex);
}

function loadProblemForIndex(problemIndex) {
    tsumego.loadSgf(getReorientedProblem(problemIndex));
    setProblemData();
}

function getReorientedProblem(problemIndex) {
    let reorientedSGF = SGFGrove.stringify(
        SGFGrove.parse(config.activeProblems[problemIndex].sgf).map(function(gameTree) {

            // Don't reorient permalinks; users should be able to discuss coordinates

            if (!window.location.href.includes('by_problem_id')) {

                // Don't swap colors for full-screen problems, especially real
                // games and fuseki. These trees should have the #game tag.
                let shouldSwapColors = config.activeProblems[problemIndex].topics.includes("game")
                    ? false : Math.random() < 0.5;

                SGFReorienter()
                .mirrorHorizontally(Math.random() < 0.5)
                .mirrorVertically(Math.random() < 0.5)
                .swapAxes(Math.random() < 0.5)
                .swapColors(shouldSwapColors)
                .reorientGameTree(gameTree);
            }


            /* If MN[-1] is present, don't show whose turn it is to play.
               This is useful for tasks such as questions, rating
               choices, showing choices and tsumego status problems; in
               these problems the user is not supposed to play a move
               as Black or White; the intersection to be played is
               simply the impetus to show the answer.

               gameTree[0] are the nodes; [1] are the descendant game trees
               Then the game info node is the first node.
             */

            let gameInfo = gameTree[0][0];
            let gameInfoParts = [];

            if (gameInfo.hasOwnProperty("PW")) {
                let giWhite = gameInfo.PW;
                if (gameInfo.hasOwnProperty("WR")) {
                    giWhite += " (" + gameInfo.WR + ")";
                }
                gameInfoParts.push("White: " + giWhite);
            }

            if (gameInfo.hasOwnProperty("PB")) {
                let giBlack = gameInfo.PB;
                if (gameInfo.hasOwnProperty("BR")) {
                    giBlack += " (" + gameInfo.BR + ")";
                }
                gameInfoParts.push("Black: " + giBlack);
            }

            if (gameInfo.hasOwnProperty("DT")) {
                gameInfoParts.push("Date: " + gameInfo.DT);
            }

            if (gameInfo.hasOwnProperty("KM")) {
                gameInfoParts.push("Komi: " + gameInfo.KM);
            }

            if (gameInfo.hasOwnProperty("RE")) {
                gameInfoParts.push("Result: " + gameInfo.RE);
            }

            if (gameInfo.hasOwnProperty("EV")) {
                gameInfoParts.push("Event: " + gameInfo.EV);
            }

            if (gameInfo.hasOwnProperty("RO")) {
                gameInfoParts.push("Round: " + gameInfo.RO);
            }

            if (gameInfo.hasOwnProperty("PC")) {
                gameInfoParts.push("Place: " + gameInfo.PC);
            }

            if (config.activeProblems[problemIndex].hasOwnProperty("metadata")) {
                metadataString = JSON.stringify(config.activeProblems[problemIndex].metadata, metadataReplacer, 2);
                if (metadataString !== '{}') {
                    gameInfoParts.push("<pre>", metadataString, "</pre>");
                }
            }

            if (gameInfo.hasOwnProperty("GC")) {
                gameInfoParts.push('');    // newline
                gameInfoParts.push(gameInfo.GC.replace(/(?:\r\n|\r|\n)/g, '<br>'));
            }

            let gameInfoDiv = document.getElementById('game-info');
            gameInfoDiv.innerHTML = gameInfoParts.map(x => x + "<br />").join("\n");

            return gameTree;
        })
    );
    return reorientedSGF;
}

// shorten book filenames so they don't squash the Go board
const bookRegExp = new RegExp('^books/(.+/)*');
function metadataReplacer(name, val) {
    if (name === 'filename') {
        return val.replace(bookRegExp, 'book: ');
    } else {
        return val;
    }
}

function setProblemData() {
    setProblemRelatedCollections();
    setProblemSubsets();

    let currentProblem = config.activeProblems[config.currentIndex];
    document.getElementById('problem-number').innerHTML = (config.currentIndex+1) + " / " + config.activeProblems.length;
    if (currentProblem.problem_id !== undefined) {
        let permalink = url_for_problem_by_id(currentProblem.problem_id);
        document.getElementById('permalink').innerHTML = '<a href="' + permalink + '">Permalink</a>';
    }
}

function setProblemRelatedCollections() {
    let currentProblem = config.activeProblems[config.currentIndex];

    // Each problem has a list of topics that it occurs in. These are
    // numeric indices into the topicIndex.

    let relatedData = currentProblem.topics
        .map(function(el) {
            let entry = topicIndex[el];
            entry.link = url_for_collection_by_filter(entry.filename);
            return entry;
        })
        .sort(function(a, b) {
            if (a.html < b.html) return -1;
            if (a.html > b.html) return 1;
            return 0;
        });

    // Show a link if the current problem has more than one - i.e., the
    // currently shown - variation in the SGF tree that it came from.

    let related_positions = currentProblem.related_positions;
    if (related_positions > 1) {
        relatedData.unshift({
            text: 'Same tree',
            count: related_positions,
            link: url_for_collection_by_id(currentProblem.collection_id)
        });
    }

    let related_ul = document.getElementById('related');
    related_ul.innerHTML = '';

    relatedData.forEach(function(el) {
        li = document.createElement('li');

        // Sometimes the full collection name is too long and might break the
        // layout; the user can set a different 'rel_text' key instead.
        let displayText = el.rel_text;
        if (displayText === undefined) {
            displayText = el.text;
        }

        li.innerHTML = '<a href=' + el.link + '>' + displayText + ' (' + el.count + ')</a>';

        related_ul.appendChild(li);
    });
}

function setProblemSubsets() {
    let currentProblem = config.activeProblems[config.currentIndex];
    let subsets_ul = document.getElementById('subsets');
    subsets_ul.innerHTML = '';

    if (config.subsets === undefined) {
        li = document.createElement('li');
        li.innerHTML = 'None';
        subsets_ul.appendChild(li);
    } else {
        var currentURL = window.location.protocol + "//" + window.location.host + window.location.pathname;
        config.subsets.forEach(function(el) {
            li = document.createElement('li');
            urlParams.set('subset', el.id);
            li.innerHTML =
                '<a href=' + currentURL + '?' + urlParams.toString() + '>' +
                el.text + ' (' + el.count + ')</a>';
            if (el.id == config.activeSubset) li.classList.add("active");
            subsets_ul.appendChild(li);
        });
    }
}
