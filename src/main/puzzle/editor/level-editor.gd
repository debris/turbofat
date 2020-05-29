extends Control
"""
A graphical level editor which lets players create, load and save scenarios.

Full instructions are available at https://github.com/Poobslag/turbofat/wiki/level-editor
"""

const DEFAULT_SCENARIO := "ultra-normal"

# scenario scene currently being tested
var _test_scene: Node

onready var ScenarioScene := preload("res://src/main/puzzle/scenario/Scenario.tscn")

onready var _scenario_json := $HBoxContainer/CenterPanel/VBoxContainer/Json
onready var _scenario_name := $HBoxContainer/RightPanel/SideButtons/ScenarioName

func _ready() -> void:
	if not ResourceCache.is_done():
		# when launched standalone, we don't load customer resources (they're slow)
		ResourceCache.minimal_resources = true
	
	var scenario_text: String = Global.get_file_as_text(ScenarioLibrary.scenario_path(DEFAULT_SCENARIO))
	_scenario_json.text = scenario_text
	_scenario_json.refresh_tilemap()
	_scenario_name.text = DEFAULT_SCENARIO
	Breadcrumb.connect("trail_popped", self, "_on_Breadcrumb_trail_popped")


func _save_scenario(path: String) -> void:
	Global.write_file(path, _scenario_json.text)


func _load_scenario(path: String) -> void:
	var scenario_text: String = Global.get_file_as_text(path)
	_scenario_json.text = scenario_text
	_scenario_json.refresh_tilemap()
	_scenario_name.text = ScenarioLibrary.scenario_name(path)


func _start_test() -> void:
	Global.scenario_settings = ScenarioLibrary.load_scenario(_scenario_name.text, _scenario_json.text)
	Global.launched_scenario_name = Global.scenario_settings.name
	_test_scene = ScenarioScene.instance()
	
	# back button should close scenario; shouldn't redirect us to a new scene
	Breadcrumb.push_trail("res://src/main/puzzle/editor/LevelEditor.tscn::test")
	add_child(_test_scene)


func _stop_test() -> void:
	if _test_scene:
		remove_child(_test_scene)
		_test_scene.queue_free()
		_test_scene = null
		MusicPlayer.stop()


func _on_OpenFile_pressed() -> void:
	$OpenFileDialog.popup_centered()


func _on_OpenResource_pressed() -> void:
	$OpenResourceDialog.popup_centered()


func _on_Save_pressed() -> void:
	$SaveDialog.current_file = ScenarioLibrary.scenario_filename(_scenario_name.text)
	$SaveDialog.popup_centered()


func _on_OpenResourceDialog_file_selected(path) -> void:
	_load_scenario(path)


func _on_OpenFileDialog_file_selected(path) -> void:
	_load_scenario(path)


func _on_SaveDialog_file_selected(path) -> void:
	_save_scenario(path)


func _on_Test_pressed() -> void:
	_stop_test()
	_start_test()


func _on_Breadcrumb_trail_popped(prev_path: String) -> void:
	if prev_path == "res://src/main/puzzle/editor/LevelEditor.tscn::test":
		# player exited the scenario under test; stop the test
		_stop_test()
	elif not Breadcrumb.trail:
		# player exited the level editor when it was launched standalone; exit to loading screen to avoid jitter
		ResourceCache.minimal_resources = false
		get_tree().change_scene("res://src/main/ui/menu/LoadingScreen.tscn")


func _on_Exit_pressed() -> void:
	Breadcrumb.pop_trail()