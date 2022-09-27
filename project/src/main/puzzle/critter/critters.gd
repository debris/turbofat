extends Control
## Draws puzzle 'critters', little monsters which affect the puzzle.

export (NodePath) var _playfield_path: NodePath setget set_playfield_path
export (NodePath) var _piece_manager_path: NodePath setget set_piece_manager_path

## Draws moles, puzzle critters which dig up star seeds for the player.
onready var _moles: Moles = $Moles

func _ready() -> void:
	Pauser.connect("paused_changed", self, "_on_Pauser_paused_changed")
	_refresh_playfield_path()
	_refresh_piece_manager_path()


func set_playfield_path(new_playfield_path: NodePath) -> void:
	_playfield_path = new_playfield_path
	_refresh_playfield_path()


func set_piece_manager_path(new_piece_manager_path: NodePath) -> void:
	_piece_manager_path = new_piece_manager_path
	_refresh_piece_manager_path()


func _refresh_playfield_path() -> void:
	if not (is_inside_tree() and _moles):
		return
	
	_moles.playfield_path = _moles.get_path_to(get_node(_playfield_path))


func _refresh_piece_manager_path() -> void:
	if not (is_inside_tree() and _moles):
		return
	
	_moles.piece_manager_path = _moles.get_path_to(get_node(_piece_manager_path))


## When the player pauses, we hide the playfield so they can't cheat.
func _on_Pauser_paused_changed(value: bool) -> void:
	visible = not value