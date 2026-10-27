extends Node3D
## Damage-only regions follow the corrected skeleton, never the movement footprint.
const LAYER := 16
var actor: Node3D
var regions: Array=[]
var shapes: Array=[]
func setup(rex: Node3D) -> void:
	actor=rex
	for spec in [["jt_Hips_C_031","jt_Spine2_C_04",4.0],["jt_Spine2_C_04","jt_Neck3_C_07",2.6],["jt_Head_C_08","jt_Tongue2_C_011",2.7],["jt_Hips_C_031","jt_Tail2_C_033",2.5],["jt_Tail2_C_033","jt_Tail4_C_035",1.5],["jt_Hip_R_038","jt_Knee_R_040",1.8],["jt_Knee_R_040","jt_Ankle_R_00",1.1],["jt_Hip_L_049","jt_Knee_L_051",1.8],["jt_Knee_L_051","jt_Ankle_L_052",1.1]]:
		var a=actor.skeleton.find_bone(spec[0]);var b=actor.skeleton.find_bone(spec[1]);assert(a>=0 and b>=0)
		var area=Area3D.new();area.collision_layer=LAYER;area.collision_mask=0;area.monitoring=false;area.monitorable=false;add_child(area)
		var shape=CollisionShape3D.new();shape.shape=CapsuleShape3D.new();shape.shape.radius=spec[2];area.add_child(shape)
		regions.append({"area":area,"shape":shape,"a":a,"b":b,"radius":spec[2]});shapes.append(shape)
	actor.set_meta("damage_regions",shapes)
	actor.grounding.modification_processed.connect(sync_pose)
	sync_pose()
func sync_pose() -> void:
	for region in regions:
		region.area.collision_layer=LAYER if actor.health>0 else 0
		var a: Vector3=actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(region.a).origin)
		var b: Vector3=actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(region.b).origin)
		var offset=b-a
		region.shape.shape.height=offset.length()+region.radius*2
		region.area.global_transform=Transform3D(Basis(Quaternion(Vector3.UP,offset.normalized())) if offset.length_squared()>.0001 else Basis.IDENTITY,(a+b)*.5)
