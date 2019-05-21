const Faces = preload("./Faces.gd");
const vox_to_godot = Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP);

func generate(vox, voxel_data, scale):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for voxel in voxel_data:
		var voxelSides = []
		if not voxel_data.has(voxel + Vector3.UP): voxelSides += Faces.Top
		if not voxel_data.has(voxel + Vector3.DOWN): voxelSides += Faces.Bottom
		if not voxel_data.has(voxel + Vector3.LEFT): voxelSides += Faces.Left
		if not voxel_data.has(voxel + Vector3.RIGHT): voxelSides += Faces.Right
		if not voxel_data.has(voxel + Vector3.BACK): voxelSides += Faces.Front
		if not voxel_data.has(voxel + Vector3.FORWARD): voxelSides += Faces.Back
		
		st.add_color(vox.colors[voxel_data[voxel]])

		for t in voxelSides:
			st.add_vertex(vox_to_godot.xform((t + voxel) * scale))
		
	st.generate_normals()
	
	var material = SpatialMaterial.new()
	material.vertex_color_is_srgb = true
	material.vertex_color_use_as_albedo = true
	material.roughness = 1
	st.set_material(material)

	return st.commit()
