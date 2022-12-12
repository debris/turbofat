class_name HoldPieceDisplays
extends Control
## Displays the hold piece to the player and manages the hold piece display.
##
## There is only one hold piece display at a time. This code is named and organized how it is for symmetry with the
## Next Piece Display functionality, since they have a lot in common.

export (NodePath) var piece_queue_path: NodePath
export (PackedScene) var HoldPieceDisplayScene

var _hold_piece_display: HoldPieceDisplay

onready var _piece_queue: PieceQueue = get_node(piece_queue_path)

func _ready() -> void:
	PuzzleState.connect("game_prepared", self, "_on_PuzzleState_game_prepared")
	Pauser.connect("paused_changed", self, "_on_Pauser_paused_changed")
	SystemData.gameplay_settings.connect("hold_piece_changed", self, "_on_GameplaySettings_hold_piece_changed")
	
	_hold_piece_display = HoldPieceDisplayScene.instance()
	_hold_piece_display.initialize(_piece_queue)
	_hold_piece_display.scale = Vector2(0.5, 0.5)
	_hold_piece_display.position = Vector2(11, 14)
	_hold_piece_display.hide()
	add_child(_hold_piece_display)
	
	_refresh()


func _refresh() -> void:
	visible = CurrentLevel.hold_piece_enabled()


## Gets ready for a new game, randomizing the pieces and filling the piece queues.
func _on_PuzzleState_game_prepared() -> void:
	_hold_piece_display.show()


## When the player pauses, we hide the hold piece so they can't cheat.
func _on_Pauser_paused_changed(value: bool) -> void:
	_hold_piece_display.visible = not value


func _on_GameplaySettings_hold_piece_changed(_value: bool) -> void:
	_refresh()