extends ScenarioButton
"""
Button which launches an 'marathon' scenario.
"""

"""
Calculates the label text for displaying a player's high score for marathon mode.
"""
func get_best_text(scenario_name: String) -> String:
	var has_lived := false
	if ScenarioHistory.scenario_history.has(scenario_name):
		for rank_result in ScenarioHistory.scenario_history[scenario_name]:
			if not rank_result.died:
				has_lived = true
				break
	
	var text := ""
	var best_result := ScenarioHistory.get_best_result(scenario_name)
	if has_lived:
		text = "Top: %s (%s)*" % [best_result.score, Global.grade(best_result.score_rank)]
	elif best_result:
		text = "Top: %s (%s)" % [best_result.score, Global.grade(best_result.score_rank)]
	return text