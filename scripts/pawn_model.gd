extends Node3D

# Shared by the pawn, queen, king and bishop GLBs, which have no UVs.
# Box projection keeps each original asset intact
# and gives each flat face wood grain without stretching across perpendicular faces.
const WOOD := preload("res://assets/skoczek czarny_wood texture.jpg")
@export var wood_tint := Color.WHITE

func _ready() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var textured := ArrayMesh.new()
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var count := indices.size() if not indices.is_empty() else vertices.size()
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			for triangle in range(0, count, 3):
				var a := indices[triangle] if not indices.is_empty() else triangle
				var b := indices[triangle + 1] if not indices.is_empty() else triangle + 1
				var c := indices[triangle + 2] if not indices.is_empty() else triangle + 2
				# Godot imports triangles with clockwise front faces. Match their
				# outward normals so the wood is lit like the knight's material.
				var normal := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a]).normalized()
				var axis := normal.abs().max_axis_index()
				for index in [a, b, c]:
					var point := vertices[index]
					var uv := Vector2(point.x, point.y)
					if axis == Vector3.AXIS_X:
						uv = Vector2(point.y, point.z)
					elif axis == Vector3.AXIS_Y:
						uv = Vector2(point.x, point.z)
					builder.set_uv(uv / 20.0)
					builder.set_normal(normal)
					builder.add_vertex(point)
			var material := StandardMaterial3D.new()
			material.albedo_texture = WOOD
			material.albedo_color = wood_tint
			material.roughness = 0.85
			builder.set_material(material)
			builder.index()
			builder.commit(textured)
		instance.mesh = textured
