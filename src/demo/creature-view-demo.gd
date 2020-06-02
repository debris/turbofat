extends Node2D
"""
A demo which shows off the creature view.

Keys:
	[F]: Feed the creature
	[D]: Ring the doorbell
	[V]: Say something
	[P]: Print the current animation details
	[1-9,0]: Change the creature's size from 10% to 100%
	[Q,W,E]: Switch to the 1st, 2nd or 3rd creature.
	brace keys: Change the creature's appearance
"""

const FATNESS_KEYS = [10.0, 1.0, 1.5, 2.0, 3.0, 5.0, 6.0, 7.0, 8.0, 9.0]

var _current_color_index := -1

func _ready() -> void:
	# Ensure creatures are random
	randomize()


func _input(event: InputEvent) -> void:
	match Global.key_scancode(event):
		KEY_F: $CreatureView/SceneClip/CreatureSwitcher/Scene.feed()
		KEY_D: $CreatureView/SceneClip/CreatureSwitcher/Scene.play_door_chime(0)
		KEY_V: $CreatureView/SceneClip/CreatureSwitcher/Scene.play_goodbye_voice()
		KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
			$CreatureView.set_fatness(FATNESS_KEYS[Global.key_num(event)])
		KEY_Q: $CreatureView.set_current_creature_index(0)
		KEY_W: $CreatureView.set_current_creature_index(1)
		KEY_E: $CreatureView.set_current_creature_index(2)
		KEY_BRACELEFT:
			if _current_color_index == -1:
				_current_color_index = 0
			else:
				_current_color_index += CreatureLoader.DEFINITIONS.size()
				_current_color_index = (_current_color_index - 1) % CreatureLoader.DEFINITIONS.size()
			Global.creature_queue.push_front(CreatureLoader.DEFINITIONS[_current_color_index])
			$CreatureView.summon_creature()
		KEY_BRACERIGHT:
			if _current_color_index == -1:
				_current_color_index = 0
			else:
				_current_color_index = (_current_color_index + 1) % CreatureLoader.DEFINITIONS.size()
			Global.creature_queue.push_front(CreatureLoader.DEFINITIONS[_current_color_index])
			$CreatureView.summon_creature()
		KEY_P:
			print($CreatureView/SceneClip/CreatureSwitcher/Scene/Creature/AnimationPlayer.current_animation)
			print($CreatureView/SceneClip/CreatureSwitcher/Scene/Creature/AnimationPlayer.is_playing())