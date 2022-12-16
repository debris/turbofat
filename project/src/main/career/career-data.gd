extends Node
class_name CareerData
## Stores current and historical data for career mode
##
## This includes the current day's data like "how much money has the player earned today" and "how far have they
## travelled today", as well as historical information like "how many days have they played" and "how much money did
## they earn three days ago"


## Emitted when the player's distance changes, particularly at the start of career mode when they're picking their
## starting distance
signal distance_travelled_changed

## Emitted when the number of levels played in the current career session changes. It's unusual for this to change
## mid-scene, and really only happens when using cheat codes.
signal hours_passed_changed

## time to show when the number of levels the player has played is an unexpected value
var invalid_time_of_day := tr("?:?? zm")

## key: (int) corresonding to the number of levels the player has played
## value: (String) human-readable time of day
var time_of_day_by_hours := {
	0: tr("11:00 am"),
	1: tr("12:10 pm"),
	2: tr("1:20 pm"),
	3: tr("6:30 pm"),
	4: tr("7:40 pm"),
	5: tr("8:50 pm"),
	6: tr("10:00 pm"),
}

## The number of steps the player couldn't take because they were stopped by a boss/intro level.
var banked_steps := 0

## The distance the player has travelled in the current career session.
var distance_travelled := 0 setget set_distance_travelled

## The distance the progress board should start from when moving the player
var progress_board_start_distance_travelled := 0

## The distance earned from the previously completed puzzle, plus any banked steps from earlier puzzles.
var distance_earned := 0

## The number of levels played in the current career session.
var hours_passed := 0 setget set_hours_passed

## The number of customers served in the current career session.
var daily_customers := 0

## The amount of money earned in the current career session.
var daily_earnings := 0

## The level IDs played in the current career session. This is tracked to avoid repeating levels.
var daily_level_ids := []

## The amount of time played in the current career session.
var daily_seconds_played := 0.0

## The number of steps taken in the current career session (not including initial level selection)
var daily_steps := 0

## The number of days the player has completed.
var day := 0

## Array of ints for previous daily earnings. Index 0 holds the most recent data.
var prev_daily_earnings := []

## Array of ints for previous distance travelled. Index 0 holds the most recent data.
var prev_distance_travelled := []

## The furthest total distance the player has travelled in a single session.
var best_distance_travelled := 0

## 'true' if the player should not advance to the next region.
##
## This is enabled when replaying regions. It would be tedious to be forced into later regions, because playing
## earlier regions is necessary to view certain cutscenes and finish the game.
var remain_in_region := false

## 'true' if the player skipped or gave up on the previous level, instead of finishing it or topping out.
var skipped_previous_level := false

## Whether the career map should show the player's progress.
var show_progress: int = Careers.ShowProgress.STATIC

## periodically increments the 'daily_seconds_played' value
var _daily_seconds_played_timer: Timer

## CareerCalendar instance which advances the calendar and clock in career mode.
var _career_calendar

## CareerFlow instance which maintains the flow of scenes in career mode. Redirects the player to cutscenes, victory
## screens and interludes.
var _career_flow

func _ready() -> void:
	CurrentCutscene.connect("cutscene_played", self, "_on_CurrentCutscene_cutscene_played")
	
	_daily_seconds_played_timer = Timer.new()
	_daily_seconds_played_timer.wait_time = PlayerData.SECONDS_PLAYED_INCREMENT
	_daily_seconds_played_timer.connect("timeout", self, "_on_DailySecondsPlayedTimer_timeout")
	add_child(_daily_seconds_played_timer)
	_daily_seconds_played_timer.start()
	
	## We avoid cyclic reference errors by loading these scripts with 'load' instead of 'preload'
	_career_calendar = load("res://src/main/career/career-calendar.gd").new(self)
	_career_flow = load("res://src/main/career/career-flow.gd").new(self)


func reset() -> void:
	banked_steps = 0
	distance_travelled = 0
	distance_earned = 0
	hours_passed = 0
	daily_customers = 0
	daily_earnings = 0
	daily_level_ids.clear()
	daily_seconds_played = 0.0
	daily_steps = 0
	day = 0
	prev_daily_earnings.clear()
	prev_distance_travelled.clear()
	best_distance_travelled = 0
	remain_in_region = false
	skipped_previous_level = false
	emit_signal("distance_travelled_changed")


func from_json_dict(json: Dictionary) -> void:
	banked_steps = int(json.get("banked_steps", 0))
	distance_travelled = int(json.get("distance_travelled", 0))
	distance_earned = int(json.get("distance_earned", 0))
	hours_passed = int(json.get("hours_passed", 0))
	daily_customers = int(json.get("daily_customers", 0))
	daily_earnings = int(json.get("daily_earnings", 0))
	daily_level_ids = json.get("daily_level_ids", [])
	daily_seconds_played = float(json.get("daily_seconds_played", 0.0))
	daily_steps = int(json.get("daily_steps", 0))
	day = int(json.get("day", 0))
	prev_daily_earnings = json.get("prev_daily_earnings", [])
	prev_distance_travelled = json.get("prev_distance_travelled", [])
	best_distance_travelled = int(json.get("best_distance_travelled", 0))
	remain_in_region = bool(json.get("remain_in_region", false))
	skipped_previous_level = bool(json.get("skipped_previous_level", false))
	emit_signal("distance_travelled_changed")


func to_json_dict() -> Dictionary:
	var results := {}
	results["banked_steps"] = banked_steps
	results["distance_travelled"] = distance_travelled
	results["distance_earned"] = distance_earned
	results["hours_passed"] = hours_passed
	results["daily_customers"] = daily_customers
	results["daily_earnings"] = daily_earnings
	results["daily_level_ids"] = daily_level_ids
	results["daily_seconds_played"] = daily_seconds_played
	results["daily_steps"] = daily_steps
	results["day"] = day
	results["prev_daily_earnings"] = prev_daily_earnings
	results["prev_distance_travelled"] = prev_distance_travelled
	results["best_distance_travelled"] = best_distance_travelled
	results["remain_in_region"] = remain_in_region
	results["skipped_previous_level"] = skipped_previous_level
	return results


## Returns the player's current career interlude hours.
##
## When replaying an already-cleared region, more levels include a cutscene interlude. This is because presumably,
## players in a new region are more focused on playing the new levels, where players replaying a region are focused on
## finishing its cutscenes.
##
## Returns:
## 	Array of ints for the hours in career mode which should currently include interlude cutscenes, based on the
## 	player's progress.
func career_interlude_hours() -> Array:
	var result: Array
	if remain_in_region:
		# When replaying an already-cleared region, the 2nd, 4th and 6th levels include a cutscene
		result = [1, 3, 5]
	else:
		# Normally, the 3rd and 6th levels include a cutscene
		result = [2, 5]
	return result


## Returns 'true' if the player has completed the current career mode session.
func is_day_over() -> bool:
	return hours_passed >= Careers.HOURS_PER_CAREER_DAY


## Launches the next scene in career mode. Either a new level, or a cutscene/ending scene.
func push_career_trail() -> void:
	_career_flow.push_career_trail()


## Returns the career region the player is currently in.
func current_region() -> CareerRegion:
	return CareerLevelLibrary.region_for_distance(distance_travelled)


## Returns 'true' if the current career region has a prologue the player hasn't seen.
func should_play_prologue() -> bool:
	return _career_flow.should_play_prologue()


## Returns 'true' if the player is current playing career mode
func is_career_mode() -> bool:
	return Global.SCENE_CAREER_MAP in Breadcrumb.trail


## Returns 'true' if the player hasn't reached this region yet
func is_region_locked(region: CareerRegion) -> bool:
	return best_distance_travelled < region.start


## Returns 'true' if the player has completed the boss level in the specified region
func is_region_cleared(region: CareerRegion) -> bool:
	return best_distance_travelled > region.end


## Returns 'true' if the player has completed one level in the specified region
func is_region_started(region: CareerRegion) -> bool:
	return best_distance_travelled > region.start


## Returns 'true' if the current career mode distance corresponds to an uncleared boss level
func is_boss_level() -> bool:
	var result := true
	var region: CareerRegion = current_region()
	if distance_travelled != region.end:
		# the player is not at the end of the region
		result = false
	elif not region.boss_level:
		# the region has no boss level
		result = false
	elif is_region_cleared(region):
		# the player has already cleared this boss level
		result = false
	return result


## Returns 'true' if the current career mode distance corresponds to an uncleared intro level
func is_intro_level() -> bool:
	var result := true
	var region: CareerRegion = current_region()
	if distance_travelled != region.start:
		# the player is not at the start of the region
		result = false
	elif not region.intro_level:
		# the region has no intro level
		result = false
	elif is_intro_level_finished(region):
		# the player has already cleared this intro level
		result = false
	return result


func is_intro_level_finished(region: CareerRegion) -> bool:
	return region.intro_level and best_distance_travelled > region.start


## Returns the number of levels the player can choose between, based on their current distance and progress.
func level_choice_count() -> int:
	return 1 if is_intro_level() or is_boss_level() else 3


## Returns the player's distance penalties for picking different levels.
##
## Upon beating a level, the player is advanced by distance_earned. If they select one of the two leftmost levels,
## a penalty is applied and they don't travel as far.
##
## Returns:
## 	An array of positive ints corresponding to the penalty for selecting each level. Index 0 corresponds to the
## 	earliest level.
func distance_penalties() -> Array:
	var result := [0, 0, 0]
	
	if level_choice_count() == 1:
		# if the player has no choice, there is no penalty
		return result
	
	# adjust result[0]
	if distance_earned < 0: result [0] = 1 # small penalty for level selection after failing a boss stage
	elif distance_earned <= 1: result[0] = 0 # no penalty after skipping, or for the first level of a set
	elif distance_earned <= 2: result[0] = 1
	elif distance_earned <= 5: result[0] = 2
	elif distance_earned <= 6: result[0] = 3
	else: result[0] = 4
	
	# adjust result[1]
	if distance_earned <= 1: result[1] = 0 # no penalty after skipping, or for the first level of a set
	elif distance_earned <= 5: result[1] = 1
	else: result[1] = 2
	
	# penalties can never take you into a previous region
	var max_penalty: int = distance_travelled - current_region().start
	for i in range(result.size()):
		result[i] = min(result[i], max_penalty)
	
	return result


## Advances the clock and advances the player the specified distance.
##
## Even if new_distance_earned is a large number, the player's travel distance can be limited in two scenarios:
##
## 1. If they just played a non-boss level, they cannot advance past a boss level they haven't cleared.
##
## 2. If they just played a boss level, they cannot advance without meeting its success criteria.
##
## Parameters:
## 	'new_distance_earned': The maximum distance the player will travel.
##
## 	'success': 'True' if the player met the success criteria for the current level.
func advance_clock(new_distance_earned: int, success: bool) -> void:
	_career_calendar.advance_clock(new_distance_earned, success)


## Advances the calendar day and resets all daily variables.
func advance_calendar() -> void:
	_career_calendar.advance_calendar()


## Updates the state of career mode based on the player's puzzle performance.
##
## If the player skips or fails a level, this has consequences including skipping cutscenes and advancing the clock.
func process_puzzle_result() -> void:
	_career_flow.process_puzzle_result()


func set_distance_travelled(new_distance_travelled: int) -> void:
	distance_travelled = new_distance_travelled
	best_distance_travelled = max(best_distance_travelled, distance_travelled)
	emit_signal("distance_travelled_changed")


func set_hours_passed(new_hours_passed: int) -> void:
	hours_passed = new_hours_passed
	emit_signal("hours_passed_changed")


## Returns data about which parts of a region are complete/incomplete.
func region_completion(region: CareerRegion) -> RegionCompletion:
	var region_completion := RegionCompletion.new()
	
	# include the percent of cutscenes which have been viewed
	if region.cutscene_path:
		var all_search_flags := CutsceneSearchFlags.new()
		all_search_flags.include_all_numeric_children = true
		var all_chat_count: int = CareerCutsceneLibrary.find_chat_key_pairs(
				[region.cutscene_path], all_search_flags).size()
		region_completion.potential_cutscene_completion = all_chat_count
		
		var unexhausted_search_flags := CutsceneSearchFlags.new()
		unexhausted_search_flags.include_all_numeric_children = true
		unexhausted_search_flags.excluded_chat_keys = CareerCutsceneLibrary.exhausted_chat_keys([region.cutscene_path])
		var unexhausted_chat_count: int = CareerCutsceneLibrary.find_chat_key_pairs(
				[region.cutscene_path], unexhausted_search_flags).size()
		
		region_completion.cutscene_completion = all_chat_count - unexhausted_chat_count
	
	# include the percent of levels which have been completed
	region_completion.potential_level_completion = region.levels.size()
	for level_obj in region.levels:
		var level: CareerLevel = level_obj
		if PlayerData.level_history.is_level_finished(level.level_id):
			region_completion.level_completion += 1.0
	
	return region_completion


## Advance the player past the region shown in the specified cutscene.
##
## When a cutscene shows the player advancing to the next region, we automatically advance them through career mode.
##
## This is an important gameplay consideration if the player is stuck in a difficult area -- finishing every cutscene
## lets them see the rest of the game. It's more of a quirk otherwise, and might even frustrate the player if they
## still want to play a specific region. But it would be confusing and weird if they watched a cutscene saying 'Well,
## that's enough of that area! Goodbye!' and then they remained there to play more levels.
##
## If the player is already past the specified cutscene, this method has no effect.
##
## Parameters:
## 	'chat_key': The chat key for a cutscene which shows the player advancing to the next region
func advance_past_chat_region(chat_key: String) -> void:
	var region: CareerRegion = CareerLevelLibrary.region_for_chat_key(chat_key)
	
	if distance_travelled < region.end + 1:
		# The cutscene shows the player advancing to the next region. Forcibly advance the player to the next region.
		remain_in_region = false
		var old_distance_travelled := distance_travelled
		set_distance_travelled(region.end + 1)
		distance_earned += (distance_travelled - old_distance_travelled)


## Returns 'true' if the player's travelled far enough to have a 'nice restaurant'
func is_restaurant_decorated() -> bool:
	if CareerLevelLibrary.regions.size() < 2:
		return false
	
	var second_region: CareerRegion = CareerLevelLibrary.regions[1]
	return best_distance_travelled >= second_region.get_end()


## Returns 'true' if the player still refers to Fat Sensei as 'Turbo'
func is_sensei_turbo() -> bool:
	if CareerLevelLibrary.regions.size() < 1:
		return true
	
	var first_region: CareerRegion = CareerLevelLibrary.regions[0]
	return not PlayerData.chat_history.is_chat_finished("chat/career/lemon/boss_level") \
		and best_distance_travelled <= first_region.get_end()


## When a cutscene shows the player advancing to the next region, we automatically advance them through career mode
##
## This is an important gameplay consideration if the player is stuck in a difficult area -- finishing every cutscene
## lets them see the rest of the game. It's more of a quirk otherwise, and might even frustrate the player if they
## still want to play a specific region. But it would be confusing and weird if they watched a cutscene saying 'Well,
## that's enough of that area! Goodbye!' and then they remained there to play more levels.
func _on_CurrentCutscene_cutscene_played(chat_key: String) -> void:
	# Cannot statically type as 'ChatTree' because of cyclic reference
	var chat_tree = ChatLibrary.chat_tree_for_key(chat_key)
	if chat_tree.meta.get("advance_region", false):
		advance_past_chat_region(chat_key)


func _on_DailySecondsPlayedTimer_timeout() -> void:
	if is_career_mode():
		daily_seconds_played += PlayerData.SECONDS_PLAYED_INCREMENT


## Calculates the highest rank milestone the player's reached.
static func rank_milestone_index(rank: float) -> int:
	var rank_milestone_index := 0
	for i in range(1, Careers.RANK_MILESTONES.size()):
		var rank_milestone: Dictionary = Careers.RANK_MILESTONES[i]
		if rank > rank_milestone.rank:
			break
		rank_milestone_index = i
	return rank_milestone_index
