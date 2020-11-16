tool
extends HBoxContainer
"""
A row which lets the player define keybinds for a specific action, such as 'Move Piece Left'.
"""

export (String) var description: String setget set_description
export (String) var action_name setget set_action_name

func _ready() -> void:
	_refresh_description_label()
	$Delete.connect("pressed", self, "_on_Delete_pressed")


func set_description(new_description: String) -> void:
	description = new_description
	_refresh_description_label()


func set_action_name(new_action_name: String) -> void:
	action_name = new_action_name
	$Value0.action_name = new_action_name
	$Value1.action_name = new_action_name
	$Value2.action_name = new_action_name


func _refresh_description_label() -> void:
	if is_inside_tree():
		$Description.text = description


func _on_Delete_pressed() -> void:
	for action_index in range(0, 3):
		PlayerData.keybind_settings.set_custom_keybind(action_name, action_index, {})
	
	var custom_keybind_buttons := get_tree().get_nodes_in_group("custom_keybind_buttons")
	for keybind_button in custom_keybind_buttons:
		keybind_button.end_awaiting()
