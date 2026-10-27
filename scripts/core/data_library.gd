class_name DataLibrary
extends RefCounted
## Loads every .tres in a folder, so adding a data file is enough to add content.

static func load_all(dir: String) -> Array[Resource]:
	var out: Array[Resource] = []
	for file in DirAccess.get_files_at(dir):
		var name := file.trim_suffix(".remap")  # exported builds list "<file>.tres.remap"
		if name.ends_with(".tres"):
			out.append(load(dir.path_join(name)))
	return out
