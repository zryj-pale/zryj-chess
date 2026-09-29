extends RefCounted

# Bake a single brightness into each triangle in model coordinates. Coplanar
# triangles get the same value, so a flat wall stays one continuous surface.
# No camera position, board light, shadow map or time enters this calculation.
const LIGHT_DIRECTION := Vector3(-0.65, 1.0, 0.45)
const DARKEST := 0.20

static func bake(source: MeshInstance3D, model_basis: Basis) -> ArrayMesh:
	var result := ArrayMesh.new()
	var normal_basis := model_basis.inverse().transposed()
	for surface in source.mesh.get_surface_count():
		var arrays := source.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var count := indices.size() if not indices.is_empty() else vertices.size()
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for triangle in range(0, count, 3):
			var a := indices[triangle] if not indices.is_empty() else triangle
			var b := indices[triangle + 1] if not indices.is_empty() else triangle + 1
			var c := indices[triangle + 2] if not indices.is_empty() else triangle + 2
			var face := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).normalized()
			# Respect the imported mesh's winding, including mirrored exports.
			if not normals.is_empty() and face.dot(normals[a] + normals[b] + normals[c]) < 0:
				face = -face
			var direction := (normal_basis * face).normalized()
			var light := clampf(direction.dot(LIGHT_DIRECTION.normalized()) * 0.5 + 0.5, 0.0, 1.0)
			var shade := lerpf(DARKEST, 1.0, pow(light, 1.6))
			for index in [a, b, c]:
				builder.set_color(Color(shade, shade, shade, 1))
				builder.set_normal(face)
				if not uvs.is_empty():
					builder.set_uv(uvs[index])
				builder.add_vertex(vertices[index])
		var original := source.get_active_material(surface)
		var material := original.duplicate() as StandardMaterial3D if original is StandardMaterial3D else StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = false
		material.emission_enabled = false
		builder.set_material(material)
		builder.commit(result)
	return result
