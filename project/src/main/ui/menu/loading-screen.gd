extends Control
## Shows a progress bar while resources are loading.

onready var _wallpaper := $Wallpaper
onready var _orb := $Holder/Orb
onready var _progress_bar := $Holder/ProgressBar

func _ready() -> void:
	ResourceCache.connect("finished_loading", self, "_on_ResourceCache_finished_loading")
	ResourceCache.start_load()
	
	_orb.modulate = _wallpaper.light_color.lightened(0.5)
	_progress_bar.modulate = _orb.modulate


func _process(_delta: float) -> void:
	_progress_bar.value = ResourceCache.get_progress()


func _on_ResourceCache_finished_loading() -> void:
	if SystemData.fast_mode:
		# run faster for debug builds
		SceneTransition.next_fade_out_duration *= 0.5
		SceneTransition.next_fade_in_duration *= 0.5
	else:
		# This scene transition looks pretty so it's nice to draw attention to it. But we don't want every scene
		# transition to be this slow or the game will be tedious to navigate. So, we just slow it down for the loading
		# screen.
		SceneTransition.next_fade_out_duration += 0.6
		SceneTransition.next_fade_in_duration += 0.6
	SceneTransition.push_trail(Global.SCENE_SPLASH)
