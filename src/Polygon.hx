import luxe.Log;
import luxe.Visual;
import luxe.Color;
import luxe.Vector;
import luxe.Rectangle;
import luxe.utils.Maths;
import phoenix.geometry.*;
import phoenix.Batcher; //necessary to access PrimitiveType
import luxe.collision.shapes.Polygon in CollisionPoly;
import luxe.collision.ShapeDrawerLuxe;

import Type;

using utilities.VectorExtender;
using utilities.PolylineExtender;
using utilities.TransformExtender;

using Lambda;

import animation.Rigging;

class Polygon extends Visual {
	public var points:Array<Vector>;
	var bounds:Rectangle;

	//animation
	public var rigging : Rigging;

	//debug
	var sdrwr = new ShapeDrawerLuxe();

	//TODO - make new polygon from list of old polygons
	public override function new(_options:luxe.options.VisualOptions, points:Array<Vector>, ?jsonObj) {
		super(_options);

		this.points = points;

		this.rigging = new Rigging(this);

		//LISTENERS ( TODO - still not working D: )
		//pos.listen_x = listen_x;

		if (_options.scene == null) _options.scene = Luxe.scene;
		trace("SCENE " + _options.scene);


		if (jsonObj != null) {
			trace("hi!");

			if (jsonObj.name != null) {
				_options.scene.remove(this);
				name = jsonObj.name;
				_options.scene.add(this);
			}

			transform.pos = new Vector(jsonObj.pos.x, jsonObj.pos.y);

			transform.scale = new Vector(jsonObj.scale.x, jsonObj.scale.y);

			rotation_z = jsonObj.rotation;

			this.color = new Color(jsonObj.color.r, jsonObj.color.g, jsonObj.color.b, jsonObj.color.a);

			this.points = [];
			for (jp in cast(jsonObj.points, Array<Dynamic>)) {
				this.points.push(new Vector(jp.x, jp.y));
			}

			for (jc in cast(jsonObj.children, Array<Dynamic>)) {
				var child = new Polygon({batcher:_options.batcher, depth:_options.depth, parent:this}, [], jc);
			}


			//trace(jsonObj.rigging);
			this.rigging = Rigging.createFromJson(this, jsonObj.rigging);

		}

		recenter();

		trace(_options.batcher);

		if (_options.batcher == null) _options.batcher = Luxe.renderer.batcher;

		geometry = new Geometry({
			primitive_type: PrimitiveType.triangles,
			batcher: _options.batcher, //THIS MIGHT FUCK SOME SHIT UP BUT I DON'T CARE
			depth: _options.depth
		});

		generateMesh();

		
	}

	override function update(dt:Float) {
		//trace("poly update test");

		//YES trying to recreate the mesh every frame slows things down
		//noticeable at ~100, VERY noticeable over 300
		//so: could be used for special cases, but that's it
		//generateMesh();

		if (rigging.rigged()) rigging.morphMesh();
	}
	
	public function generateMesh() {
		//clear geometry (super INEFFICIENT (probably))
		var curBatcher = geometry.batchers[0]; //get current batcher?

		trace(curBatcher);

		//Luxe.renderer.batcher.remove(geometry); //switch to _options.batcher for better flexibility

		curBatcher.remove(geometry);
		geometry = new Geometry({
			primitive_type: PrimitiveType.triangles,
			batcher: curBatcher
		});

		trace("GEOM BATCHER " + geometry.batchers);

		if (points.length > 0) {
			var p2t = new org.poly2tri.VisiblePolygon();
			p2t.addPolyline(convertVectorsToPoly2TriPoints(points));
			p2t.performTriangulationOnce();

			var results = p2t.getVerticesAndTriangles();
			
			var i = 0;
			while (i < results.triangles.length) {
				for (j in i ... (i+3)) {
					var vIndex = results.triangles[j] * 3;

					var x = results.vertices[vIndex + 0];
					var y = results.vertices[vIndex + 1];
					var z = results.vertices[vIndex + 2];

					var vertex = new Vertex(new Vector(x, y, z), color);

					geometry.add(vertex);
				}

				i += 3;
			}
		}
	}

	function convertVectorsToPoly2TriPoints(vectors:Array<Vector>) : Array<org.poly2tri.Point> {
		var pointArray = [];
		for (v in vectors) {
			pointArray.push(new org.poly2tri.Point(v.x, v.y));
		}
		return pointArray;
	}

	/*
	public function scaleChildren(scaleDelta : Vector) {
		for (c in getChildrenAsPolys()) {
			//TODO fix the thing where it gets stuck at the center
			//c.pos.add(Vector.MultiplyVector(c.pos, scaleDelta));
			trace("scale");
			trace(scaleDelta);
			trace(c.pos.normalized);

			var n = c.pos.normalized;
			if (n.x < 0.01 && n.x > -0.01) n.x = 0.01;
			if (n.y < 0.01 && n.y > -0.01) n.y = 0.01;

			c.pos.add( Vector.MultiplyVector(scaleDelta, n.multiplyScalar(10)) );
			
			while (c.pos.distance(new Vector(0,0)) < 0.01) {
				c.pos.add(Vector.MultiplyVector(c.pos, scaleDelta));
			}
			
		}
	}
	*/


	/*
	override function set_scale(newScale : Vector) : Vector {
		//trace("SCALE INTERCEPT " + newScale);
		if (points.length > 0) {
			super.set_scale(newScale);
		}
		else {
			var dif = newScale.subtract(scale);
			var scaleDeltOnParent = transform.up().clone().multiplyScalar(dif.y);
			scaleDeltOnParent.add( transform.right().clone().multiplyScalar(dif.x) );
			//WORK HERE
			trace("IT'S WORKINGGGG");
			trace("PP " + scaleDeltOnParent);
			trace("p-up " + transform.up());

			for (c in getChildrenAsPolys()) {
				//c.scale = Vector.Add(c.scale, dif);

				/////
				trace("c-up " + c.transform.localUp());

				var upComp = scaleDeltOnParent.dot(c.transform.localUp());
				var rightComp = scaleDeltOnParent.dot(c.transform.localRight());

				trace("u " + upComp);
				trace("r " + rightComp);

				var scaleDeltOnChild = c.transform.localUp().clone().multiplyScalar(upComp);
				scaleDeltOnChild.add( c.transform.localRight().clone().multiplyScalar(rightComp) );

				trace("DIF " + dif);
				trace("CC " + scaleDeltOnChild);
				c.scale = Vector.Add(c.scale, scaleDeltOnChild);
				/////

				var scaleDeltOnChild = dif.clone();
				scaleDeltOnChild.applyQuaternion(c.transform.rotation);
				trace(c.transform.rotation);
				trace("CC " + scaleDeltOnChild);

				c.scale = Vector.Add(c.scale, scaleDeltOnChild);
			}
		}
		return newScale;
	}
	*/

	function calculateBounds() : Rectangle {
		//old version
		/*
		var xMin = 0.0;
		var xMax = 0.0;
		var yMin = 0.0;
		var yMax = 0.0;

		var allPoints = [];
		allPoints = allPoints.concat( points.clone() );
		for (child in children) { //ADD ALL THE POINTS ( from children )
			allPoints = allPoints.concat( cast(child, Polygon).points.clone() );
		}
		*/
		

		//new version
		var allPoints = getPoints().clone(); //clone for safety probs unecessary

		var xMin = allPoints[0].x;
		var xMax = allPoints[0].x;
		var yMin = allPoints[0].y;
		var yMax = allPoints[0].y;

		for (p in allPoints) {
			xMin = Math.min(xMin, p.x);
			xMax = Math.max(xMax, p.x);
			yMin = Math.min(yMin, p.y);
			yMax = Math.max(yMax, p.y);
		}

		var x = xMin;
		var y = yMin;
		var w = xMax - xMin;
		var h = yMax - yMin;

		return new Rectangle(x, y, w, h);
	}

	public function getRectBounds() : Rectangle {

		//this was fucked up so I'm skipping it

		//probably not the best place to put this
		/*
		bounds = calculateBounds(); //local bounds

		var pos = new Vector(bounds.x, bounds.y);
		var size = new Vector(bounds.w, bounds.h);
		pos = pos.toWorldSpace(transform);
		size = size.multiply(transform.scale); //is there a better way of doing this?
		return new Rectangle(pos.x, pos.y, size.x, size.y);
		*/

		return calculateBounds();
	}

	public function getRectCollisionBounds() : CollisionPoly {
		var r = getRectBounds();
		var cp = new CollisionPoly(0,0,
							[new Vector(r.x, r.y), new Vector(r.x + r.w, r.y),
							new Vector(r.x + r.w, r.y + r.h), new Vector(r.x, r.y + r.h)]);

		//sdrwr.drawShape(cp, new Color(1,0,0), false);

		return cp;
	}

	public function drawRectBounds() {
		var r = getRectBounds();
		//trace(r);

		Luxe.draw.rectangle({
			x : r.x,
			y : r.y,
			w : r.w,
			h : r.h,
            immediate : true,
            color : new Color(1,1,1,0.5)
		});
	}

	//REPLACE THIS WITH set_points ???
	public function setPoints(points:Array<Vector>) {
		this.points = points;
		transform.pos = new Vector(0,0);
		recenter();
		generateMesh(); //regenerate mesh whenever you change the number of points
	}

	public function getPoints(): Array<Vector> {
		//NOW INCLUDING ALL POINTS FROM CHILDREN - WHAT COULD GO WRONG????
		var worldPoints = [];
		worldPoints = worldPoints.concat(points.toWorldSpace(transform));
		
		for (child in children) {
			worldPoints = worldPoints.concat( cast(child, Polygon).getPoints() );
		}
		
		return worldPoints;
	}

	public function addPoint(p:Vector) {
		//put points back in world space to add world-space point
		points = points.toWorldSpace(transform);
		points.push(p);
		//re-center polygon
		recenter();

		generateMesh(); //regenerate mesh whenever you add a point (probably inefficient)
	}

	public function jsonRepresentation() {
		var jsonName = name;

		var jsonPos = {x: transform.pos.x, y: transform.pos.y};

		var jsonScale = {x: transform.scale.x, y: transform.scale.y};

		var jsonRotation = rotation_z;

		var jsonPoints = [];
		for (p in points) {
			jsonPoints.push({x: p.x, y: p.y});
		}

		var jsonColor = {r: color.r, g: color.g, b: color.b, a: color.a};

		var jsonChildren : Array<Dynamic> = [];
		for (child in children) {
			jsonChildren.push( cast(child, Polygon).jsonRepresentation() );
		}

		var jsonRigging = rigging.jsonRepresentation();

		return {name: jsonName, pos: jsonPos, scale: jsonScale, rotation: jsonRotation, 
			color: jsonColor, points: jsonPoints, rigging: jsonRigging, children: jsonChildren};
	}

	//should this really be public??
	public function recenter() {
		var c = points.polylineCenter();

		for (child in children) {
			c.add( child.pos );
		}
		if (children.length > 0) c.divideScalar( children.length ); //this could cause problems if the parent has any points

		transform.pos.add(c);

		points = points.toLocalSpace(transform);

		for (child in children) {
			var p = cast(child, Polygon);
			p.pos = p.pos.toLocalSpace(transform);
		}
	}

	//another attempt at the recent function, basically
	//see vertexDrag() in Main for a use case
	public function recenterLocally() {
		//var c = points.polylineCenter();

		var worldPoints = points.toWorldSpace(transform);
		var c = worldPoints.polylineCenter();
		
		if (transform.parent != null) {
			transform.pos = c.toLocalSpace(parent.transform);
		}
		else {
			transform.pos = c;
		}	
		//transform.pos.add(c);

		points = worldPoints.toLocalSpace(transform);
	}

	public function collisionBounds() : CollisionPoly {
		var worldPoints = getPoints().map( function(p) { return p.subtract(pos); } );
		return worldPoints.collisionShape(transform.pos);
	}

	//group depth
	override function set_depth(depth : Float) : Float {

		if(geometry != null) {
            geometry.depth = depth;
        } //geometry

		for (child in children) {
			cast(child, Visual).depth = depth;
		}
		return depth;
	}

	/*
	override function set_pos(pos : Vector) : Vector {
		//super.set_pos(pos);
		trace("set_pos");
		return pos;
		Vector.Listen()
	}
	*/

	function listen_x(change : Float) : Void {
		trace("pos change " + change);
	}

	public function getChildrenAsPolys() : Array<Polygon> {
		var polyList : Array<Polygon> = [];
		for (c in children) {
			if (Std.is(c, Polygon)) { //only get polygons
				polyList.push(cast(c, Polygon));
			}
		}
		return polyList;
	}

	override function ondestroy() {
		super.ondestroy();

		for ( p in getChildrenAsPolys()) {
			p.destroy();
		}

		Luxe.scene.remove(this);
	}
}