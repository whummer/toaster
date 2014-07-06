function initTree(containerID, jsonData) {
	$("#" + containerID).jstree({
		"plugins" : [ 
			"themes","json_data","ui","crrm","cookies","dnd","search","types","hotkeys","contextmenu" 
		],
		"json_data" : { 
			"data" : prepareTreeNode(jsonData)
		}
	})
}

function prepareTreeNode(node, newParent, depth) {
	if(!depth) depth = 0;
	
	if(!newParent) {
		var root = new Object();
		root["children"] = new Array();
		root["data"] = "root";
		root["state"] = "open";
		return prepareTreeNode(node, root, depth);
	}

	var numChildren = 0;
	for(i in node) {
		numChildren ++;
		var newNode = new Object();
		newNode["metadata"] = new Object();
		newNode["metadata"]["propName"] = i;
		if (typeof node[i] == 'object'){
			newNode["data"] = i;
			newNode["children"] = new Array();
			prepareTreeNode(node[i], newNode, depth+1);
		} else {
			var value = node[i];
			value = value.length > 50 ? (value.substring(0,50) + " [...]") : value;
			newNode["data"] = i + " = " + value;
			newNode["metadata"]["propValue"] = node[i];
		}
		if(depth < 2) {
			newNode["state"] = "open";
		}
		if(newParent) {
			if(!newParent["children"]) {
				newParent["children"] = new Array();
			}
			newParent["children"].push(newNode);
		}
	}
	if(numChildren <= 0) {
		newParent["children"] = null;
	}
	return newParent;
}
