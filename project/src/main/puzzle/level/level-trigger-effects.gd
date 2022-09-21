extends Node
## A library of level trigger effects.
##
## These effects are each mapped to a unique string so that they can be referenced from json.

## Adds one or more moles to the playfield.
class AddMolesEffect extends LevelTriggerEffect:
	var config: MoleConfig = MoleConfig.new()
	
	func set_config(new_config: Dictionary = {}) -> void:
		if new_config.has("count"):
			config.count = new_config["count"].to_int()
		if new_config.has("home"):
			config.home = Utils.enum_from_snake_case(MoleConfig.Home, new_config["home"])
		if new_config.has("y"):
			var inverted_lines := ConfigStringUtils.ints_from_config_string(new_config["y"])
			config.lines = ConfigStringUtils.invert_lines(inverted_lines)
		if new_config.has("x"):
			config.columns = ConfigStringUtils.ints_from_config_string(new_config["x"])
		if new_config.has("dig_duration"):
			config.dig_duration = new_config["dig_duration"].to_int()
		if new_config.has("reward"):
			config.reward = Utils.enum_from_snake_case(MoleConfig.Reward, new_config["reward"])
	
	
	func run() -> void:
		CurrentLevel.puzzle.get_moles().add_moles(config)
	
	
	func get_config() -> Dictionary:
		var result := {}
		
		if config.count != 1:
			result["count"] = str(config.count)
		if config.home != MoleConfig.Home.ANY:
			result["home"] = Utils.enum_to_snake_case(MoleConfig.Home, config.home)
		if config.lines:
			var inverted_lines := ConfigStringUtils.invert_lines(config.lines)
			result["y"] = ConfigStringUtils.config_string_from_ints(inverted_lines)
		if config.columns:
			result["x"] = ConfigStringUtils.config_string_from_ints(config.columns)
		if config.dig_duration != 3:
			result["dig_duration"] = str(config.dig_duration)
		if config.reward != MoleConfig.Reward.STAR:
			result["reward"] = Utils.enum_to_snake_case(MoleConfig.Reward, config.reward)
		
		return result


## Advances all moles on the playfield, allowing them to dig up pickups.
class AdvanceMolesEffect extends LevelTriggerEffect:
	
	func run() -> void:
		CurrentLevel.puzzle.get_moles().advance_moles()


## Rotates one or more pieces in the piece queue.
class RotateNextPiecesEffect extends LevelTriggerEffect:
	enum Rotation {
		NONE, CW, CCW, FLIP
	}
	
	## an enum in Rotation corresponding to the direction to rotate
	var rotate_dir: int = Rotation.NONE
	
	## The first piece index in the queue to rotate, inclusive
	var next_piece_from_index: int = 0
	
	## The last piece index in the queue to rotate, inclusive
	var next_piece_to_index: int = 999999
	
	## Updates the effect's configuration.
	##
	## This effect's configuration accepts the following parameters:
	##
	## [0]: (Optional) The direction to rotate, 'cw', 'ccw', '180' or 'none'. Defaults to 'none'.
	## [1]: (Optional) The first piece index in the queue to rotate. Defaults to 0.
	## [2]: (Optional) The last piece index in the queue to rotate. Defaults to 999999.
	##
	## Example: ["cw", "0", "0"]
	func set_config(new_config: Dictionary = {}) -> void:
		if new_config.has("0"):
			match new_config["0"]:
				"none": rotate_dir = Rotation.NONE
				"cw": rotate_dir = Rotation.CW
				"ccw": rotate_dir = Rotation.CCW
				"180": rotate_dir = Rotation.FLIP
		
		if new_config.has("1"):
			next_piece_from_index = new_config["1"].to_int()
		
		if new_config.has("2"):
			next_piece_to_index = new_config["2"].to_int()
	
	
	## Rotates one or more pieces in the piece queue.
	func run() -> void:
		var pieces: Array = CurrentLevel.puzzle.get_piece_queue().pieces
		for i in range(next_piece_from_index, next_piece_to_index + 1):
			if i >= pieces.size():
				break
			var next_piece: NextPiece = pieces[i]
			match rotate_dir:
				Rotation.CW: next_piece.orientation = next_piece.get_cw_orientation()
				Rotation.CCW: next_piece.orientation = next_piece.get_ccw_orientation()
				Rotation.FLIP: next_piece.orientation = next_piece.get_flip_orientation()
	
	
	func get_config() -> Dictionary:
		var result := {}
		match rotate_dir:
			Rotation.NONE: result["0"] = "none"
			Rotation.CW: result["0"] = "cw"
			Rotation.CCW: result["0"] = "ccw"
			Rotation.FLIP: result["0"] = "180"
		if next_piece_from_index != 0:
			result["1"] = str(next_piece_from_index)
		if next_piece_to_index != 999999:
			# we also populate result["1"] if it wasn't already populated
			result["1"] = str(next_piece_from_index)
			result["2"] = str(next_piece_to_index)
		
		return result


## Inserts a new line at the bottom of the playfield.
class InsertLineEffect extends LevelTriggerEffect:
	## (Optional) key corresponding to a set of tiles in LevelTiles for the tiles to insert
	var tiles_key: String
	
	## (Optional) keys corresponding to sets of tiles in LevelTiles for the tiles to insert
	var tiles_keys: Array
	
	## Updates the effect's configuration.
	##
	## This effect's configuration accepts the following parameters:
	##
	## [tiles_key]: (Optional) A key corresponding to a set of tiles in LevelTiles for the tiles to insert.
	##
	## Example: ["tiles_key=0"]
	##
	## [tiles_keys]: (Optional) A key corresponding to sets of tiles in LevelTiles for the tiles to insert.
	##
	## Example: ["tiles_keys=0,1"]
	func set_config(new_config: Dictionary = {}) -> void:
		tiles_key = new_config.get("tiles_key", "")
		tiles_keys = new_config["tiles_keys"].split(",") if new_config.has("tiles_keys") else []
	
	
	## Inserts a new line at the bottom of the playfield.
	func run() -> void:
		if tiles_key:
			CurrentLevel.puzzle.get_playfield().line_inserter.insert_line([tiles_key])
		elif tiles_keys:
			CurrentLevel.puzzle.get_playfield().line_inserter.insert_line(tiles_keys)
		else:
			CurrentLevel.puzzle.get_playfield().line_inserter.insert_line([])
	
	
	func get_config() -> Dictionary:
		var result := {}
		if tiles_key:
			result["tiles_key"] = tiles_key
		if tiles_keys:
			result["tiles_keys"] = PoolStringArray(tiles_keys).join(",")
		return result


var effects_by_string := {
	"add_moles": AddMolesEffect,
	"advance_moles": AdvanceMolesEffect,
	"rotate_next_pieces": RotateNextPiecesEffect,
	"insert_line": InsertLineEffect,
}


## Creates a new LevelTriggerEffect instance.
##
## Parameters:
## 	'effect_key': A string key corresponding to the level trigger effect, such as 'insert_line'.
##
## 	'effect_config': (Optional) An array of strings defining the effect's behavior.
func create(effect_key: String, effect_config: Dictionary = {}) -> LevelTriggerEffect:
	if not effects_by_string.has(effect_key):
		push_warning("Unrecognized effect: %s" % [effect_key])
	var effect_script: GDScript = effects_by_string.get(effect_key)
	var effect: LevelTriggerEffect = effect_script.new()
	if effect_config:
		effect.set_config(effect_config)
	return effect


func effect_key(effect: LevelTriggerEffect) -> String:
	return effects_by_string.keys()[effects_by_string.values().find(effect.get_script())]
