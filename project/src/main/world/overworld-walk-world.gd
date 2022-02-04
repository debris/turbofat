extends Node
## Populates/unpopulates the creatures and obstacles on the overworld walking scene.

onready var _overworld_ui: OverworldUi = Global.get_overworld_ui()

func _ready() -> void:
	MusicPlayer.play_tutorial_bgm()
	
	ChattableManager.refresh_creatures()
	$Camera.position = ChattableManager.player.position
	if CurrentCutscene.chat_tree:
		_launch_cutscene()


func _launch_cutscene() -> void:
	_overworld_ui.cutscene = true
	
	# get the location, spawn location data
	var chat_tree := CurrentCutscene.chat_tree
	
	yield(get_tree(), "idle_frame")
	_overworld_ui.start_chat(chat_tree, null)
