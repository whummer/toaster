
var graphXOffset = 50;
var graphYOffset = 30;
var graphXDistance = 150;
var graphYDistance = 60;

var nodeWidth = 80;
var nodeHeight = 20;

//var graphEngine = "wireit";
var graphEngine = "jsPlumb";

/** 
 * Provide a JSON document of the following form:
 * 
 * {
 *	"nodes" : [ 
 * 		{ "ID" : "n1", "name" : "Node 1" },
 * 		{ "ID" : "n2", "name" : "Node 2" },
 * 		{ "ID" : "n3", "name" : "Node 3" }
 *	],
 * 
 * 	"edges" : [ 
 * 		{ "from" : "n1", "to" : "n2", "label" : "Edge 1", "short_label" : "e1", "href" : "http://..." },
 * 		{ "from" : "n1", "to" : "n3", "label" : "Edge 2", "short_label" : "e2", "href" : "http://..."  }
 * 	]
 * }
 * 
 */
function loadGraph(graphJSON) {

	if(!graphJSON)
		return;

	var nodes = Array();
	var nodeIDs = Array();
	var wires = Array();
	var errors = Array();
	var i = 0;

	var nodesJSON = graphJSON["nodes"];
	if(typeof(nodesJSON) == "undefined" || !nodesJSON) {
		throw "The graph does not contain any nodes. Probably the generation was aborted because the graph would have grown too big for rendering in the Web browser.";
	}
	for(i = 0; i < nodesJSON.length; i++) {
		var node = nodesJSON[i];
		var id = node["ID"];

		nodeIDs.push(id);
		nodes[id] = new Object(); 
		nodes[id]["name"] = node["name"]; 
		nodes[id]["from"] = new Array();
		nodes[id]["to"] = new Array();
		nodes[id]["content"] = node["content"].replace(/\n/g,"\n<br/>");
		nodes[id]["column"] = node["column"];
		nodes[id]["row"] = 0;
	
	}

	if(nodesJSON.length > 50) {
		if(!confirm("Graph contains " + nodesJSON.length + " nodes, do you want to start rendering?")) {
			return;
		}
	}

	var edgesJSON = graphJSON["edges"];
	for(i = 0; i < edgesJSON.length; i++) {
		var edge = edgesJSON[i];
		
		var from = edge["from"];
		var to = edge["to"];
		var label_short = edge["label_short"];
		var label = edge["label"];
		var href = edge["href"];
		
		// TODO: better construct object instead of Array..
		var wire = new Array(from, to, label_short, label, href);
		nodes[from]["to"].push(to);
		nodes[to]["from"].push(from);
		wires.push(wire);
	}

	getNodePositions(nodes, nodeIDs);

	if(graphEngine == "wireit") {
		drawGraphWireit(nodeIDs, nodes, wires);
	} else if(graphEngine == "jsPlumb") {
		cont = $("#graphContainer");
		drawGraphJSPlumb(cont, nodeIDs, nodes, wires);
	}
}

function drawGraphJSPlumb(container, nodeIDs, nodes, wires) {

	var color = "gray";

	jsPlumb.importDefaults({
		// notice the 'curviness' argument to this Bezier curve.  the curves on this page are far smoother
		// than the curves on the first demo, which use the default curviness value.			
		//Connector : [ "Bezier", { curviness: 20 } ],
		DragOptions : { cursor: "pointer", zIndex:2000 },
		PaintStyle : { strokeStyle:color, lineWidth:2 },
		EndpointStyle : { radius:0, fillStyle:color },
		HoverPaintStyle : {strokeStyle:"#ec9f2e" },
		EndpointHoverStyle : {fillStyle:"#ec9f2e" }
	});
	
	var connector = {			
		connector: [ "Bezier", { curviness: 20 } ],
		endpoint: "Blank",
		anchor: "AutoDefault"
	};
	

	for(var i = 0; i < nodeIDs.length ; i++) {
		var id = nodeIDs[i];
		var node = nodes[id];
		node["containerId"] = i;

		var x = graphXOffset + (graphXDistance * (node["column"] - 1));
		var y = graphYOffset + (graphYDistance * (node["row"] - 1));

		if(id == "__start__") {
			container.append("<div class=\"component window jsPlumbNodeInitial\" id=\"" + id + "\">" +
					"<img src=\"media/initial_state.gif\"/>" +
				"</div>");
		} else if(id == "__end__") {
			container.append("<div class=\"component window jsPlumbNodeFinal\" id=\"" + id + "\">" +
					"<img src=\"media/final_state.gif\"/>" +
				"</div>");
		} else {
			container.append("<div class=\"component window jsPlumbNode\" id=\"" + id + "\">" +
					"<div class=\"nodeName\">" + node["name"] + "</div>" +
					"<div class=\"nodeContent\">" + (node["content"] ? node["content"] : "") + "<br/><br/><br/></div>" +
				"</div>");
			$("#" + id).resizable();
		}
		
		$("#" + id).css("left", x);
		$("#" + id).css("top", y);

	}
	
	for(var i = 0 ; i < wires.length ; i++) {
		var wc = wires[i];
		var label_short = wc[2];
		var label = wc[3];
		var href = wc[4];
		var wireID = "edgeText" + i;

		overlays = [["PlainArrow", {
			location:1, width:10, length:12
		}]];
		
		if(label_short != "") {
			var theLabel = "<div id=\"tip_" + wireID + "\"><div class=\"edgeLabelText\">" + label_short + "</div>" + 
				"<div style=\"display:none;\" id=\"tiptext_" + wireID + "\" class=\"edgeTooltip\">Task " + 
				label_short + ":<br/><a href=\"" + href + "\">" + label + "</a></div>" + 
			"</div>";
			overlays.push(["Label", {
				cssClass:"edgeLabel",
				label : theLabel, 
				location: 0.5,
				events:{
					"click": function(label, evt) {}
				}
			}]);
		}

		jsPlumb.connect(connector, {
			source: wc[0],
			target: wc[1],
			overlays: overlays,
		});

		if(label_short != "") {
			$("#tip_" + wireID).mouseover(function() {
		        $($(this).children(".edgeTooltip")[0]).show();
			});
			$("#tip_" + wireID).mouseout(function() {
		        $($(this).children(".edgeTooltip")[0]).hide();
			});
		}

	}

	// double click on any connection 
	//jsPlumb.bind("dblclick", function(connection, originalEvent) { alert("double click on connection from " + connection.sourceId + " to " + connection.targetId); });

	// make divs draggable
	//$(".jsPlumbNode").draggable();
	jsPlumb.draggable(jsPlumb.getSelector(".jsPlumbNode"), {handle: ".nodeName"});
	jsPlumb.draggable(jsPlumb.getSelector(".jsPlumbNodeInitial"));
	jsPlumb.draggable(jsPlumb.getSelector(".jsPlumbNodeFinal"));

}

function drawGraphWireit(nodeIDs, nodes, wires) {
	wireit_containers = {};
	wireit_wires = new Array();
	
	g = function(Y) {
		var layerEl = Y.one('#graphContainer');
		var mygraphic = new Y.Graphic({render: "#graphContainer"});

		for(var i = 0; i < nodeIDs.length ; i++) {
			var id = nodeIDs[i];
			var node = nodes[id];
			node["containerId"] = i;

			var x = graphXOffset + (graphXDistance * (node["column"] - 1));
			var y = graphYOffset + (graphYDistance * (node["row"] - 1));

			container = addGraphNode(Y, layerEl, node["name"], node["content"], x, y)
			wireit_containers[id] = container;
		}
		
		for(var i = 0 ; i < wires.length ; i++) {
			var wc = wires[i];
			var srcCont = wireit_containers[wc[0]]
			var tgtCont = wireit_containers[wc[1]]

			edge = addGraphEdge(Y, mygraphic, srcCont, tgtCont)
			wireit_wires.push(edge);
		}
		
	}

	YUI({filter: 'raw'}).use('image-container', 'container', 'arrow-wire', 
			'bezier-wire', 'straight-wire', 'inputex-group', 'json', g);

}


function graphOnNodeSelect(event) {
	
}

function addGraphNode(Y, layerEl, name, content, x, y) {

	c = new Y.Container({
		children: [
			{ align: {points:["tl", "lc"]}, offset: [0,0], dir: [-0.3, -0.0], name: 'lc', editable: false },
			{ align: {points:["tl", "rc"]}, offset: [0,0], dir: [0.3, -0.0], name: 'rc', editable: false },
			{ align: {points:["tl", "tl"]}, offset: [0,0], dir: [-0.2, -0.1], name: 'lt', editable: false },
			{ align: {points:["tl", "tr"]}, offset: [0,0], dir: [0.2, -0.1], name: 'rt', editable: false }
		],
		type: 'Container',
		width: nodeWidth,
		height: nodeHeight,
		xy: [x, y],
		icons: {},
		headerContent: name,
		//bodyContent: "<div style=\"width: 100%; height: 100%; overflow: auto;\">" + content + "</div>",
		bodyContent: content,
		zIndex: 5,
		render: layerEl,
		fillHeight: true
	});

	return c
}

function addGraphEdge(Y, mygraphic, srcCont, tgtCont) {

	  var wire = mygraphic.addShape({
	     type: (srcCont == tgtCont) ? Y.BezierWire : Y.BezierWire,
	     stroke: {
	         weight: 4,
	         color: "rgb(173,216,230)" 
	     },
	     label: "wire",
	     labelContent: "wire",
	     src: (srcCont == tgtCont) ? srcCont.item(3) : srcCont.item(1),
	     tgt: (srcCont == tgtCont) ? tgtCont.item(2) : tgtCont.item(0)
	  });
	  wire._draw();
}

function getNodePositions(nodes, nodeIDs) {

	var unProccessedIDs = nodeIDs;

	var values = { maxRow: 0, usedCells: [], unProccessedIDs: nodeIDs }

	var index;
	
	hasRoot = false;
	for(var i = 0; i < unProccessedIDs.length; i ++) {
		var id = unProccessedIDs[i];
		var node = nodes[id];

		//starting nodes without dependencies
		if ((node["from"].length) == 0) {
			hasRoot = true;
			getNodePosRecursive(nodes, node, 1, values.maxRow + 1, values, new Array());
		}
	}
	if(nodeIDs.length > 0 && !hasRoot) {
		alert("Warning: Graph contains a cycle.");
	}
}

function getNodePosRecursive(nodes, node, column, row, values, path_so_far) {

	startRow = -1;
	endRow = row;
	thisRow = row;

	//process only new nodes
	if (node["row"] == 0) {

		for (var i = 0; i < node["to"].length; i++) {
			var nextNode = nodes[ node["to"][i] ];
			var childRow = 1
			if(!path_so_far.contains(nextNode)) {
				path_so_far.push(nextNode);
				childRow = getNodePosRecursive(nodes, nextNode, nextNode["column"], 1, values, path_so_far);
			}
			startRow = (startRow < 0 || childRow < startRow) ? childRow : startRow;
			endRow = childRow > endRow ? childRow : endRow;
		}

		startRow = (startRow < 0) ? 1 : startRow;
		thisRow = startRow + ((endRow - startRow) / 2);
		thisRow = Math.floor(thisRow)
		//alert(startRow + "," + endRow + " - " + (endRow - startRow))
		if((endRow - startRow) <= 1)
			thisRow = startRow;

		positionOK = false
		while(!positionOK) {
			positionOK = true;
			for(var i = 0; i < values.usedCells.length; i ++) {
				if(values.usedCells[i].row == thisRow && values.usedCells[i].column == column) {
					positionOK = false;
					thisRow += 1;
				}
			}
		}

		//node["column"] = column;
		node["row"] = thisRow;

		values.usedCells.push({ "row" : thisRow, "column" : column })

	}
	return node["row"];
}

function estimateMaxSubTreeWith(node, nodesMap, seenNodes) {
	total = 1;
	if(!seenNodes)
		seenNodes = new Array();
	if (seenNodes.contains(node)) {
		alert("Looks like the graph contains a cycle - already saw node " + inspect(node));
		return result;
	}
	if (!seenNodes.contains(node)) {
		seenNodes.push(node);
	}
	for (var i = 0; i < node["to"].length; i++) {
		child = nodesMap[ node["to"][i] ]
		seenNodesCopy = seenNodes.slice(0) // make copy
		total += estimateMaxSubTreeWith(child, nodesMap, seenNodesCopy);
	}
	return total;
}

function getMaxDescendantBreadth(nodes, nodesMap) {
	max = 0;
	seenNodes = []
	while(nodes.length > 0) {
		nodes = getDescendants(nodes, seenNodes, nodesMap);
		if(nodes.length > max)
			max = nodes.length;
	}
	return max;
}

function getDescendants(nodeList, seenNodes, nodesMap) {
	result = new Array();
	for (var i = 0; i < nodeList.length; i++) {
		node = nodeList[i];
		if (seenNodes.contains(node)) {
			alert("Looks like the graph contains a cycle, already saw node " + node);
			return result;
		}
	}
	for (var i = 0; i < nodeList.length; i++) {
		node = nodeList[i];
		if (!seenNodes.contains(node)) {
			seenNodes.push(node);
		}
		for (var j = 0; j < node["to"].length; j++) {
			nextNode = nodesMap[ node["to"][j] ];
			if (!result.contains(nextNode)) {
				result.push(nextNode);
			}
		}
	}
	return result;
}

function inspect(obj) {
	res = "";
	for(i in obj) {
		res += i + " = " + obj[i];
		res += "\n";
	}
	return res;
}

Array.prototype.contains = function(obj) {
    var i = this.length;
    while (i--) {
        if (this[i] === obj) {
            return true;
        }
    }
    return false;
}

Array.prototype.contains_equal = function(obj) {
    var i = this.length;
    while (i--) {
        if (this[i] == obj) {
            return true;
        }
    }
    return false;
}

function indexOf(someArray,someValue) {
	var i = 0;
	for(i in someArray) {
		if(someArray[i] == someValue)
			return i;
	}
	return -1;
}
