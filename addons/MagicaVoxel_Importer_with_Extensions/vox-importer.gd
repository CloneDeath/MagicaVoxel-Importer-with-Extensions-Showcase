tool
extends EditorImportPlugin

const VoxFile = preload("./VoxFile.gd");
const Faces = preload("./Faces.gd");
const VoxData = preload("./VoxFormat/VoxData.gd");
const VoxNode = preload("./VoxFormat/VoxNode.gd");
const VoxMaterial = preload("./VoxFormat/VoxMaterial.gd");

const debug_file = false;
const debug_models = false;

func _init():
	print('MagicaVoxel Importer: Ready')

func get_importer_name():
	return 'MagicaVoxel.With.Extensions'

func get_visible_name():
	return 'MagicaVoxel Mesh'

func get_recognized_extensions():
	return [ 'vox' ]

func get_resource_type():
	return 'Mesh'

func get_save_extension():
	return 'mesh'

func get_preset_count():
	return 0

func get_preset_name(_preset):
	return 'Default'
	
func get_import_options(_preset):
	return [
		{
			'name': 'Scale',
			'default_value': 0.1
		}
	]

func get_option_visibility(_option, _options):
	return true

func import(source_path, destination_path, options, _platforms, _gen_files):
	var scale = 0.1
	if options.Scale:
		scale = float(options.Scale)
	
	var file = File.new()
	var err = file.open(source_path, File.READ)

	if err != OK:
		if file.is_open(): file.close()
		return err
	
	var identifier = PoolByteArray([ file.get_8(), file.get_8(), file.get_8(), file.get_8() ]).get_string_from_ascii()
	var version = file.get_32()
	print('Importing: ', source_path, ' (scale: ', scale, ', file version: ', version, ')');
	
	var vox = VoxData.new();
	if identifier == 'VOX ':
		var voxFile = VoxFile.new(file);
		while voxFile.has_data_to_read():
			read_chunk(vox, voxFile);
	file.close()
	
	var voxel_data = unify_voxels(vox).data;

	var generator = VoxelMeshGenerator.new(vox, voxel_data, scale);
	var mesh = generator.generate_mesh();
	
	var full_path = "%s.%s" % [ destination_path, get_save_extension() ]
	return ResourceSaver.save(full_path, mesh);

func string_to_vector3(input: String) -> Vector3:
	var data = input.split_floats(' ');
	return Vector3(data[0], data[1], data[2]);

func byte_to_basis(data: int):
	var x_ind = ((data >> 0) & 0x03);
	var y_ind = ((data >> 2) & 0x03);
	var indexes = [0, 1, 2];
	indexes.erase(x_ind);
	indexes.erase(y_ind);
	var z_ind = indexes[0];
	var x_sign = 1 if ((data >> 4) & 0x01) == 0 else -1;
	var y_sign = 1 if ((data >> 5) & 0x01) == 0 else -1;
	var z_sign = 1 if ((data >> 6) & 0x01) == 0 else -1;
	var result = Basis();
	result.x[0] = x_sign if x_ind == 0 else 0;
	result.x[1] = x_sign if x_ind == 1 else 0;
	result.x[2] = x_sign if x_ind == 2 else 0;
	
	result.y[0] = y_sign if y_ind == 0 else 0;
	result.y[1] = y_sign if y_ind == 1 else 0;
	result.y[2] = y_sign if y_ind == 2 else 0;
	
	result.z[0] = z_sign if z_ind == 0 else 0;
	result.z[1] = z_sign if z_ind == 1 else 0;
	result.z[2] = z_sign if z_ind == 2 else 0;
	return result;

func read_chunk(vox: VoxData, file: VoxFile):
	var chunk_id = file.get_string(4);
	var chunk_size = file.get_32();
	#warning-ignore:unused_variable
	var childChunks = file.get_32()

	file.set_chunk_size(chunk_size);
	match chunk_id:
		'SIZE':
			vox.current_index += 1;
			var model = vox.get_model();
			var x = file.get_32();
			var y = file.get_32();
			var z = file.get_32();
			model.size = Vector3(x, y, z);
			if debug_file: print('SIZE ', model.size);
		'XYZI':
			var model = vox.get_model();
			if debug_file: print('XYZI');
			for _i in range(file.get_32()):
				var x = file.get_8()
				var y = file.get_8()
				var z = file.get_8()
				var c = file.get_8()
				var voxel = Vector3(x, y, z)
				model.voxels[voxel] = c - 1
				if debug_file && debug_models: print('\t', voxel, ' ', c-1);
		'RGBA':
			vox.colors = []
			for _i in range(256):
				var r = float(file.get_8() / 255.0)
				var g = float(file.get_8() / 255.0)
				var b = float(file.get_8() / 255.0)
				var a = float(file.get_8() / 255.0)
				vox.colors.append(Color(r, g, b, a))
		'nTRN':
			var node_id = file.get_32();
			var attributes = file.get_vox_dict();
			var node = VoxNode.new(node_id, attributes);
			vox.nodes[node_id] = node;
			
			var child = file.get_32();
			node.child_nodes.append(child);
			
			file.get_buffer(8);
			var num_of_frames = file.get_32();
			
			if debug_file: 
				print('nTRN[', node_id, '] -> ', child);
				if (!attributes.empty()): print('\t', attributes);
			for _frame in range(num_of_frames):
				var frame_attributes = file.get_vox_dict();
				if (frame_attributes.has('_t')):
					var trans = frame_attributes['_t'];
					node.translation = string_to_vector3(trans);
					if debug_file: print('\tT: ', node.translation);
				if (frame_attributes.has('_r')):
					var rot = frame_attributes['_r'];
					node.rotation = byte_to_basis(int(rot));
					if debug_file: print('\tR: ', node.rotation);
			
		'nGRP':
			var node_id = file.get_32();
			var attributes = file.get_vox_dict();
			var node = VoxNode.new(node_id, attributes);
			vox.nodes[node_id] = node;
			
			var num_children = file.get_32();
			for _c in num_children:
				node.child_nodes.append(file.get_32());
			if debug_file: 
				print('nGRP[', node_id, '] -> ', node.child_nodes);
				if (!attributes.empty()): print('\t', attributes);
		'nSHP':
			var node_id = file.get_32();
			var attributes = file.get_vox_dict();
			var node = VoxNode.new(node_id, attributes);
			vox.nodes[node_id] = node;
			
			var num_models = file.get_32();
			for _i in range(num_models):
				node.models.append(file.get_32());
				file.get_vox_dict();
			if debug_file: 
				print('nSHP[', node_id,'] -> ', node.models);
				if (!attributes.empty()): print('\t', attributes);
		'MATL':
			var material_id = file.get_32() - 1;
			var properties = file.get_vox_dict();
			vox.materials[material_id] = VoxMaterial.new(properties);
			if debug_file: 
				print("MATL ", material_id);
				print("\t", properties);
		_:
			if debug_file: print(chunk_id);
	file.read_remaining();

func unify_voxels(vox: VoxData):
	var node = vox.nodes[0];
	return get_voxels(node, vox);

class VoxelData:
	var data = {};
	
	func combine(model):
		var offset = (model.size / 2.0).floor();
		for voxel in model.voxels:
			data[voxel - offset] = model.voxels[voxel];
	
	func combine_data(other):
		for voxel in other.data:
			data[voxel] = other.data[voxel];
	
	func rotate(basis: Basis):
		var new_data = {};
		for voxel in data:
			var half_step = Vector3(0.5, 0.5, 0.5);
			var new_voxel = (basis.xform(voxel+half_step)-half_step).floor();
			new_data[new_voxel] = data[voxel];
		data = new_data;
	
	func translate(translation: Vector3):
		var new_data = {};
		for voxel in data:
			var new_voxel = voxel + translation;
			new_data[new_voxel] = data[voxel];
		data = new_data;

func get_voxels(node: VoxNode, vox: VoxData):
	var data = VoxelData.new();
	for model_index in node.models:
		var model = vox.models[model_index];
		data.combine(model);
	for child_index in node.child_nodes:
		var child = vox.nodes[child_index];
		var child_data = get_voxels(child, vox);
		data.combine_data(child_data);
	data.rotate(node.rotation.inverse());
	data.translate(node.translation);
	return data;

class MeshGenerator:
	var surfaces = {};
	
	func ensure_surface_exists(surface_index: int, color: Color, material: Material):
		if (surfaces.has(surface_index)): return;
		
		var st = SurfaceTool.new();
		st.begin(Mesh.PRIMITIVE_TRIANGLES);
		st.add_color(color);
		st.set_material(material);
		surfaces[surface_index] = st;
	
	func add_vertex(surface_index: int, vertex: Vector3):
		var st = surfaces[surface_index] as SurfaceTool;
		st.add_vertex(vertex);
	
	func combine_surfaces():
		var mesh = null;
		for surface_index in surfaces:
			var surface = surfaces[surface_index] as SurfaceTool;
			surface.index();
			surface.generate_normals();
			mesh = surface.commit(mesh);
			
			var new_surface_index = mesh.get_surface_count() - 1;
			var name = str(surface_index);
			mesh.surface_set_name(new_surface_index, name);
		return mesh;

class VoxelMeshGenerator:
	var vox;
	var voxel_data = {};
	var scale:float;
	
	func _init(vox, voxel_data, scale):
		self.vox = vox;
		self.voxel_data = voxel_data;
		self.scale = scale;
	
	func get_material(voxel):
		var surface_index = voxel_data[voxel];
		return vox.materials[surface_index]
	
	func face_is_visible(voxel, face):
		if (not voxel_data.has(voxel + face)):
			return true;
		var local_material = get_material(voxel);
		var adj_material = get_material(voxel + face);
		return adj_material.is_glass() && !local_material.is_glass();

	func generate_mesh():
		var vox_to_godot = Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP);
		
		var gen = MeshGenerator.new();
		
		for voxel in voxel_data:
			var voxelSides = []
			if face_is_visible(voxel, Vector3.UP): voxelSides += Faces.Top
			if face_is_visible(voxel, Vector3.DOWN): voxelSides += Faces.Bottom
			if face_is_visible(voxel, Vector3.LEFT): voxelSides += Faces.Left
			if face_is_visible(voxel, Vector3.RIGHT): voxelSides += Faces.Right
			if face_is_visible(voxel, Vector3.BACK): voxelSides += Faces.Front
			if face_is_visible(voxel, Vector3.FORWARD): voxelSides += Faces.Back
			
			var surface_index = voxel_data[voxel];
			var color = vox.colors[surface_index];
			var material = vox.materials[surface_index].get_material(color);
			gen.ensure_surface_exists(surface_index, color, material);
	
			for t in voxelSides:
				gen.add_vertex(surface_index, vox_to_godot.xform((t + voxel) * scale));
	
		return gen.combine_surfaces();