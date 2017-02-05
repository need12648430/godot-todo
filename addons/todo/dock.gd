tool
extends EditorPlugin

var dock
var re = RegEx.new()

func _enter_tree():
	print("TODO created.")
	re.compile("TODO\\:[:space:]*([^\\n]*)[:space:]*")
	
	dock = preload("scenes/TODO List.tscn").instance()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_BL, dock)
	dock.get_node("Toolbar/Refresh").connect("pressed", self, "populate_tree")
	populate_tree()

func _exit_tree():
	dock.get_node("Toolbar/Refresh").disconnect("pressed", self, "populate_tree")
	remove_control_from_docks(dock)
	print("TODO freed.")

func item_activated():
	var tree = dock.get_node("Background/Scrollbar/Contents")
	var file = tree.get_selected().get_metadata(0)
	edit_resource(load(file))

func populate_tree():
	var tree = dock.get_node("Background/Scrollbar/Contents")
	
	tree.clear()
	
	if not tree.is_connected("item_activated", self, "item_activated"):
		tree.connect("item_activated", self, "item_activated")
	
	var root = tree.create_item()
	tree.set_column_expand(0, true)
	tree.set_hide_root(true)
	#tree.set_hide_folding(true)
	
	var files = find_all_todos()
	for file in files:
		var where = file["file"]
		var todos = file["todos"]
		if todos.size():
			var file_node = tree.create_item(root)
			file_node.set_metadata(0, file["file"])
			file_node.set_text(0, where)
			for todo in todos:
				var todo_node = tree.create_item(file_node)
				todo_node.set_metadata(0, file["file"])
				if "line" in todo:
					todo_node.set_text(0, "Line %d: %s" % [todo["line"], todo["text"]])
				else:
					todo_node.set_text(0, todo["text"])
					file_node.set_collapsed(true)

func find_files(directory, extensions, recur = false):
	var results = []
	var dir = Directory.new()
	
	if dir.open(directory) != OK:
		return results
	
	dir.list_dir_begin()
	
	var file = dir.get_next()
	
	while file != "":
		var location = dir.get_current_dir() + "/" + file
		
		if file in [".", ".."]:
			file = dir.get_next()
			continue
		
		if recur and dir.current_is_dir():
			for subfile in find_files(location, extensions, true):
				results.append(subfile)
		
		if not dir.current_is_dir() and file.extension() in extensions:
			results.append(location)
		
		file = dir.get_next()
	
	dir.list_dir_end()
	return results

func find_all_todos():
	var files = find_files("res://", ["gd", "scn", "tscn", "xscn", "xml"], true)
	
	var todos = []
	
	for file in files:
		var file_todos = {"file": file}
		var found = todos_in_file(file)
		if file.extension() == "gd":
			file_todos["todos"] = found
		else:
			if found.size() > 0:
				file_todos["todos"] = [{"text": "Found TODOs in built-in scripts."}]
			else:
				file_todos["todos"] = []
		todos.append(file_todos)
	
	return todos

func todos_in_file(location):
	var todos = []
	var line_count = 0
	
	var file = File.new()
	file.open(location, File.READ)
	
	while not file.eof_reached():
		var line = file.get_line()
		line_count += 1
		
		var pos = re.find(line, 0)
		if pos != -1:
			todos.append({"line": line_count, "text": re.get_capture(1)})
	
	file.close()
	return todos
