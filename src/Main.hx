//LUXE
import luxe.Input;
import luxe.Log;
import luxe.Visual;
import luxe.Color;
import luxe.Vector;
import luxe.utils.Maths;
import phoenix.geometry.*;
import phoenix.Batcher;
import luxe.States;
import luxe.collision.Collision;
import luxe.collision.ShapeDrawerLuxe;
import luxe.collision.shapes.Circle in CollisionCircle;
import luxe.collision.shapes.Polygon in CollisionPoly;
import luxe.utils.Maths;
import snow.types.Types;

//HAXE
//IOS hack

import sys.io.File;
import sys.io.FileOutput;
import sys.io.FileInput;


//ARL
/*
import Polyline;
import Polygon;
import ColorPicker;
import Slider;
import Edit;
import LayerManager;
*/
import animation.Bone;

using ledoux.UtilityBelt.VectorExtender;
using ledoux.UtilityBelt.PolylineExtender;
using ledoux.UtilityBelt.TransformExtender;

class Main extends luxe.Game {

	//drawing
	var curLine : Polyline;
	var minLineLength = 20;
	public var isDrawing : Bool;

	//layers
	var layers = new LayerManager(0, 1, 1000);
	var aboveLayersDepth = 10001;
	var curLayer = 0;
	public var selectedLayerOutline : Polyline;

	//color picker
	var picker : ColorPicker;
	var slider : Slider;
	var curColorIcon : QuadGeometry;
	var colorList : Array<ColorHSV> = [];
	var colorIndex : Int;

    //editting
    var dragMouseStartPos : Vector;
    var selectedVertex : Int;
    var scaleDirLocal : Vector;
    var scaleDirWorld : Vector;

    //ui
    public var uiBatcher : Batcher;

    //states
    var machine : States;

    //collisions
    var polyCollision : CollisionPoly;

    //play mode and components
    var componentManager = new ComponentManager();

    //camera and zoom
    var refSize = new Vector(960, 640);

    override function ready() {
        trace(Luxe.screen.size);
        trace(Luxe.camera.center);
        trace(Luxe.screen.mid);

    	//instantiate objects
        selectedLayerOutline = new Polyline({depth: aboveLayersDepth}, []);

        //render settings
        Luxe.renderer.batcher.layer = 1;
        Luxe.renderer.clear_color = new ColorHSV(0, 0, 0.2);
        Luxe.renderer.state.lineWidth(2);

        //UI
        createUI();  

        //STATES
        machine = new States({name:"statemachine"});
        machine.add(new DrawState({name:"draw"}));
        machine.add(new PickColorState({name:"pickcolor"}));
        machine.add(new EditState({name:"edit"}));
        machine.add(new AnimationState({name:"animation"}));
        machine.add(new PlayState({name:"play"}));
        machine.set("draw", this);

        //HACK TO LOAD TEST LEVEL IMMEDIATELY
        /*
        Luxe.loadJSON("assets/prototype5.json", function(j) {
            var inObj = j.json;

            for (l in cast(inObj.layers, Array<Dynamic>)) {
                Edit.AddLayer(layers, new Polygon({}, [], l), curLayer+1);
                switchLayerSelection(1);
            }

            Luxe.loadJSON("assets/prototype5_components.json", function(j) {
                var inObj = j.json;
                componentManager.updateFromJson(inObj);

                machine.set("play", this);
            });
        });
        */
    } //ready

    override function onkeydown(e:KeyEvent) {
    }

    override function onkeyup(e:KeyEvent) {
        if(e.keycode == Key.escape) {
            Luxe.shutdown();
        }
    } //onkeyup

    override function update(dt:Float) {

    } //update

    override function onmousedown(e:MouseEvent) {
    }

    override function onmousemove(e:MouseEvent) {
    }

    override function onmouseup(e:MouseEvent) {
    }

    override function onwindowresized(e:WindowEvent) {
        //Luxe.camera.viewport.w = e.event.x;
        //Luxe.camera.viewport.h = e.event.y;
        
        //trace(e.event.x);
        //trace(Luxe.screen.w);
        //trace(Luxe.camera.pos);


        var tmp = Luxe.camera.center.clone();
        Luxe.camera.size = Luxe.screen.size.clone();
        trace(Luxe.screen.mid);
        trace(Luxe.camera.center);
        //Luxe.camera.center = tmp;
        trace(Luxe.camera.center);

        

        Luxe.camera.zoom = Luxe.screen.size.y / refSize.y;
        Luxe.camera.pos = Vector.Subtract(Luxe.screen.size, Vector.Multiply(refSize, 1 / Luxe.camera.zoom));


        //trace(Luxe.camera.viewport);
        //Luxe.camera.center = Luxe.screen.mid.clone();
    }

    function createUI () {
        //separate batcher to layer UI over drawing space
        uiBatcher = Luxe.renderer.create_batcher({name:"uiBatcher", layer:2});

        //UI
        picker = new ColorPicker({
            scale : new Vector(Luxe.screen.h/4,Luxe.screen.h/4), /*separate radius from scale??*/
            pos : new Vector(Luxe.screen.w/2,Luxe.screen.h/2),
            batcher : uiBatcher
        });

        slider = new Slider({
            size : new Vector(10, Luxe.screen.h * 0.5),
            pos : new Vector(Luxe.screen.w * 0.8, Luxe.screen.h/2),
            batcher: uiBatcher
        });

        curColorIcon = Luxe.draw.box({w: 30, h: 30, x: 0, y: 0, batcher: uiBatcher});
        curColorIcon.color = picker.pickedColor;

        //UI events
        slider.onSliderMove = function() {
            picker.setV(slider.value);
        };

        picker.onColorChange = function() {
            slider.setOutlineHue(picker.pickedColor.h);
        };

        //turn off color picker
        colorPickerMode(false);
    }

    function addColorToList(c:ColorHSV) {
    	colorList.push(c.clone());
    	colorIndex = colorList.length-1; //move back to top of the list
    	//add something to tie this function to the color picker? (force color picker to switch colors for example)
    }

    function navigateColorList(dir:Int) {
    	colorIndex += dir;
    	if (colorIndex < 0) colorIndex = 0;
    	if (colorIndex >= colorList.length) colorIndex = colorList.length-1;

    	var c = colorList[colorIndex];

    	picker.pickedColor = c;
    	slider.value = c.v;
    }

    function colorPickerMode(on:Bool) {
    	picker.visible = on;
    	slider.visible = on;
    }

    function switchLayerSelection(dir:Int) {
    	curLayer += dir;

    	if (curLayer < 0) curLayer = 0;
    	if (curLayer >= layers.getNumLayers()) curLayer = layers.getNumLayers()-1;

    	if (layers.getNumLayers() > 0) {	
            var poly : Polygon = cast(layers.getLayer(curLayer), Polygon);

            //close loop
	    	var loop = poly.getPoints();
	    	var start = loop[0];
            loop.push(start);

            selectedLayerOutline.setPoints(loop);

            polyCollision = poly.collisionBounds();
    	}
    	else {
	    	selectedLayerOutline.setPoints([]);
    	}
    }

    function addPointToCurrentLine(p:Vector) {
    	curLine.addPoint(p);

    	var test = curLine.getPoints().polylineIntersections();

        if (test.intersects) {

    		var newPolylines = curLine.getPoints().polylineSplit(test.intersectionList[0]);
            var newPolygon = new Polygon({color: curLine.color}, newPolylines.closedLine);
    		
            Edit.AddLayer(layers, newPolygon, curLayer+1);
    		
            switchLayerSelection(1);

    		//remove drawing line
    		endDrawing();
    	}
    }

    function endDrawing() {
		Luxe.renderer.batcher.remove(curLine.geometry);
		curLine = null;
		isDrawing = false;
    }

    public function startLayerDrag(mousePos) : Bool {
        mousePos = Luxe.camera.screen_point_to_world(mousePos);
        if (Collision.pointInPoly(mousePos, polyCollision)) {
            dragMouseStartPos = mousePos;
            return true;
        }
        return false;
    }

    public function layerDrag(mousePos) {
        mousePos = Luxe.camera.screen_point_to_world(mousePos);

        var poly = cast(layers.getLayer(curLayer), Polygon);

        var drag = Vector.Subtract(mousePos, dragMouseStartPos);
        
        poly.transform.pos.add(drag);

        dragMouseStartPos = mousePos;

        switchLayerSelection(0);
    }

    public function startSceneDrag(screenPos) {
        dragMouseStartPos = screenPos;
    }

    public function sceneDrag(screenPos) {
        var drag = Vector.Subtract(dragMouseStartPos, screenPos);
        drag.divideScalar(Luxe.camera.zoom); //necessary b/c I didn't put the vectors into screen space (WHOOPS)

        Luxe.camera.transform.pos.add(drag);

        dragMouseStartPos = screenPos;
    }

    public function undoRedoInput(e:KeyEvent) {
       if (e.keycode == Key.key_z) {
            //Undo
            Edit.Undo();
        }
        else if (e.keycode == Key.key_x) {
            //Redo
            Edit.Redo();
        } 
    }

    public function selectLayerInput(e:KeyEvent) {
        if (e.keycode == Key.key_a) {
            //Go up a layer
            switchLayerSelection(-1);
        }
        else if (e.keycode == Key.key_s) {
            //Go down a layer
            switchLayerSelection(1);
        }
    }

    public function deleteLayerInput(e:KeyEvent) {
        if (e.keycode == Key.key_p) {  
            //Delete selected layer
            if (layers.getNumLayers() > 0) {    
                Edit.RemoveLayer(layers, curLayer);
                switchLayerSelection(-1);
            }
        }
    }

    public function duplicateLayerInput(e:KeyEvent) {
        if (e.keycode == Key.key_d) {
            if (layers.getNumLayers() > 0) {    
                var layerDupe = new Polygon({}, [], cast(layers.getLayer(curLayer), Polygon).jsonRepresentation());
                layerDupe.transform.pos.add(new Vector(10,10));
                Edit.AddLayer(layers, layerDupe, curLayer);
                switchLayerSelection(1);
            }
        }
    }

    public function moveLayerInput(e:KeyEvent) {
        if (e.keycode == Key.key_q) {
            //Move selected layer down the stack
            if (curLayer > 0) {
                Edit.MoveLayer(layers, curLayer, -1);
                switchLayerSelection(-1);
            }
        }
        else if (e.keycode == Key.key_w) {
            //Move selected layer up the stack
            if (curLayer < layers.getNumLayers() - 1) {
                Edit.MoveLayer(layers, curLayer, 1);    
                switchLayerSelection(1);
            }
        }
    }

    public function recentColorsInput(e:KeyEvent) {
        if (e.keycode == Key.key_j) {
            //prev color
            navigateColorList(-1);
        }
        else if (e.keycode == Key.key_k) {
            //next color
            navigateColorList(1);
        }    
    }

    public function colorDropperInput(e:KeyEvent) {
        if (e.keycode == Key.key_m) {
            //pick up color
            var tmp = layers.getLayer(curLayer).color.clone().toColorHSV();
            picker.pickedColor = tmp;
            slider.value = tmp.v;

            addColorToList(picker.pickedColor);
        }
        else if (e.keycode == Key.key_n) {
            //drop color
            //layers.getLayer(curLayer).color = picker.pickedColor.clone();
            Edit.ChangeColor(layers.getLayer(curLayer), picker.pickedColor.clone());
        }
    }

    public function addCircleInput(e:KeyEvent) {
        if (e.keycode == Key.key_t) {
            var worldMousePos = Luxe.camera.screen_point_to_world(Luxe.screen.cursor.pos);
            var points : Array<Vector> = [];
            points = points.makeCirclePolyline(worldMousePos, (Luxe.screen.w / 50) / Luxe.camera.zoom);

            trace(points);

            //var newPLine = new Polyline({color: picker.color}, points);
            var newPolygon = new Polygon({color: curColorIcon.color.clone()}, points);
            Edit.AddLayer(layers, newPolygon, curLayer+1);
            switchLayerSelection(1);
        }
    }

    public function saveLoadInput(e:KeyEvent) {

        //HACK for ios
        
        if (e.keycode == Key.key_1) {
            //save
            var rawSaveFileName = Luxe.core.app.io.platform.dialog_save().split(".");
            var saveFileName = rawSaveFileName[0];

            //scene file
            var output = File.write(saveFileName + ".json", false);

            var outObj = layers.jsonRepresentation();
            var outStr = haxe.Json.stringify(outObj);
            output.writeString(outStr);

            output.close();

            //component file
            var output = File.write(saveFileName + "_components.json", false);

            var outObj = componentManager.jsonRepresentation();
            var outStr = haxe.Json.stringify(outObj, null, "    ");
            output.writeString(outStr);

            output.close();
        }
        else if (e.keycode == Key.key_2) {
            //load
            var rawOpenFileName = Luxe.core.app.io.platform.dialog_open().split(".");
            var openFileName = rawOpenFileName[0];

            //scene file
            var input = File.read(openFileName + ".json", false);

            //read all - regardless of how many lines it is
            var inStr = "";
            while (!input.eof()) {
                inStr += input.readLine();
            }

            var inObj = haxe.Json.parse(inStr);

            for (l in cast(inObj.layers, Array<Dynamic>)) {
                Edit.AddLayer(layers, new Polygon({}, [], l), curLayer+1);
                switchLayerSelection(1);
            }

            input.close();

            //component file
            var input = File.read(openFileName + "_components.json", false);

            //read all - regardless of how many lines it is
            var inStr = "";
            while (!input.eof()) {
                inStr += input.readLine();
            }

            var inObj = haxe.Json.parse(inStr);

            componentManager.updateFromJson(inObj);

            input.close();
        }
        
    }

    public function zoomInput(e:KeyEvent) {
        if (e.keycode == Key.minus) {
            //zoom out
            Luxe.renderer.camera.zoom *= 0.5;
        }
        else if (e.keycode == Key.equals) {
            //zoom in
            Luxe.renderer.camera.zoom *= 2;
        }
    }

    public function startDrawing(e:MouseEvent) {
        var mousepos = Luxe.renderer.camera.screen_point_to_world(e.pos);
        curLine = new Polyline({color: picker.pickedColor.clone(), depth: aboveLayersDepth+1}, [mousepos]);
        isDrawing = true;
    }

    public function smoothDrawing(e:MouseEvent) {
        var mousepos = Luxe.renderer.camera.screen_point_to_world(e.pos);
        if (isDrawing && Luxe.input.mousedown(1)) {
            if (curLine.getEndPoint().distance(mousepos) >= (minLineLength / Luxe.camera.zoom)) {
                addPointToCurrentLine(mousepos);
            }
        }
    }

    public function pointDrawing(e:MouseEvent) {
        var mousepos = Luxe.renderer.camera.screen_point_to_world(e.pos);
        addPointToCurrentLine(mousepos);
    }

    public function exitColorPickerMode() {
        if (picker.pickedColor != colorList[colorList.length-1]) {
            addColorToList(picker.pickedColor);
        }
        colorPickerMode(false);
    }

    public function enterColorPickerMode() {
        colorPickerMode(true);
    }

    public function drawRotationHandle() {

        var p = curPoly();
        var b = p.getBounds();
        var handlePos = Vector.Subtract( p.transform.pos, curPoly().transform.up().multiplyScalar(b.h * 0.7) );

        Luxe.draw.line({
            p0 : curPoly().transform.pos,
            p1 : handlePos,
            color : new Color(255,0,255),
            depth : aboveLayersDepth,
            immediate : true
        });

        Luxe.draw.ring({
            x : handlePos.x,
            y : handlePos.y,
            r : (15 / Luxe.camera.zoom),
            color : new Color(255,0,255),
            depth : aboveLayersDepth,
            immediate : true
        });
    }

    public function startRotationDrag(mousePos : Vector) : Bool {
        mousePos = Luxe.camera.screen_point_to_world(mousePos);

        var p = curPoly();
        var b = p.getBounds();
        var handlePos = Vector.Subtract( p.transform.pos, curPoly().transform.up().multiplyScalar(b.h * 0.7) );

        if (mousePos.distance(handlePos) < (15 / Luxe.camera.zoom)) {
            return true;
        }

        return false;
    }

    public function rotationDrag(mousePos) {
        mousePos = Luxe.camera.screen_point_to_world(mousePos);

        var p = curPoly();

        var rotationDir = Vector.Subtract(mousePos, p.transform.pos);
        p.rotation_z = Maths.degrees(rotationDir.angle2D) - 90 - (p.transform.scale.y > 0 ? 180 : 0); // - 270;

        switchLayerSelection(0);
    }

    function scaleHandles() {
        var p = curPoly();
        var b = p.getBounds();

        var upPos = Vector.Add( p.transform.pos, p.transform.up().multiplyScalar(b.h * 0.5 /* * 0.7 */) );
        var rightPos = Vector.Add( p.transform.pos, p.transform.right().multiplyScalar(b.w * 0.5 /* * 0.7 */) );

        var handleSize = 10 / Luxe.camera.zoom;

        return {size: handleSize, up: upPos, right: rightPos};
    }

    public function drawScaleHandles() {
        var handles = scaleHandles();

        Luxe.draw.line({
            p0 : curPoly().transform.pos,
            p1 : handles.up,
            color : new Color(0,255,0),
            depth : aboveLayersDepth,
            immediate : true
        });

        Luxe.draw.rectangle({
            x : handles.up.x - (handles.size / 2),
            y : handles.up.y - (handles.size / 2),
            h : handles.size,
            w : handles.size,
            color : new Color(0,255,0),
            depth : aboveLayersDepth,
            immediate : true
        });

        Luxe.draw.line({
            p0 : curPoly().transform.pos,
            p1 : handles.right,
            color : new Color(255,0,0),
            depth : aboveLayersDepth,
            immediate : true
        });

        Luxe.draw.rectangle({
            x : handles.right.x - (handles.size / 2),
            y : handles.right.y - (handles.size / 2),
            h : handles.size,
            w : handles.size,
            color : new Color(255,0,0),
            depth : aboveLayersDepth,
            immediate : true
        });
    }

    function collisionWithScaleHandle(mousePos) : Bool {

        var handles = scaleHandles();

        mousePos = Luxe.camera.screen_point_to_world(mousePos);

        var mouseCollider = new CollisionCircle(mousePos.x, mousePos.y, 5);
        var handleColliderUp = new CollisionCircle(handles.up.x, handles.up.y, handles.size * 0.7); //this collision circle is kind of a hack, but it should be "close enough"
        var handleColliderRight = new CollisionCircle(handles.right.x, handles.right.y, handles.size * 0.7);


        if (Collision.test(mouseCollider, handleColliderUp) != null) {
            scaleDirLocal = new Vector(0,1); // NOT A GREAT WAY TO DO THIS
            //scaleDirWorld = curPoly().transform.up();
            return true;
        }
        else if (Collision.test(mouseCollider, handleColliderRight) != null) {
            scaleDirLocal = new Vector(1,0);
            //scaleDirWorld = curPoly().transform.right();
            return true;
        }
        else {
            return false;
        }
    }

    public function startScaleDrag(mousePos) : Bool {
        if (collisionWithScaleHandle(mousePos)) {
            dragMouseStartPos = Luxe.camera.screen_point_to_world(mousePos);
            return true;
        }
        return false;
    }

    //this mostly works (but could be better)
    public function scaleDrag(mousePos) {
        mousePos = Luxe.camera.screen_point_to_world(mousePos);
        var drag = Vector.Subtract(mousePos, dragMouseStartPos);

        if (scaleDirLocal.x != 0) {
            scaleDirWorld = curPoly().transform.right();
        }
        else {
            scaleDirWorld = curPoly().transform.up();
        }

        var scaleDelta = Vector.Multiply(scaleDirLocal, drag.dot(scaleDirWorld));
        scaleDelta.x = (scaleDelta.x / curPoly().getBounds().w) * curPoly().transform.scale.x * 2;
        scaleDelta.y = (scaleDelta.y / curPoly().getBounds().h) * curPoly().transform.scale.y * 2;

        curPoly().transform.scale.add(scaleDelta);

        //hack to avoid the horrible problems that occur when scale == 0
        if (curPoly().transform.scale.x == 0) {
            curPoly().transform.scale.x = 0.01;
        }
        if (curPoly().transform.scale.y == 0) {
            curPoly().transform.scale.y = 0.01;
        }

        dragMouseStartPos = mousePos;

        switchLayerSelection(0); //hack (probably a better way to do this w/ listening?)
    }

    public function drawVertexHandles() {
        if (!areVerticesTooCloseToHandle()) {  
            for (p in curPoly().getPoints()) {
                Luxe.draw.circle({
                    r : 10 / Luxe.camera.zoom,
                    steps: 360,
                    color : new Color(255,255,255),
                    depth : aboveLayersDepth,
                    x : p.x,
                    y : p.y,
                    immediate : true
                });
            }
        }
    }

    function collisionWithVertexHandle(mousePos) : Int {
        mousePos = Luxe.camera.screen_point_to_world(mousePos);
        
        var vertexCollider = new CollisionCircle(0, 0, 10 / Luxe.camera.zoom);
        var mouseCollider = new CollisionCircle(mousePos.x, mousePos.y, 5);

        var i = 0;
        for (p in curPoly().getPoints()) {
            vertexCollider.x = p.x;
            vertexCollider.y = p.y;

            if (Collision.test(mouseCollider, vertexCollider) != null) {
                return i;
            }

            i++;
        }

        return -1;
    }

    public function startVertexDrag(mousePos) : Bool {
        if (!areVerticesTooCloseToHandle()) {  
            selectedVertex = collisionWithVertexHandle(mousePos);

            if (selectedVertex > -1) {
                dragMouseStartPos = Luxe.camera.screen_point_to_world(mousePos);
                return true;
            }
        }
        return false;
    }

    public function vertexDrag(mousePos) {
        mousePos = Luxe.camera.screen_point_to_world(mousePos);

        var drag = Vector.Subtract(mousePos, dragMouseStartPos);

        var points = curPoly().getPoints();
        points[selectedVertex].add(drag);
        switchLayerSelection(0);

        curPoly().setPoints(points);

        dragMouseStartPos = mousePos;
    }

    function areVerticesTooCloseToHandle() {
        var points = curPoly().getPoints();
        for (i in 0 ... points.length-1) {
            var p1 = points[i];

            for (j in i+1 ... points.length) {
                var p2 = points[j];

                if (p1.distance(p2) < 10 / Luxe.camera.zoom) {
                    return true;
                }
            }
        }

        return false;
    }

    function curPoly() : Polygon {
        return cast(layers.getLayer(curLayer), Polygon);
    }

    public function enterPlayMode() {
        componentManager.activateComponents();
    }

    public function exitPlayMode() {
        componentManager.deactivateComponents();
    }

    public function addSelectedLayerToComponentManagerInput(e : KeyEvent) {
        //HACK IOS
        
        if (e.keycode == Key.key_c) {
            //load
            var rawOpenFileName = Luxe.core.app.io.platform.dialog_open( "Load Component", [{extension:"hx"}] ).split(".");
            var openFileName = rawOpenFileName[0];
            var fileNameSplit = openFileName.split("/"); //need to change for other OSs?
            var className = fileNameSplit[fileNameSplit.length-1];
            componentManager.addComponent(curPoly(), className);
        }
        
    }
} //Main

class DrawState extends State {

    var main : Main;

    override function init() {
    } //init

    override function onleave<T>( _main:T ) {
    } //onleave

    override function onenter<T>( _main:T ) {
        main = cast(_main, Main);
    } //onenter

    override function onkeydown(e:KeyEvent) {
        //input
        main.undoRedoInput(e);

        main.selectLayerInput(e);

        main.deleteLayerInput(e);

        main.moveLayerInput(e);

        main.duplicateLayerInput(e);

        main.recentColorsInput(e);

        main.colorDropperInput(e);

        main.saveLoadInput(e);

        main.zoomInput(e);

        main.addSelectedLayerToComponentManagerInput(e);

        main.addCircleInput(e);
        
        //switch modes
        if (e.keycode == Key.key_l) {
            //enter color picker mode
            machine.set("pickcolor", main);
        }
        
        if (e.keycode == Key.key_e) {
            machine.set("edit", main);
        }

        if (e.keycode == Key.key_0) {
            machine.set("play", main);
        }

        if (e.keycode == Key.key_b) {
            machine.set("animation", main);
        }
    }

    override function onmousedown(e:MouseEvent) {
        if (!main.isDrawing) {
            main.startDrawing(e);
        }
        else {
            main.pointDrawing(e);
        }
    }

    override function onmousemove(e:MouseEvent) {
        main.smoothDrawing(e);
    }
}

class EditState extends State {

    var main : Main;
    var draggingLayer : Bool;
    var draggingVertex : Bool;
    var draggingScale : Bool;
    var draggingRotation : Bool;

    override function init() {
    } //init

    override function onleave<T>( _main:T ) {
    } //onleave

    override function onenter<T>( _main:T ) {
        main = cast(_main, Main);
    } //onenter

    override function update(dt:Float) {
        main.drawScaleHandles();
        main.drawRotationHandle();
        main.drawVertexHandles();
    }

    override function onmousedown(e:MouseEvent) {

        draggingScale = main.startScaleDrag(e.pos);

        if (!draggingScale) {
            draggingRotation = main.startRotationDrag(e.pos);
        }

        if (!draggingRotation) {
            draggingVertex = main.startVertexDrag(e.pos);
        }

        if (!draggingVertex) {
            draggingLayer = main.startLayerDrag(e.pos);
        }
        
        if (!draggingLayer && !draggingVertex) {
          main.startSceneDrag(e.pos);
        }
    }

    override function onmousemove(e:MouseEvent) {
        if (Luxe.input.mousedown(1)) {
            if (draggingScale) {
                main.scaleDrag(e.pos);
            }
            else if (draggingRotation) {
                main.rotationDrag(e.pos);
            } 
            else if (draggingVertex) {
                main.vertexDrag(e.pos);
            }
            else if (draggingLayer) {
                main.layerDrag(e.pos);
            }
            else {
                main.sceneDrag(e.pos);
            }
        }
    }

    override function onmouseup(e:MouseEvent) {
        draggingVertex = false;
        draggingLayer = false;
        draggingRotation = false;
        draggingScale = false;
    }

    override function onkeydown(e:KeyEvent) {
        //input
        main.undoRedoInput(e);

        main.selectLayerInput(e);

        main.deleteLayerInput(e);

        main.moveLayerInput(e);

        main.duplicateLayerInput(e);

        /*
        main.recentColorsInput(e);

        main.colorDropperInput(e);
        */

        main.saveLoadInput(e);

        main.zoomInput(e);

        //return to draw mode
        if (e.keycode == Key.key_e) {
            machine.set("draw", main);
        }
    }
}

class PickColorState extends State {

    var main : Main;

    override function init() {
    } //init

    override function onleave<T>( _main:T ) {
        main.exitColorPickerMode();
    } //onleave

    override function onenter<T>( _main:T ) {
        main = cast(_main, Main);
        main.enterColorPickerMode();
    } //onenter

    override function onkeydown(e:KeyEvent) {
        main.recentColorsInput(e);

        main.saveLoadInput(e);

        if (e.keycode == Key.key_l) {
            //leave color picker mode
            machine.set("draw", main);
        }
    }
}  

class AnimationState extends State {
    var main : Main;

    //bones
    var boneList : Array<Bone> = [];
    var selectedBone : Bone;

    //making a new bone
    var startPos : Vector;
    var endPos : Vector;

    //modes
    var isMakingBone : Bool; 
    var isRotatingBone : Bool;   

    //debug
    var drawer : ShapeDrawerLuxe = new ShapeDrawerLuxe();

    //
    var curFrame : Int = 0;

    override function init() {
    } //init

    override function onenter<T>( _main:T ) {
        main = cast(_main, Main);
    } //onenter

    override function onleave<T>( _main:T ) {
    } //onleave

    override function onmousedown(e:MouseEvent) {
        var worldMousePos = Luxe.camera.screen_point_to_world(e.pos);
        var mouseCollisionShape = new CollisionCircle(worldMousePos.x, worldMousePos.y, 10);

        if (selectedBone != null) {
            if (Collision.test(mouseCollisionShape, selectedBone.rotationHandleCollisionShape()) != null) {
                isRotatingBone = true;
            }
        }

        if (!isRotatingBone) {

            isMakingBone = true;
            for (b in boneList) {
                if (Collision.test(mouseCollisionShape, b.collisionShape()) != null) {
                    selectBone(b);
                    isMakingBone = false;
                    break;
                }
            }

            if (isMakingBone) {
                startPos = Luxe.camera.screen_point_to_world(e.pos);
                endPos = startPos.clone(); 
            }

        }
        
    }

    override function onmousemove(e:MouseEvent) {
        if (Luxe.input.mousedown(1)) {
            if (isMakingBone) {
                endPos = Luxe.camera.screen_point_to_world(e.pos);
            }
            else if (isRotatingBone) {
                selectedBone.rotation_z = Maths.degrees( Luxe.camera.screen_point_to_world(e.pos).subtract(selectedBone.worldPos()).angle2D );
                selectedBone.rotation_z += 90;
                //surely there must be a better way to do this? why isn't this all automatic?
                if (selectedBone.parent != null) {
                    selectedBone.rotation_z = selectedBone.parent.transform.worldRotationToLocalRotationZ(selectedBone.rotation_z);
                }
            }
        }
    }

    override function onmouseup(e:MouseEvent) {
       
       if (isMakingBone) {
            if (selectedBone != null) {
                var b = new Bone({
                        pos : startPos.toLocalSpace(selectedBone.transform), 
                        parent : selectedBone,
                        batcher : main.uiBatcher
                    }, 
                    startPos.distance(endPos),
                    selectedBone.transform.worldRotationToLocalRotationZ( Maths.degrees(endPos.clone().subtract(startPos).angle2D) - 90 )
                );
                
                boneList.push(b);
                selectBone(b);
            }
            else {
                var b = new Bone({
                        pos : startPos, 
                        batcher : main.uiBatcher
                    }, 
                    startPos.distance(endPos), 
                    Maths.degrees(endPos.clone().subtract(startPos).angle2D) - 90
                );

                boneList.push(b);
                selectBone(b);
            }
        }
        
        isMakingBone = false;
        isRotatingBone = false;
    }

    override function update(dt:Float) {

        if (selectedBone != null) selectedBone.drawEditHandles();

        if (isMakingBone) {
            Luxe.draw.line({
                p0 : startPos,
                p1 : endPos,
                color : new Color(255,255,0),
                immediate : true,
                batcher : main.uiBatcher
            });
        }

        Luxe.draw.text({
            color: new Color(255,255,255),
            pos : new Vector(Luxe.screen.mid.x, 30),
            point_size : 20,
            text : "Frame: " + curFrame,
            immediate : true,
            batcher : main.uiBatcher
        });

    }

    override function onkeydown(e:KeyEvent) {
        if (boneList.length > 0) {
            var skeletonRoot = boneList[0];

            if (e.keycode == Key.equals) {
                curFrame++;
                skeletonRoot.frameIndex = curFrame;
            }
            else  if (e.keycode == Key.minus) {
                curFrame--;
                skeletonRoot.frameIndex = curFrame;
            }

            curFrame = skeletonRoot.frameIndex; //make sure we don't get a mismatch or go out of bounds

            if (e.keycode == Key.key_a) {
                skeletonRoot.animate(1);
            }
        }
        

        if (e.keycode == Key.key_b) {
            //leave animation mode
            machine.set("draw", main);
        }
    } 

    function selectBone(b : Bone) {
        if (selectedBone != null) {
            selectedBone.color = new Color(255,255,255);
        }
        selectedBone = b;
        selectedBone.color = new Color(255,255,0);
    }
}

class PlayState extends State {

    var main : Main;

    override function init() {
    } //init

    override function onleave<T>( _main:T ) {
        main.exitPlayMode();

        //HACK
        Luxe.renderer.add_batch(main.uiBatcher);
        Luxe.renderer.batcher.add(main.selectedLayerOutline.geometry);
    } //onleave

    override function onenter<T>( _main:T ) {
        main = cast(_main, Main);
        main.enterPlayMode();

        //HACK
        Luxe.renderer.remove_batch(main.uiBatcher);
        Luxe.renderer.batcher.remove(main.selectedLayerOutline.geometry); 
    } //onenter

    override function onkeydown(e:KeyEvent) {
        if (e.keycode == Key.key_0) {
            //leave play mode
            machine.set("draw", main);
        }
    }    
} 