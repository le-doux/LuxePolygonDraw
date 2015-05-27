package components;
import components.EditorComponent;

import luxe.Vector;
import luxe.Color;

import animation.Bone;

using utilities.TransformExtender;
using utilities.VectorExtender;

/*
typedef VertexBoneMapping = {
	public var vertexIndex : Int;
	public var boneIndex : Int;
	public var localPos : Vector;
}
*/


typedef VertexBoneMapping = {
	public var vertex : Int;
	public var bones : Array<Int>;
	public var weights : Array<Float>;
	public var displacements : Array<Vector>;
}


class Animation extends EditorComponent {
	
	var polygon : Polygon;

	public var skeletonRoot (default, set) : Bone;
	var skeleton : Array<Bone>;

	var skeletonMap : Array<VertexBoneMapping>;

	public var maxInfluenceDistance : Float = 200; //distance within which vertices are influenced by bones

	//DEBUG
	var isDebug = true;

	override function init() {
		polygon = cast entity;
	}

	override function update(dt : Float) {
		for (mapping in skeletonMap) {

			/*
			var bone = skeleton[mapping.boneIndex];
			
			var worldPos = bone.transform.localVectorToWorldSpace(mapping.localPos);
			var vertPos = polygon.transform.worldVectorToLocalSpace(worldPos);

			polygon.geometry.vertices[mapping.vertexIndex].pos = vertPos;
			*/

			
			var weightedVertPos = new Vector(0,0);

			for (i in 0 ... mapping.bones.length) {

				var bone = skeleton[mapping.bones[i]];
				var weight = mapping.weights[i];

				var worldPos = bone.transform.localVectorToWorldSpace(mapping.displacements[i]);
				var vertPos = polygon.transform.worldVectorToLocalSpace(worldPos);

				weightedVertPos.add(vertPos.multiplyScalar(weight));

			}

			polygon.geometry.vertices[mapping.vertex].pos = weightedVertPos;

			//debug
			if (isDebug) {
				for (i in 0 ... mapping.bones.length) {

					var bone = skeleton[mapping.bones[i]];
				
					Luxe.draw.line({
						p0 : bone.closestWorldPoint(polygon.transform.localVectorToWorldSpace(weightedVertPos)),
						p1 : polygon.transform.localVectorToWorldSpace(weightedVertPos),
						immediate : true,
						depth : 2000,
						color : new ColorHSV(mapping.weights[i] * 360, 1, 1) 
					});

				}
			}

		}
	}

	function set_skeletonRoot(root : Bone) : Bone {
		skeletonRoot = root;

		skeleton = root.skeleton();
		mapMeshToSkeleton();

		return skeletonRoot;
	}

	function mapMeshToSkeleton() {

		skeletonMap = [];

		var i = 0;
		for (vert in polygon.geometry.vertices) {

			//find closest bone
			var vertWorldPos = polygon.transform.localVectorToWorldSpace(vert.pos);

			var closestBone = 0;
			var closestDist = skeleton[closestBone].closestWorldPoint(vertWorldPos).distance(vertWorldPos);

			var closeBones = [];
			var closeDistList = [];

			var j = 0;
			for (bone in skeleton) {

				var curDist = bone.closestWorldPoint(vertWorldPos).distance(vertWorldPos);

				if (curDist < closestDist) {
					closestBone = j;
					closestDist = curDist;
				}

				
				if (curDist < maxInfluenceDistance) {
					closeBones.push(j);
					closeDistList.push(curDist);
				}
				

				j++;
			}

			/*
			var posRelToBone = skeleton[closestBone].transform.worldVectorToLocalSpace(vertWorldPos);

			//create mapping
			var mapping = {vertexIndex : i, boneIndex : closestBone, localPos : posRelToBone};
			skeletonMap.push(mapping);
			*/

			
			//in case no bones are closer than maxInfluenceDistance
			if (closeBones.length == 0) {
				closeBones.push(closestBone);
				closeDistList.push(closestDist);
			}

			//calc weights
			var totalDist = 0.0;
			for (d in closeDistList) {
				totalDist += d;
			}
			var weights = closeDistList.map(function(d) { return (1 - (d / totalDist)); });

			//inelegant hack
			if (weights.length == 1) weights = [1.0];


			//debug
			var inbetweenBone = (weights.length > 1);
			if (inbetweenBone) trace("weights");
			if (inbetweenBone) trace(weights);

			//another inelegant hack ( for renormalization )

			/*
			var totalWeight = 0.0;
			for (w in weights) {
				totalWeight += w;
			}

			if (Math.abs(totalWeight - 1) > 0.01) trace("F****CK");

			if (inbetweenBone) trace(totalWeight);

			weights = weights.map(function(w) { return w / totalWeight; });

			totalWeight = 0.0;
			for (w in weights) {
				totalWeight += w;
			}

			if (inbetweenBone) trace(weights);
			if (inbetweenBone) trace(totalWeight);
			*/

			

			//calc displacements
			var displacements = closeBones.map(function(b) { return skeleton[b].transform.worldVectorToLocalSpace(vertWorldPos); });

			//create mapping
			var mapping = {
				vertex : i,
				bones : closeBones,
				weights : weights,
				displacements : displacements
			};
			skeletonMap.push(mapping);
			

			i++;
		}

		//trace(skeletonMap);

		/*
		for (m in skeletonMap) {
			trace(m.weights);
			trace(m.bones);
			trace("---");
		}
		*/

	}
}