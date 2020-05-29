extends Label
"""
Displays bonus points awarded during the current combo.

This only includes bonuses and should be a round number like +55 or +130 for visual aesthetics.
"""

func _ready() -> void:
	PuzzleScore.connect("bonus_score_changed", self, "_on_PuzzleScore_bonus_score_changed")
	text = "-"


func _on_PuzzleScore_bonus_score_changed(value: int) -> void:
	text = "-" if value == 0 else "+¥%s" % value