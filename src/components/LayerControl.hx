package components;

import components.EditorComponent;
import luxe.Component;
import luxe.Vector;
import luxe.Color;
import luxe.Input.MouseEvent;
import luxe.Rectangle;
import luxe.Visual;
import phoenix.geometry.RectangleGeometry;
import phoenix.geometry.CircleGeometry;
import luxe.utils.Maths;

import luxe.collision.Collision;
import luxe.collision.shapes.Polygon in CollisionPoly;

using ledoux.UtilityBelt.VectorExtender;

class LayerControl extends EditorComponent {

	var polygon : Polygon;
	var bounds : Rectangle;

	var isSelectingLayer : Bool;
	var isMovingLayer : Bool;
	var isGrouping : Bool;
	
	var thumbnailPoly : Polygon; 
	var groupHandle : Visual;
	var enterGroupHandle : Visual;

	var closestLayerToGroupHandle : Int;

	override function init() {
		polygon = cast entity;
		bounds = polygon.getRectBounds();

		//create extra geometry
		groupHandle = new Visual({
			pos: new Vector(bounds.x - 15, bounds.y),
			color: new Color(0,1,0),
			batcher: Main.instance.uiSceneBatcher,
			depth: 2000,
			immediate: false,
			geometry: Luxe.draw.circle({r:10})
		});

		enterGroupHandle = new Visual({
			pos: new Vector(bounds.x + bounds.w + 110, bounds.y),
			color: new Color(1,0,1),
			batcher: Main.instance.uiSceneBatcher,
			depth: 2000,
			immediate: false,
			geometry: Luxe.draw.circle({r:15})
		});
	}

	override function update(dt : Float) {
		var numLayers = Main.instance.layers.getNumLayers();

		var i = 0;

		for (h in layerLineHeights()) {

			var isSelectedLayer = (i == Main.instance.curLayer);
			var isSelectedGroup = ( isGrouping && 
									((closestLayerToGroupHandle > Main.instance.curLayer 
										&& i <= closestLayerToGroupHandle && i > Main.instance.curLayer) || 
									(closestLayerToGroupHandle < Main.instance.curLayer 
										&& i >= closestLayerToGroupHandle && i < Main.instance.curLayer)) );
			var c = (isSelectedLayer || isSelectedGroup) ? new Color(255,255,0) : new Color(255,255,255);

			Luxe.draw.line({
				p0: new Vector(bounds.x, h),
				p1: new Vector(bounds.x + bounds.w, h),
				immediate: true,
				color: c,
				depth: 1000,
				//batcher: Luxe.renderer.batcher
				batcher: Main.instance.uiSceneBatcher
			});

			i++;
		}
	}

	override function onmousedown(e : MouseEvent) {

		if (e.pos.distance(groupHandle.pos) < 15) {
			isGrouping = true;
		}
		if ( Collision.pointInPoly(e.pos, polygon.getRectCollisionBounds()) ) {
			selectLayerWithCursor(e.pos.y);
			isSelectingLayer = true;
		}
		else if ( thumbnailPoly != null && Collision.pointInPoly(e.pos, thumbnailPoly.getRectCollisionBounds()) ) {
			isMovingLayer = true;
		}
	}

	override function onmousemove(e : MouseEvent) {
		if (isGrouping) {
			moveGroupingSelector(e.pos.y);
		}
		if ( isSelectingLayer ) {
			selectLayerWithCursor(e.pos.y);
		}
		else if (isMovingLayer) {
			moveLayerWithCursor(e.pos.y);
		}
	}

	override function onmouseup(e : MouseEvent) {
		if (isMovingLayer && e.pos.y > bounds.y + bounds.h) {
			trace("delete layer");
			var curP = Main.instance.curPoly();
			Edit.RemoveLayer(Main.instance.layers, 0);
		}
		else if (isGrouping && closestLayerToGroupHandle != Main.instance.curLayer) {
			mergeGroup();
		}

		isSelectingLayer = false;
		isMovingLayer = false;
		isGrouping = false;
	}

	function mergeGroup() {

		var groupLayer = cast(Math.min(closestLayerToGroupHandle, Main.instance.curLayer), Int);

		var polysInGroup = [];
		var i = 0;
		for (l in Main.instance.layers.layers) {

			var isSelectedGroup = ( i == Main.instance.curLayer || 
									((closestLayerToGroupHandle > Main.instance.curLayer 
										&& i <= closestLayerToGroupHandle && i > Main.instance.curLayer) || 
									(closestLayerToGroupHandle < Main.instance.curLayer 
										&& i >= closestLayerToGroupHandle && i < Main.instance.curLayer)) );
			

			if (isSelectedGroup) {
				polysInGroup.push(l);
			}

			i++;

		}

        var parentPoly = new Polygon({}, []);

		for (childPoly in polysInGroup) {
			Main.instance.layers.removeLayer(childPoly);
			childPoly.parent = parentPoly;
		}

		parentPoly.recenter();

		Main.instance.layers.addLayer(parentPoly, groupLayer);

		Main.instance.switchLayerSelection(groupLayer);
	}

	function moveGroupingSelector(cursorHeight:Float) {
		var clampedHeight = Maths.clamp(cursorHeight, bounds.y, bounds.y + bounds.h);
		groupHandle.pos.y = clampedHeight;
		closestLayerToGroupHandle = findClosestLayer(groupHandle.pos.y);
	}

	function moveLayerWithCursor(cursorHeight:Float) {
		var clampedHeight = Maths.clamp(cursorHeight, bounds.y, bounds.y + bounds.h);

		thumbnailPoly.pos.y = clampedHeight;

		var closestLayer = findClosestLayer(clampedHeight);
		if (closestLayer != Main.instance.curLayer) {
			
			//THIS DIDN'T WORK (ok, it sorta works --- why???)
			/*
			var curP = Main.instance.curPoly();
			Main.instance.layers.removeLayer(curP);
			Main.instance.layers.addLayer(curP, closestLayer);
			*/

			var curP = Main.instance.curPoly();
			if (Main.instance.curLayer < closestLayer) {
				while (Main.instance.curLayer != closestLayer) {
					Edit.MoveLayer(Main.instance.layers, Main.instance.curLayer, 1);
					Main.instance.switchLayerSelection(1);
				}
			}
			else {
				while (Main.instance.curLayer != closestLayer) {
					Edit.MoveLayer(Main.instance.layers, Main.instance.curLayer, -1);
					Main.instance.switchLayerSelection(-1);
				}
			}
			



			//THIS CAUSES BUGS IF YOU MOVE THE LAYER TOO FAST
			//but it also sort of works?
			//Main.instance.layers.swapLayers(Main.instance.curLayer, closestLayer);

			Main.instance.goToLayer( closestLayer );
		}
	}

	function findClosestLayer(targetHeight:Float) : Int {
		var i = 0;
		var closestLayer = 0;
		var heights = layerLineHeights();
		for (h in heights) {
			var closestDist = Math.abs(targetHeight - heights[closestLayer]);
			var testDist = Math.abs(targetHeight - h);

			if (testDist < closestDist) {
				closestLayer = i;
			}

			i++;
		}
		return closestLayer;
	}

	function selectLayerWithCursor(cursorHeight:Float) {
		//FIND CLOSEST LAYER
		var closestLayer = findClosestLayer(cursorHeight);

		//SELECT LAYER
		Main.instance.goToLayer(closestLayer);

		//CREATE THUMBNAIL
		if (thumbnailPoly != null) {

			//THIS NEEDS TO BE REFACTORED BRO
			Main.instance.uiSceneBatcher.remove(thumbnailPoly.geometry);
			for (c in thumbnailPoly.children) {
				Main.instance.uiSceneBatcher.remove( cast(c, Visual).geometry );
			}
		}

		var thumbWidth = 100;
		thumbnailPoly = new Polygon({batcher: Main.instance.uiSceneBatcher, depth: 2000}, [],
										Main.instance.curPoly().jsonRepresentation());

		var heights = layerLineHeights();
		thumbnailPoly.pos.y = heights[closestLayer];
		thumbnailPoly.pos.x = bounds.x + bounds.w + thumbWidth/2;

		var scaleRatio = thumbnailPoly.getRectBounds().w / thumbWidth;
		thumbnailPoly.scale = thumbnailPoly.scale.divideScalar(scaleRatio);

		groupHandle.pos.y = heights[closestLayer];
		enterGroupHandle.pos.y = heights[closestLayer];
	}

	//from lowest to highest
	function layerLineHeights() : Array<Float> {
		var heights : Array<Float> = [];
		var numLayers = Main.instance.layers.getNumLayers();
		for (i in 0 ... numLayers) {
			var curH = bounds.y + (bounds.h * ( 1 - ((i+1) / (numLayers+1)) ) );
			heights.push(curH);
		}
		return heights;
	}

}