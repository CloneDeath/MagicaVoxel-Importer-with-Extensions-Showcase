var properties = null;
var material: SpatialMaterial = null;

func _init(properties):
	self.properties = properties;

func get_material():
	if (material != null): return material;
	
	material = SpatialMaterial.new()
	material.vertex_color_is_srgb = true
	material.vertex_color_use_as_albedo = true
	material.roughness = 1
	return material;