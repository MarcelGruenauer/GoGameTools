/**
 * Tsumego (go problems) viewer for WGo.js.
 * It requires files: wgo.js, player.js, sgfparser.js, kifu.js
 */

const EV_UNKNOWN = -1;
const EV_WRONG = 0;
const EV_DOUBTFUL = 1; // not entirely incorrect
const EV_INTERESTING = 2; // not the best one but correct solution
const EV_CORRECT = 3;

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
        if(node.DO) val = EV_DOUBTFUL;
        else if(node.IT) val = EV_INTERESTING;
        else if(node.GB) val = EV_CORRECT;
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
    this.boardElement = document.createElement("div");

    this.board = new WGo.Board(this.boardElement, this.config);

    // Player object has to contain element.
    this.element = this.element || this.boardElement;

    this.upper_left = [0,0];
    this.lower_right = [18,18];

    this.init();
    this.board.addEventListener("click", board_click.bind(this));
    this.listeners.variationEnd = [function(e){console.log(e)}];
    this.listeners.nextMove = [function(e){console.log(e)}];
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
            new Howl({ src: ['../../support/sounds/play0.mp3'] }),
            new Howl({ src: ['../../support/sounds/play1.mp3'] }),
            new Howl({ src: ['../../support/sounds/correct.mp3'] }),
            new Howl({ src: ['../../support/sounds/wrong.mp3'] }),
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

let generate_dom = function() {
    // clean up
    this.element.innerHTML = "";

    // main wrapper
    this.wrapper = document.createElement("div");
    this.wrapper.className = "wgo-tsumego";
    this.element.appendChild(this.wrapper);

    // board center part
    this.center = document.createElement("div");
    this.wrapper.appendChild(this.center);
    this.center.appendChild(this.boardElement);
    this.board.setWidth(this.center.offsetWidth);

    // Tocca.js.
    this.center.addEventListener('swipeleft',  function(e) { previousProblem(); });
    this.center.addEventListener('swiperight', function(e) { nextProblem(); });

    // no scrolling inside the board
    this.center.addEventListener('touchmove', function(e) { e.preventDefault(); });

    // bottom part
    this.bottom = document.createElement("div");
    this.bottom.className = "wgo-tsumego-bottom";
    this.wrapper.appendChild(this.bottom);

        // control panel
        this.controlPanel = document.createElement("div");
        this.controlPanel.className = "wgo-tsumego-control";
        this.bottom.appendChild(this.controlPanel);

            // shuffle button
            this.shuffleWrapper = document.createElement("div");
            this.shuffleWrapper.className = "wgo-tsumego-btnwrapper";
            this.controlPanel.appendChild(this.shuffleWrapper);

            this.shuffleButton = document.createElement("button");
            this.shuffleButton.className = "wgo-tsumego-btn";
            this.shuffleButton.innerHTML = "Shuffle";
            this.shuffleButton.addEventListener("click", shuffleProblems.bind(this));
            this.shuffleWrapper.appendChild(this.shuffleButton);

            // prev button
            this.prevWrapper = document.createElement("div");
            this.prevWrapper.className = "wgo-tsumego-btnwrapper";
            this.controlPanel.appendChild(this.prevWrapper);

            this.prevButton = document.createElement("button");
            this.prevButton.className = "wgo-tsumego-btn";
            this.prevButton.innerHTML = "Prev";
            this.prevButton.addEventListener("click", previousProblem.bind(this));
            this.prevWrapper.appendChild(this.prevButton);

            // next button
            this.nextWrapper = document.createElement("div");
            this.nextWrapper.className = "wgo-tsumego-btnwrapper";
            this.controlPanel.appendChild(this.nextWrapper);

            this.nextButton = document.createElement("button");
            this.nextButton.className = "wgo-tsumego-btn";
            this.nextButton.innerHTML = "Next";
            this.nextButton.addEventListener("click", nextProblem.bind(this));
            this.nextWrapper.appendChild(this.nextButton);

            // reset button
            this.resetWrapper = document.createElement("div");
            this.resetWrapper.className = "wgo-tsumego-btnwrapper";
            this.controlPanel.appendChild(this.resetWrapper);

            this.resetButton = document.createElement("button");
            this.resetButton.className = "wgo-tsumego-btn";
            this.resetButton.innerHTML = "Retry";
            this.resetButton.addEventListener("click", this.reset.bind(this));
            this.resetWrapper.appendChild(this.resetButton);

            // previous button
            this.undoWrapper = document.createElement("div");
            this.undoWrapper.className = "wgo-tsumego-btnwrapper";
            this.controlPanel.appendChild(this.undoWrapper);

            this.undoButton = document.createElement("button");
            this.undoButton.className = "wgo-tsumego-btn";
            this.undoButton.innerHTML = "Undo";
            this.undoButton.addEventListener("click", this.undo.bind(this));
            this.undoWrapper.appendChild(this.undoButton);

            // hint button
            this.hintWrapper = document.createElement("div");
            this.hintWrapper.className = "wgo-tsumego-btnwrapper";
            if(this.config.displayHintButton) this.controlPanel.appendChild(this.hintWrapper);

            this.hintButton = document.createElement("button");
            this.hintButton.className = "wgo-tsumego-btn";
            this.hintButton.innerHTML = "Hint";
            this.hintButton.addEventListener("click", this.hint.bind(this));
            this.hintWrapper.appendChild(this.hintButton);

        // comment box below buttons
        this.comment = document.createElement("div")
        this.comment.className = "wgo-tsumego-comment";
        this.bottom.appendChild(this.comment);

}

/**
 * Simple front end for TsumegoApi. It provides all html but isn't very adjustable.
 */
let Tsumego = WGo.extendClass(WGo.TsumegoApi, function(elem, config) {
    this.element = elem;

    this.super.call(this, config);

    // add default configuration of Tsumego
    for(var key in Tsumego.default) if(config[key] === undefined && Tsumego.default[key] !== undefined) this.config[key] = Tsumego.default[key];

    generate_dom.call(this);

    this.listeners.update.push(this.updateTsumego.bind(this));
    this.listeners.variationEnd.push(this.variationEnd.bind(this));

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
    if(e.node.comment) this.setInfo(WGo.filterHTML(e.node.comment));
    else this.setInfo("&nbsp;");  // ensure comment box is >= 1 line high

    let toPlayDiv = document.getElementById('color_to_play');
    toPlayDiv.innerHTML = (this.turn == WGo.B ? "Black" : "White")+" to play";

    // disable the "Hint" button if there are only 'edited' children nodes
    if(e.node.children.length > 0 && e.node.children.filter(node => !node.edited)) this.hintButton.disabled = "";
    else this.hintButton.disabled = "disabled";

    if(!e.node.parent) {
        this.resetButton.disabled = "disabled";
        this.undoButton.disabled = "disabled";
    }
    else {
        this.resetButton.disabled = "";
        this.undoButton.disabled = "";
    }

    this.setClass();
}

Tsumego.prototype.setInfo = function(msg) {
    let formatted = msg.replace(new RegExp('\n', 'g'), "<br />");
    formatted = formatted.replace(new RegExp("'([A-Z])'", 'g'), "<em>$1</em>");
    this.comment.innerHTML = formatted;
}

Tsumego.prototype.setClass = function(className) {
    this.wrapper.className = "wgo-tsumego"+(className ? " "+className : "");
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
        if(this.kifuReader.node.children[i]._ev == 3) {
            this.next(i);
            return;
        }
    }
    this.setInfo("Already wrong variation. Retry.");
}

Tsumego.prototype.variationEnd = function(e) {
    if(!e.node.comment) {
        switch(e.node._ev){
            case EV_WRONG: this.setInfo("Wrong. Retry."); break;
            case EV_DOUBTFUL: this.setInfo("There is a better way. Retry."); break;
            case EV_INTERESTING: this.setInfo("Correct, but there is a better move."); break;
            case EV_CORRECT: this.setInfo("Correct."); break;
            default: this.setInfo("Wrong. Retry."); break;
        }
    }

    switch(e.node._ev){
        case EV_WRONG: this.setClass("wgo-tsumego-incorrect"); break;
        case EV_DOUBTFUL: this.setClass("wgo-tsumego-doubtful"); break;
        case EV_INTERESTING: this.setClass("wgo-tsumego-interesting"); break;
        case EV_CORRECT: this.setClass("wgo-tsumego-correct"); break;
        default: this.setClass("wgo-tsumego-unknown"); break;
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

/**
 * Set right width of board.
 */

Tsumego.prototype.updateDimensions = function() {
    this.board.setWidth(this.center.offsetWidth);
}

const KEY_ARROW_LEFT = 37;
const KEY_ARROW_UP   = 38;
const KEY_ARROW_RIGHT= 39;
const KEY_ARROW_DOWN = 40;
const KEY_R          = 82;

Tsumego.prototype.setKeys = function(b) {
    var that = this;
    if(b) {
        document.onkeydown = function(e) {
            switch(e.keyCode){
                case KEY_ARROW_LEFT: previousProblem(); break;
                case KEY_ARROW_RIGHT: nextProblem(); break;
                case KEY_ARROW_UP: that.undo(); break;
                //case 40: this.selectAlternativeVariation(); break;
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
    displayHintButton: true,
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

let currentIndex, tsumego;

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

                let gameInfoDiv = document.getElementById('game_info');
                gameInfoDiv.innerHTML = gameInfoParts.map(x => x + "<br />").join("\n");

                return gameTree;
            })
    );
    return reorientedSGF;
}

function setProblemData() {
    let currentProblem = problems[currentIndex];

    // Each problem has a list of topics that it occurs in. These are
    // numeric indices into the topicIndex.

    let relatedData = currentProblem.topics
        .map(function(el) {
            let entry = topicIndex[el];
            entry.link = "../by_filter/" + entry.filename + ".html";
            return entry;
        })
        .sort(function(a, b) {
            if (a.html < b.html) return -1;
            if (a.html > b.html) return 1;
            return 0; });

    // Show a link if the current problem has more than one - i.e., the
    // currently shown - variation in the SGF tree that it came from.

    let related_positions = currentProblem.related_positions;
    if (related_positions > 1) {
        relatedData.unshift({
            text: 'Same tree',
            count: related_positions,
            link: '../by_id/' + currentProblem.id + '.html'
        });
    }

    let related_ul = document.getElementById('related');
    related_ul.innerHTML = '';

    relatedData.forEach(function(el) {
        li = document.createElement('li');

        let text = '';
        if (el.group) {
            text = el.group + ' ';
        }
        li.innerHTML = text + '<a href=' + el.link + '>' + el.text + ' (' + el.count + ')</a>';

        related_ul.appendChild(li);
    });

    let problemNumberDiv = document.getElementById('problem_number');
    problemNumberDiv.innerHTML = (currentIndex+1) + " of " + problems.length;
};

