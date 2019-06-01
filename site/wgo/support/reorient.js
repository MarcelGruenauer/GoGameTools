/* Perform traversal on gameTree
   gameTree = [
       [{Node}, {Node}, ..., {Node}],
       [[GameTree], [GameTree], ..., [GameTree]]
    ]
*/
traverseGameTree = function(gameTree, callback) {
    gameTree[0].forEach(callback);
    gameTree[1].forEach(function(child) {
        traverseGameTree(child, callback);
    });
};

function SGFReorienter() {
    var mirrorHorizontally = false;
    var mirrorVertically   = false;
    var swapAxes           = false;
    var swapColors         = false;

    var my = {};

    // getters and setters

    my.mirrorHorizontally = function(value) {
        if (!arguments.length) { return mirrorHorizontally; }
        mirrorHorizontally = value;
        return my;
    };

    my.mirrorVertically = function(value) {
        if (!arguments.length) { return mirrorVertically; }
        mirrorVertically = value;
        return my;
    };

    my.swapAxes = function(value) {
        if (!arguments.length) { return swapAxes; }
        swapAxes = value;
        return my;
    };

    my.swapColors = function(value) {
        if (!arguments.length) { return swapColors; }
        swapColors = value;
        return my;
    };

    /* The actual worker.

        // parse() => [collection of GameTree objects]
        newSGF = SGFGrove.stringify(
            SGFGrove.parse(sgf).map(my.reorientGameTree)
        );
    */

    my.reorientGameTree = function(gameTree) {
        traverseGameTree(gameTree, function(node) {
            if (my.swapAxes()) {
                my._swapAxes(node);
            }
            if (my.mirrorHorizontally()) {
                my._mirrorHorizontally(node);
            }
            if (my.mirrorVertically()) {
                my._mirrorVertically(node);
            }
            if (my.swapColors()) {
                my._swapColors(node);
            }
        });
        return gameTree;
    };

    // helper methods

    my._replaceUsingMap = function(s, obj) {
        var re = new RegExp("\\b(" + Object.keys(obj).join("|") + ")\\b", "g");
        return s.replace(re ,function(match) { return obj[match] });
    };

    my._reorientPoints = function(node, f) {
        [ "B", "W" ].forEach(function(prop) {
            // don't call the function for B[] or W[]
            if (node.hasOwnProperty(prop) && node[prop] !== null) {
                node[prop] = f(node[prop]);
            }
        });
        [ "AB", "AE", "AW", "CR", "DD", "MA", "SL", "SQ", "TB", "TR", "TW" ].forEach(function(prop) {
            if (node.hasOwnProperty(prop)) {
                node[prop] = node[prop].map(f);
            }
        });
        [ "LB" ].forEach(function(prop) {
            if (node.hasOwnProperty(prop)) {
                node[prop] = node[prop].map(function(el) { return [ f(el[0]), el[1] ] });
            }
        });
        [ "AR", "LN", "VW" ].forEach(function(prop) {
            if (node.hasOwnProperty(prop)) {
                node[prop] = node[prop].map(function(el) { return [ f(el[0]), f(el[1]) ] });
            }
        });
    };

    /* This differs from
           [ node.B, node.W ] = [ node.W, node.B ]
       in that it doesn't leave undefined values if one or both properties
       don't exist.
    */
    my._swapProperties = function(node, propA, propB) {
        var temp = {};
        if (node.hasOwnProperty(propA)) { temp[propB] = node[propA]; }
        if (node.hasOwnProperty(propB)) { temp[propA] = node[propB]; }
        delete node[propA];
        delete node[propB];
        if (temp.hasOwnProperty(propA)) { node[propA] = temp[propA]; }
        if (temp.hasOwnProperty(propB)) { node[propB] = temp[propB]; }
    };

    my._swapColors = function(node) {
        my._swapProperties(node, "B",  "W");
        my._swapProperties(node, "AB", "AW");
        my._swapProperties(node, "GB", "GW");
        my._swapProperties(node, "OB", "OW");
        my._swapProperties(node, "TB", "TW");
        my._swapProperties(node, "BT", "WT");
        my._swapProperties(node, "BL", "WL");

        if (node.hasOwnProperty("PL")) {
            node.PL = my._replaceUsingMap(node.PL, {
                "B" : "W",
                "W" : "B"
            });
        }
        if (node.hasOwnProperty("C")) {
            node.C = my._replaceUsingMap(node.C, {
                "black": "white",
                "white": "black",
                "Black": "White",
                "White": "Black"
            });
        }
    };

    my._swapAxes = function(node) {
        my._reorientPoints(node, function(p) {
            x = p.charAt(0);
            y = p.charAt(1);
            return y + x;
        });

        if (node.hasOwnProperty("C")) {
            node.C = my._replaceUsingMap(node.C, {
                "upper right corner" : "lower left corner",
                "lower left corner"  : "upper right corner",
                "left side"          : "upper side",
                "right side"         : "lower side",
                "upper side"         : "left side",
                "lower side"         : "right side"
            });
        }
    };

    my._mirrorHorizontally = function(node) {
        my._reorientPoints(node, function(p) {
            // a-s => s-a
            x = String.fromCharCode(115 + 97 - p.charCodeAt(0));
            y = p.charAt(1);
            return x + y;
        });

        if (node.hasOwnProperty("C")) {
            node.C = my._replaceUsingMap(node.C, {
                "upper left corner"  : "upper right corner",
                "upper right corner" : "upper left corner",
                "lower left corner"  : "lower right corner",
                "lower right corner" : "lower left corner",
                "left side"          : "right side",
                "right side"         : "left side"
            });
        }
    };

    my._mirrorVertically = function(node) {
        my._reorientPoints(node, function(p) {
            x = p.charAt(0);
            // a-s => s-a
            y = String.fromCharCode(115 + 97 - p.charCodeAt(1));
            return x + y;
        });

        if (node.hasOwnProperty("C")) {
            node.C = my._replaceUsingMap(node.C, {
                "upper left corner"  : "lower left corner",
                "upper right corner" : "lower right corner",
                "lower left corner"  : "upper left corner",
                "lower right corner" : "upper right corner",
                "upper side"         : "lower side",
                "lower side"         : "upper side"
            });
        }
    };

    return my;
}
