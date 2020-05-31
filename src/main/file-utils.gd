extends Node
"""
Utility class for file operations.

Many of these were adopted from the Gut library.
"""

static func file_exists(path: String) -> bool:
	var f := File.new()
	var exists := f.file_exists(path)
	f.close()
	return exists


static func get_file_as_text(path: String) -> String:
	var f := File.new()
	f.open(path, f.READ)
	var text := f.get_as_text()
	f.close()
	return text


static func write_file(path: String, text: String) -> void:
	var f := File.new()
	f.open(path, f.WRITE)
	f.store_string(text)
	f.close()