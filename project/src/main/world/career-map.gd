extends Node
## Scene which shows the player's progress through career mode.
##
## Launching this scene also advances the player towards their goal if 'distance earned' is nonzero.

## The number of levels the player can choose between
const SELECTION_COUNT := 3

## Shows the player's current progress through career mode.
##
## This includes how many levels they've played, how much money they've earned, and how far they've travelled.

## key: (int) corresonding to the number of levels the player has played
## value: (String) human-readable time of day
var TIME_OF_DAY_BY_HOURS := {
	0: tr("8:00 am"),
	1: tr("9:10 am"),
	2: tr("10:15 am"),
	3: tr("11:20 am"),
	4: tr("12:30 pm"),
	5: tr("1:40 pm"),
	6: tr("2:45 pm"),
	7: tr("3:50 pm"),
	8: tr("5:00 pm"),
}

## key: (int) corresonding to the number of levels the player has played
## value: (String) summary of the player's progress
var DESCRIPTION_TEXT_BY_HOURS := {
	0: tr("A brand new day. Let's make some money!"),
	1: tr("Eight hours left. Plenty of time!"),
	2: tr("Seven hours to go. Get ready for the lunch rush!"),
	3: tr("Six hours left. Wow, look at all these customers!"),
	4: tr("Five hours left in the workday. Let's take a little break!"),
	5: tr("Three hours left, but customers are still coming in!"),
	6: tr("Two hours left. Phew, I'm exhausted!"),
	7: tr("One hour left in the workday. Give it your all, let's make this count!"),
	8: tr("Phew, what a day! Let's go home."),
}

## The previous PlayerData.career.distance_earned value, stored temporarily for UI messages
var _distance_just_travelled := 0

## LevelSettings instances for each level the player can select
var _level_settings_for_levels := []

## PieceSpeed for all levels the player can select.
var _piece_speed: String

var _duration_calculator := DurationCalculator.new()

onready var _daily_steps := $LevelSelect/DailySteps
onready var _time_of_day := $LevelSelect/TimeOfDay

onready var _level_description_panel := $LevelSelect/VBoxContainer/Bottom/HBoxContainer/Description
onready var _level_info_panel := $LevelSelect/VBoxContainer/Bottom/HBoxContainer/Info
onready var _grade_labels := $LevelSelect/VBoxContainer/Top/GradeLabels

## LevelSelectButtons for all levels the player can select.
onready var _level_select_buttons := $LevelSelect/VBoxContainer/Top/LevelButtons.get_children()

func _ready() -> void:
	# advance the player towards their goal
	_distance_just_travelled = PlayerData.career.distance_earned
	PlayerData.career.distance_travelled = min(
		PlayerData.career.distance_travelled + PlayerData.career.distance_earned,
		CareerData.MAX_DISTANCE_TRAVELLED)
	PlayerData.career.distance_earned = 0
	
	if PlayerData.career.is_day_over():
		PlayerData.career.push_career_trail()
	else:
		_prepare_ui()


func _prepare_ui() -> void:
	_load_level_settings()
	_prepare_level_select_buttons()
	_prepare_labels()


## Loads level settings for three randomly selected levels from the current CareerRegion.
func _load_level_settings() -> void:
	var career_levels := _random_levels()
	_piece_speed = CareerLevelLibrary.piece_speed_for_distance(PlayerData.career.distance_travelled)
	for i in range(_level_select_buttons.size()):
		var level_select_button: LevelSelectButton = _level_select_buttons[i]
		if i >= career_levels.size():
			level_select_button.visible = false
			continue
		var available_level: CareerLevel = career_levels[i]
		
		var level_settings := LevelSettings.new()
		level_settings.load_from_resource(available_level.level_id)
		LevelSpeedAdjuster.new(level_settings).adjust(_piece_speed)
		_level_settings_for_levels.append(level_settings)


## Updates the LevelSelectButtons with the appropriate level data, and hooks up their signals.
func _prepare_level_select_buttons() -> void:
	for i in range(_level_select_buttons.size()):
		var level_select_button: LevelSelectButton = _level_select_buttons[i]
		if i >= _level_settings_for_levels.size():
			level_select_button.visible = false
			continue
		var level_settings: LevelSettings = _level_settings_for_levels[i]
		
		# for the first button, update its text, color, and connect a listener
		level_select_button.level_title = level_settings.title
		level_select_button.level_id = level_settings.id
		
		var duration := _duration_calculator.duration(level_settings)
		if duration < 100:
			level_select_button.level_duration = LevelSelectButton.SHORT
		elif duration < 200:
			level_select_button.level_duration = LevelSelectButton.MEDIUM
		else:
			level_select_button.level_duration = LevelSelectButton.LONG
		
		level_select_button.connect("focus_entered", self, "_on_LevelSelectButton_focus_entered", [i])
		level_select_button.connect("level_started", self, "_on_LevelSelectButton_level_started", [i])
		_grade_labels.add_label(level_select_button)
	
	# grab focus to allow keyboard support
	if _level_select_buttons:
		var middle_button_index: int = max(_level_select_buttons.size(), _level_settings_for_levels.size()) / 2
		_level_select_buttons[middle_button_index].grab_focus()


## Updates the time of day, daily steps, info and description levels with their initial values.
##
## This must happen after the LevelSelectButtons grab focus, otherwise the initial description will be overwritten by
## the level description.
func _prepare_labels() -> void:
	# prepare the time of day label
	_time_of_day.text = TIME_OF_DAY_BY_HOURS.get(PlayerData.career.hours_passed, "?:?? zm")
	if not TIME_OF_DAY_BY_HOURS.has(PlayerData.career.hours_passed):
		push_warning("TIME_OF_DAY_BY_HOURS has no entry for %s" % [PlayerData.career.hours_passed])
	
	# prepare the daily steps label
	if _distance_just_travelled:
		_daily_steps.text = "%s (+%s)" % [PlayerData.career.distance_travelled, _distance_just_travelled]
	else:
		_daily_steps.text = PlayerData.career.distance_travelled as String
	
	# prepare the info label
	if PlayerData.career.prev_distance_travelled:
		var info_text: String = tr("Past attempts:")
		for i in range(min(PlayerData.career.prev_distance_travelled.size(), 3)):
			var daily_earnings: int = PlayerData.career.prev_daily_earnings[i]
			var distance_travelled: int = PlayerData.career.prev_distance_travelled[i]
			info_text += "\n"
			info_text += "%s (%s)" % \
					[StringUtils.comma_sep(distance_travelled), StringUtils.format_money(daily_earnings)]
		_level_info_panel.set_text(info_text)
	
	# prepare the description label
	_level_description_panel.set_text(DESCRIPTION_TEXT_BY_HOURS.get(PlayerData.career.hours_passed, ""))
	if not DESCRIPTION_TEXT_BY_HOURS.has(PlayerData.career.hours_passed):
		push_warning("DESCRIPTION_TEXT_BY_HOURS has no entry for %s" % [PlayerData.career.hours_passed])


## Return a list of random CareerLevels for the player to choose from.
##
## We only select levels appropriate for the current distance, and we exclude levels which have been played in the
## current session.
func _random_levels() -> Array:
	var levels := CareerLevelLibrary.career_levels_for_distance(PlayerData.career.distance_travelled)
	levels = levels.duplicate() # avoid modifying the original list
	
	# We use a seeded shuffle which always gives the player the same random levels. Otherwise they can relaunch career
	# mode over and over until they get the exact levels they want to play.
	var seed_int := 0
	seed_int += PlayerData.career.daily_earnings
	if PlayerData.career.prev_daily_earnings:
		seed_int += PlayerData.career.prev_daily_earnings[0]
	Utils.seeded_shuffle(levels, seed_int)
	
	var random_levels := levels.slice(0, min(SELECTION_COUNT - 1, levels.size() - 1))
	var random_level_index := 0
	for level in levels:
		random_levels[random_level_index] = level
		if level.level_id in PlayerData.career.daily_level_ids:
			# this level has been played in the current session; try the next one
			pass
		else:
			# this level hasn't been played in the current session; add it to the list
			random_level_index += 1
		
		if random_level_index >= random_levels.size():
			# we've found enough levels
			break
	
	return random_levels


## When the player clicks a level button once, we show more information.
func _on_LevelSelectButton_focus_entered(level_index: int) -> void:
	var level_settings: LevelSettings = _level_settings_for_levels[level_index]
	_level_info_panel.update_unlocked_level_text(level_settings)
	_level_description_panel.update_unlocked_level_text(level_settings)


## When the player clicks a level button twice, we launch the selected level
func _on_LevelSelectButton_level_started(level_index: int) -> void:
	var level_settings: LevelSettings = _level_settings_for_levels[level_index]
	PlayerData.career.daily_level_ids.append(level_settings.id)
	CurrentLevel.set_launched_level(level_settings.id)
	CurrentLevel.piece_speed = _piece_speed
	PlayerData.career.push_career_trail()