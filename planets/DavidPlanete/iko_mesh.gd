extends MeshInstance3D

@export var rings := 256
@export var radial_segments := 128
var radius := 1
@export var fnl: FastNoiseLite
var surface_array := []
var mdt := MeshDataTool.new()

@export_range(1.0, 2.0) var exageration := 1.4 #represent how tall the moutains can be
var max_mult := exageration
var min_mult := 2 - max_mult
@export var planet_color : GradientTexture1D 

var max_vertex := Vector3(0.0, 0.0, 0.0)
var props_scale := 0.02

@onready var center_node := $Center
@onready var water_node := $Water
@onready var props_node := $Props
@onready var collision_shape := $HitBox/CollisionShape3D

#preloading all our props
var tree1 := preload("res://Props/Tree01.tscn")
var tree2 := preload("res://Props/Tree02.tscn")
var rock1 := preload("res://Props/Rock01.tscn")
var rock2 := preload("res://Props/Rock02.tscn")
var rock3 := preload("res://Props/Rock03.tscn")
var pirate_ship := preload("res://Props/MediumPirateShip.tscn")
var ship := preload("res://Props/MediumShip.tscn")
var ghost_ship := preload("res://Props/GhostShip.tscn")
var tower := preload("res://Props/Tower.tscn")

func _ready() -> void:
	#All this code is to generate the basic sphere (vertices, normals and index)
	props_node.scale = Vector3(props_scale, props_scale, props_scale)
	
	surface_array.resize(Mesh.ARRAY_MAX)

	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	
	var thisrow := 0
	var prevrow := 0
	var point := 0

	# Loop over rings.
	for i in range(rings):
		var v := float(i) / rings
		var w := sin(PI * v)
		var y := cos(PI * v)

		# Loop over segments in ring.
		for j in range(radial_segments):
			var u := float(j) / radial_segments
			var x := sin(u * PI * 2.0)
			var z := cos(u * PI * 2.0)
			var vert := Vector3(x * radius * w, y * radius, z * radius * w)
			verts.append(vert)
			uvs.append(Vector2(u, v))
			point += 1
			
			# Create triangles in ring using indices.
			if i > 0 and j > 0:
				indices.append(prevrow + j - 1)
				indices.append(prevrow + j)
				indices.append(thisrow + j - 1)

				indices.append(prevrow + j)
				indices.append(thisrow + j)
				indices.append(thisrow + j - 1)
		if i > 0 and i < rings:
			indices.append(prevrow)
			indices.append(thisrow)
			indices.append(prevrow + radial_segments - 1)

			indices.append(prevrow + radial_segments - 1)
			indices.append(thisrow)
			indices.append(thisrow + radial_segments - 1)
				

		prevrow = thisrow
		thisrow = point
		
	surface_array[Mesh.ARRAY_VERTEX] = verts
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	surface_array[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	generate_planet()
	spawn_props()

func _process(delta: float) -> void:
	max_mult = exageration
	min_mult = 2 - max_mult
	material_override.set_shader_parameter("center_pos", center_node.global_position)
	material_override.set_shader_parameter("max_height", scale.x * max_mult)
	material_override.set_shader_parameter("min_height", scale.x * min_mult)
	material_override.set_shader_parameter("height_color", planet_color)
	if Input.is_action_just_pressed("ui_accept"): #"ui_accept" is ENTER by default
		generate_planet()
		spawn_props()
	
func generate_planet() -> void:
	max_vertex = Vector3(0.0, 0.0, 0.0)
	fnl.seed = randi()
	
	mdt.create_from_surface(mesh, 0)
	
	for i in range(mdt.get_vertex_count()):
		var vertex := mdt.get_vertex(i).normalized()
		# Scale the vertices using noise.
		# We multiply vertex by 10 to expend the explored area of the noise
		var mult := min_mult + (fnl.get_noise_3dv(vertex * 10) + 1) * (max_mult - min_mult) / 2
		vertex = vertex * mult
		
		if vertex.length() > max_vertex.length():
			max_vertex = vertex
			
		mdt.set_vertex(i, vertex)
		mdt.set_vertex_normal(i,Vector3.ZERO)

	# Calculate the vertex normals, face-by-face.
	for i in range(mdt.get_face_count()):
		# Get the index in the vertex array.
		var a := mdt.get_face_vertex(i, 0)
		var b := mdt.get_face_vertex(i, 1)
		var c := mdt.get_face_vertex(i, 2)
		# Get the vertex position using the vertex index.
		var ap := mdt.get_vertex(a)
		var bp := mdt.get_vertex(b)
		var cp := mdt.get_vertex(c)
		# Calculate the normal of the face.
		var n := (bp - cp).cross(ap - bp)
		# Add this face normal to the current vertex normals.
		# This will not result in perfect normals, but it will be close.
		mdt.set_vertex_normal(a, n + mdt.get_vertex_normal(a))
		mdt.set_vertex_normal(b, n + mdt.get_vertex_normal(b))
		mdt.set_vertex_normal(c, n + mdt.get_vertex_normal(c))

	# Run through the vertices one last time to normalize their normals and
	# set the vertex colors to these new normals.
	for i in range(mdt.get_vertex_count()):
		var v := mdt.get_vertex_normal(i).normalized()
		mdt.set_vertex_normal(i, v)
	
	mesh.clear_surfaces() # Deletes all of the mesh's surfaces.
	mdt.commit_to_surface(mesh)
	collision_shape.shape.set_faces(mesh.get_faces()) #Create collision shape from mesh
	
func spawn_props() -> void:
	var max_tree := 100
	var tree_count := 0
	var max_rock := 25
	var rock_count := 0
	var max_ship := 6
	var ship_list = []
	for i in range(props_node.get_child_count()):
		props_node.get_child(i).queue_free()
	var attempt = 500
	var prop : Node3D
	for i in range(attempt):
		var vertex_try := mdt.get_vertex(randi_range(0, mdt.get_vertex_count() - 1))
		var vertex_height = vertex_try.length()
		if vertex_height > 1.01 and vertex_height < 1.1 and tree_count < max_tree:
			tree_count += 1
			match randi_range(0,1):
				0:
					prop = tree1.instantiate()
				1:
					prop = tree2.instantiate()
					
		else:
			if vertex_height > 1.1 and vertex_height < 1.15 and rock_count < max_rock:
				rock_count += 1
				match randi_range(0,2):
					0:
						prop = rock1.instantiate()
					1:
						prop = rock2.instantiate()
					2:
						prop = rock3.instantiate()
			else: 
				if vertex_height < 0.9 and ship_list.size() < max_ship:
					var too_close := false
					for i_ship in ship_list:
						if (i_ship - vertex_try).length() < 0.5 :
							too_close = true
							break
					if too_close: continue
					vertex_try = vertex_try.normalized() * 0.99
					ship_list.append(vertex_try)
					match randi_range(0,9):
						0,1,2,3:
							prop = ship.instantiate()
						4,5,6,7:
							prop = pirate_ship.instantiate()
						8,9: #Ghost ships are more rare !
							prop = ghost_ship.instantiate()
				else: continue
		props_node.add_child(prop)
		prop.get_child(0).rotate_x(-PI/2) #rotate prop model so that UP is FORWARD
		prop.look_at(global_transform * vertex_try)
		prop.rotation.z = (randf_range(PI,-PI))
		prop.global_position = global_transform * (vertex_try * 0.99)
		
	#Now spawning tower on heighest point
	prop = tower.instantiate() 
	props_node.add_child(prop)
	prop.get_child(0).rotate_x(-PI/2) #rotate prop model so that UP is FORWARD
	prop.look_at(global_transform * max_vertex)
	prop.rotation.z = (randf_range(PI,-PI))
	prop.global_position = global_transform * (max_vertex * 0.99)
	
