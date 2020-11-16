tool
extends HBoxContainer
"""
A row which shows the player the keybinds for a specific action, such as 'Move Piece Left'.

This row is used for presets like 'Guideline' and 'WASD', and is non-interactive.
"""

export (String) var description: String setget set_description
export (String) var value: String setget set_value

func _ready() -> void:
	_refresh_description_label()
	_refresh_value_label()


func set_description(new_description: String) -> void:
	description = new_description
	_refresh_description_label()


func set_value(new_value: String) -> void:
	value = new_value
	_refresh_value_label()


func _refresh_description_label() -> void:
	$Description.text = description


func _refresh_value_label() -> void:
	$Value.text = value
