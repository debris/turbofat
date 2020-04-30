extends GridContainer
"""
Shows buttons corresponding to dialog branches the player can choose.
"""

signal chat_choice_chosen(choice_index)

# The most branches we can display at once. Branches beyond this will not be displayed.
const MAX_LABELS := 6

# Time in seconds for all of the chat choices to pop up.
const TOTAL_POP_IN_DELAY := 0.3

export (PackedScene) var ChatChoiceButton

# Strings to show the player for each dialog branch.
var _choices := []

# Moods corresponding to each dialog branch; -1 for branches with no mood.
var _moods := []

func _ready() -> void:
	# Remove placeholder buttons
	_refresh_child_buttons()


"""
Repositions the buttons based on the amount of dialog shown.

If a lot of dialog is displayed, the buttons are flush against the right side of the window and narrow. If less dialog
is displayed, the buttons are closer to the center and wider.

Parameters:
	'sentence_size': An enum from ChatAppearance.SentenceSize corresponding to the amount of dialog displayed.
"""
func reposition(sentence_size: int) -> void:
	match(sentence_size):
		ChatAppearance.SentenceSize.SMALL:
			rect_position = Vector2(659, 355)
			rect_size = Vector2(325, 240)
		ChatAppearance.SentenceSize.MEDIUM, ChatAppearance.SentenceSize.LARGE:
			rect_position = Vector2(729, 355)
			rect_size = Vector2(280, 240)
		ChatAppearance.SentenceSize.EXTRA_LARGE:
			rect_position = Vector2(819, 355)
			rect_size = Vector2(200, 240)


"""
Displays a set of buttons corresponding to dialog choices.

Parameters:
	'choices': Strings to show the player for each dialog branch.
	
	'moods': An array of ChatEvent.Mood instances for each dialog branch
"""
func show_choices(choices: Array, moods: Array) -> void:
	visible = true
	_choices = choices
	_moods = moods
	
	if _choices.size() > MAX_LABELS:
		push_warning("Too many chat choices: %s > %s" % [choices.size(), MAX_LABELS])
		_choices = choices.slice(0, MAX_LABELS - 1)
	
	columns = 1 if _choices.size() <= 3 else 2
	_refresh_child_buttons()
	
	if choices:
		for child in get_children():
			var button: ChatChoiceButton = _button(child)
			if button:
				button.grab_focus()
				break


func is_showing_choices() -> bool:
	return not _choices.empty()


"""
Makes all the chat choice buttons disappear.

The chat choice buttons are immediately deleted without any sort of animation.
"""
func hide_choices() -> void:
	visible = false
	_choices = []
	_refresh_child_buttons()


func _delete_old_buttons(old_buttons: Array) -> void:
	var chosen_button: ChatChoiceButton
	for button_object in old_buttons:
		var button: ChatChoiceButton = button_object
		if button.has_focus():
			chosen_button = button
			break
	if chosen_button:
		yield(chosen_button, "pop_choose_completed")
	for button_object in old_buttons:
		var button: ChatChoiceButton = button_object
		button.queue_free()
		remove_child(button)


func _button(node: Node) -> ChatChoiceButton:
	var result: ChatChoiceButton = node if node.is_class("Button") else null
	return result


"""
Removes and recreates all chat choice buttons.
"""
func _refresh_child_buttons() -> void:
	for child in get_children():
		var button: ChatChoiceButton = _button(child)
		if button:
			child.queue_free()
			remove_child(child)
	
	var new_buttons: Array = []
	
	for i in range(_choices.size()):
		var button: ChatChoiceButton = ChatChoiceButton.instance()
		button.set_choice_text(_choices[i])
		button.set_mood(_moods[i])
		button.set_mood_right(i % 2 == 1)
		button.connect("focus_entered", self, "_on_ChatChoiceButton_focus_entered")
		button.connect("gui_input", self, "_on_ChatChoiceButton_gui_input")
		button.connect("pressed", self, "_on_ChatChoiceButton_pressed")
		add_child(button)
		new_buttons.append(button)
	
	var pop_in_delay := TOTAL_POP_IN_DELAY / (new_buttons.size() - 1) if new_buttons.size() >= 2 else 0.0
	if new_buttons.size() >= 4:
		# with four or more buttons, it looks cute if they pop up out-of-order
		new_buttons.shuffle()
	for button_object in new_buttons:
		# the button we created could already be deleted if refresh_child_buttons was called again
		if is_instance_valid(button_object):
			var button: ChatChoiceButton = button_object
			button.pop_in()
			$PopSound.play()
			yield(get_tree().create_timer(pop_in_delay), "timeout")


func _on_ChatChoiceButton_focus_entered() -> void:
	$PopSound.play()


func _on_ChatChoiceButton_gui_input(event: InputEvent) -> void:
	# swallow input; player shouldn't move when answering dialog prompts
	get_tree().set_input_as_handled()


"""
Makes all the chat choice buttons disappear and emits a signal with the player's selected choice.

The chat choice buttons remain as children of this node so they can be animated away.
"""
func _on_ChatChoiceButton_pressed() -> void:
	var old_buttons := []
	for child in get_children():
		var button: ChatChoiceButton = _button(child)
		if button:
			old_buttons.append(button)

	# determine the currently selected choice
	var choice_index := -1
	for i in range(old_buttons.size()):
		var button: ChatChoiceButton = old_buttons[i]
		if button.has_focus():
			choice_index = i
			break
	
	# make the buttons animate and disappear
	for button_object in old_buttons:
		var button: ChatChoiceButton = button_object
		if button.has_focus():
			$ChooseSound.play()
			button.pop_choose()
		else:
			button.pop_out()
	
	# delete the buttons after their animations finish, otherwise they steal keyboard focus
	_delete_old_buttons(old_buttons)
	_choices = []
	
	emit_signal("chat_choice_chosen", choice_index)
	get_tree().set_input_as_handled()