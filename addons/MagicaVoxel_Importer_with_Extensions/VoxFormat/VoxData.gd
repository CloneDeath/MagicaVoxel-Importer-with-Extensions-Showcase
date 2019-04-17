const Model = preload("./Model.gd");

var models = {0: Model.new()};
var current_index = -1;
var colors = null;
var nodes = {};

func get_model():
	if (!models.has(current_index)):
		models[current_index] = Model.new();
	return models[current_index];